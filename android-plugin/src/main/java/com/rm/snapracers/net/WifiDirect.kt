package com.rm.snapracers.net

import android.Manifest
import android.annotation.SuppressLint
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.wifi.WifiManager
import android.net.wifi.WpsInfo
import android.net.wifi.p2p.WifiP2pConfig
import android.net.wifi.p2p.WifiP2pManager
import android.net.wifi.p2p.nsd.WifiP2pDnsSdServiceInfo
import android.net.wifi.p2p.nsd.WifiP2pDnsSdServiceRequest
import android.os.Build
import android.os.Looper
import android.util.Log

/**
 * Racing with no router, no hotspot and no internet, over Wi-Fi Direct.
 *
 * Wi-Fi Direct makes a real network between the phones. The phone that owns
 * the group is at a fixed address (192.168.49.1, usually), and the others get
 * one from it. So once a group's up, the game's the same ENet game it is on
 * Wi-Fi, and this is only how phones find each other and get into the group.
 *
 * The host makes its own group instead of waiting to be asked, so it's always
 * the owner, with the address others need. A phone that owns a group can't
 * join anyone else's, since asking to connect from inside a group sends an
 * invitation instead, and groups outlive the game and even the app. So [join]
 * leaves this phone's own group first.
 *
 * Everything here runs on the main thread.
 */
class WifiDirect(private val plugin: SnapRacersNet) {
    companion object {
        private const val TAG = "SnapRacersDirect"
        // P2P's DNS-SD wants the service type without the dot on the end.
        private val SERVICE_TYPE = Nsd.SERVICE_TYPE.trimEnd('.')
        // A service answer doesn't say which port, so the TXT record does.
        private const val TXT_PORT = "port"
        private const val TXT_NAME = "name"

        // How often looking asks again. One round of asking misses a phone
        // whose radio was busy just then, and nothing else tries again.
        private const val ASK_AGAIN_MS = 5_000L
        // Waiting for this phone's own group to go before joining another.
        private const val LEAVE_WAIT_MS = 6_000L
        private const val LEAVE_POLL_MS = 500L
        // The P2P stack needs a moment after a group goes before a new one.
        private const val SETTLE_MS = 1_500L
        // Finding the other phone again, just before connecting to it.
        private const val REFIND_WAIT_MS = 15_000L
        private const val REFIND_POLL_MS = 500L
        private const val REFIND_ASK_AGAIN_MS = 4_000L
        // A quick refusal is worth another go, and a timeout isn't.
        private const val CONNECT_TRIES = 3
        private const val RETRY_MS = 1_500L
        private const val CONNECT_WAIT_MS = 30_000L
    }

    private var manager: WifiP2pManager? = null
    private var channel: WifiP2pManager.Channel? = null
    private var request: WifiP2pDnsSdServiceRequest? = null
    private var hosting = false
    private var peersReceiver: BroadcastReceiver? = null
    private var connectReceiver: BroadcastReceiver? = null
    private var askAgain: Runnable? = null
    private var lookingEnds: Runnable? = null
    // Bumped on every join, so the steps of an old one know to stop.
    private var joinNumber = 0

    fun permissions(): Array<String> =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            arrayOf(Manifest.permission.NEARBY_WIFI_DEVICES)
        } else {
            arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)
        }

    /**
     * Why it can't be used right now, in words a player can do something
     * about, or "". A refused permission, Wi-Fi being off and nobody being
     * there all look the same from outside (an empty list), so the game says
     * which it is.
     */
    fun whyNot(context: Context): String {
        if (!context.packageManager.hasSystemFeature(PackageManager.FEATURE_WIFI_DIRECT) ||
            context.getSystemService(Context.WIFI_P2P_SERVICE) == null
        ) return "This phone doesn't have Wi-Fi Direct."
        if (!plugin.granted(context, permissions())) {
            return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                "The game needs the nearby devices permission for that."
            } else {
                "The game needs the location permission for that. Android ${Build.VERSION.RELEASE} uses it for finding phones nearby."
            }
        }
        val wifi = context.getSystemService(Context.WIFI_SERVICE) as? WifiManager
        if (wifi?.isWifiEnabled != true) {
            return "Wi-Fi's turned off. Turn it on. It doesn't need to be connected to anything."
        }
        // Before Android 13, with location turned off, looking works and
        // finds nothing, forever.
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU && !plugin.locationOn(context)) {
            return "Location's turned off, and Android ${Build.VERSION.RELEASE} needs it on to find phones nearby."
        }
        return ""
    }

    private fun ready(): Boolean {
        val context = plugin.appContext ?: return false
        if (whyNot(context) != "") return false
        if (channel != null) return true
        val service = context.getSystemService(Context.WIFI_P2P_SERVICE) as? WifiP2pManager ?: return false
        manager = service
        // The channel dies if the Wi-Fi Direct stack restarts, and then every
        // request quietly gets nothing, so it's made again next time.
        channel = service.initialize(context, Looper.getMainLooper()) {
            Log.w(TAG, "the Wi-Fi Direct channel went away")
            channel = null
        }
        return channel != null
    }

    private fun result(what: String, then: (Boolean, Int) -> Unit = { _, _ -> }) =
        object : WifiP2pManager.ActionListener {
            override fun onSuccess() {
                Log.i(TAG, "$what worked")
                then(true, -1)
            }
            override fun onFailure(reason: Int) {
                Log.w(TAG, "$what didn't work (reason $reason)")
                then(false, reason)
            }
        }

    /**
     * Makes this phone a group owner and puts the game out on it, for phones
     * looking with [look] to find. Tells the game whether the group really
     * came up, so it never says it's ready when nobody could ever join.
     */
    @SuppressLint("MissingPermission")
    fun host(name: String, port: Int) {
        val context = plugin.appContext
        val why = if (context == null) "The game isn't ready yet." else whyNot(context)
        if (why != "" || !ready()) {
            plugin.tell("direct_hosting", "ok" to false, "why" to why.ifEmpty { "Wi-Fi Direct wouldn't start." })
            return
        }
        val p2p = manager!!
        val ch = channel!!
        val info = WifiP2pDnsSdServiceInfo.newInstance(
            name, SERVICE_TYPE, mapOf(TXT_PORT to port.toString(), TXT_NAME to name),
        )
        // Cleared first, or hosting again puts the game out twice.
        p2p.clearLocalServices(ch, result("clearing services") { _, _ ->
            p2p.addLocalService(ch, info, result("putting the game out") { added, _ ->
                if (!added) {
                    plugin.tell("direct_hosting", "ok" to false, "why" to "Wi-Fi Direct wouldn't put the game out.")
                    return@result
                }
                p2p.createGroup(ch, result("making a group") { made, reason ->
                    // BUSY means there's already a group, most likely ours
                    // from before, which is what we wanted anyway.
                    hosting = made || reason == WifiP2pManager.BUSY
                    if (hosting) {
                        // Looking keeps this phone answering others' questions.
                        p2p.discoverPeers(ch, result("being findable"))
                        p2p.requestGroupInfo(ch) { group ->
                            Log.i(TAG, "group's up: ${group?.networkName}, owner ${group?.isGroupOwner}")
                        }
                    }
                    plugin.tell(
                        "direct_hosting", "ok" to hosting,
                        "why" to if (hosting) "" else "The Wi-Fi Direct group wouldn't start.",
                    )
                })
            })
        })
    }

    @SuppressLint("MissingPermission")
    fun stopHosting() {
        if (!hosting) return
        hosting = false
        val p2p = manager ?: return
        val ch = channel ?: return
        val context = plugin.appContext ?: return
        if (!plugin.granted(context, permissions())) return
        p2p.clearLocalServices(ch, result("clearing services"))
        p2p.removeGroup(ch, result("ending the group"))
    }

    /**
     * Looks for games on Wi-Fi Direct for [forMs]. Each one found goes to the
     * game with the phone's device address, not an IP: there isn't one until
     * it's joined the group, which is what [join] does.
     */
    @SuppressLint("MissingPermission")
    fun look(forMs: Long) {
        stopLooking()
        val context = plugin.appContext
        val why = if (context == null) "The game isn't ready yet." else whyNot(context)
        if (why != "" || !ready()) {
            plugin.tell("looking_done", "how" to "direct", "why" to why)
            return
        }
        val p2p = manager!!
        val ch = channel!!
        // The name and the port come in separate answers, so each waits for
        // the other.
        val ports = mutableMapOf<String, Int>()
        val names = mutableMapOf<String, String>()
        fun found(device: String) {
            val port = ports[device] ?: return
            val name = names[device] ?: return
            plugin.tell("found", "how" to "direct", "name" to name, "device" to device, "port" to port)
        }
        p2p.setDnsSdResponseListeners(
            ch,
            { instance, type, device ->
                if (!type.contains(SERVICE_TYPE, ignoreCase = true)) return@setDnsSdResponseListeners
                names.putIfAbsent(device.deviceAddress, instance.ifEmpty { device.deviceName })
                found(device.deviceAddress)
            },
            { domain, record, device ->
                if (!domain.contains(SERVICE_TYPE, ignoreCase = true)) return@setDnsSdResponseListeners
                record[TXT_PORT]?.toIntOrNull()?.let { ports[device.deviceAddress] = it }
                record[TXT_NAME]?.let { names[device.deviceAddress] = it }
                found(device.deviceAddress)
            },
        )
        // Phones in range, whether or not they answer, so the log can tell
        // "nobody's there" from "they're there and not answering".
        val peers = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context, intent: Intent) {
                if (plugin.appContext?.let { whyNot(it) } != "") return
                p2p.requestPeers(ch) { list ->
                    list.deviceList.forEach { Log.i(TAG, "in range: ${it.deviceName} ${it.deviceAddress}") }
                }
            }
        }
        peersReceiver = peers
        plugin.listen(context!!, peers, IntentFilter(WifiP2pManager.WIFI_P2P_PEERS_CHANGED_ACTION))
        // Asking for every service and picking ours out, not asking for ours.
        // Several phones answer a typed request with nothing at all, and an
        // untyped one with the very same service.
        val ask = WifiP2pDnsSdServiceRequest.newInstance()
        request = ask
        p2p.addServiceRequest(ch, ask, result("asking for games") { added, _ ->
            if (added) scan(p2p, ch)
        })
        val again = object : Runnable {
            override fun run() {
                if (request == null) return
                scan(p2p, ch)
                plugin.main.postDelayed(this, ASK_AGAIN_MS)
            }
        }
        askAgain = again
        plugin.main.postDelayed(again, ASK_AGAIN_MS)
        val ends = Runnable {
            lookingEnds = null
            stopLooking()
            plugin.tell("looking_done", "how" to "direct", "why" to "")
        }
        lookingEnds = ends
        plugin.main.postDelayed(ends, forMs)
    }

    // Looking for phones as well as services, since a phone that isn't
    // looking doesn't answer anyone else either.
    @SuppressLint("MissingPermission")
    private fun scan(p2p: WifiP2pManager, ch: WifiP2pManager.Channel) {
        p2p.discoverPeers(ch, result("looking for phones"))
        p2p.discoverServices(ch, result("looking for games"))
    }

    @SuppressLint("MissingPermission")
    fun stopLooking() {
        lookingEnds?.let { plugin.main.removeCallbacks(it) }
        lookingEnds = null
        askAgain?.let { plugin.main.removeCallbacks(it) }
        askAgain = null
        plugin.stopListening(plugin.appContext, peersReceiver)
        peersReceiver = null
        val p2p = manager ?: return
        val ch = channel ?: return
        request?.let { p2p.removeServiceRequest(ch, it, result("done asking for games")) }
        request = null
        // Looking left running keeps the Wi-Fi chip busy, unless we're hosting.
        if (!hosting) {
            try {
                p2p.stopPeerDiscovery(ch, result("done looking for phones"))
            } catch (e: SecurityException) {
                // The permission went away. It's stopped either way.
            }
        }
    }

    /**
     * Joins [device]'s group, and tells the game the owner's address to race
     * to (or why not). Leaves this phone's own group first (see the top).
     */
    @SuppressLint("MissingPermission")
    fun join(device: String) {
        val number = ++joinNumber
        fun done(address: String, why: String) {
            if (number != joinNumber) return
            joinNumber++
            unlistenConnect()
            plugin.tell("direct_joined", "address" to address, "why" to why)
        }
        val context = plugin.appContext
        val why = if (context == null) "The game isn't ready yet." else whyNot(context)
        if (why != "" || !ready()) return done("", why.ifEmpty { "Wi-Fi Direct wouldn't start." })
        val p2p = manager!!
        val ch = channel!!
        // Looking while connecting makes it flaky, and hosting's over now.
        stopLooking()
        stopHosting()
        leaveGroup(p2p, ch, number) { left ->
            if (!left) return@leaveGroup done(
                "", "This phone's still in another Wi-Fi Direct group. Turn Wi-Fi off and on again, and have another go.",
            )
            // Asked straight after a group goes, connecting is refused.
            plugin.main.postDelayed({ attempt(p2p, ch, device, number, 1, ::done) }, SETTLE_MS)
        }
    }

    private fun attempt(
        p2p: WifiP2pManager, ch: WifiP2pManager.Channel, device: String,
        number: Int, tries: Int, done: (String, String) -> Unit,
    ) {
        if (number != joinNumber) return
        // Stopping looking and leaving a group both empty Android's list of
        // phones it knows, and it refuses to connect to one it doesn't know.
        // So it's found again first, instead of trusting what we saw earlier.
        refind(p2p, ch, device, number) { there ->
            if (!there) return@refind done("", "The other phone stopped answering. Is it still hosting?")
            connectOnce(p2p, ch, device, number) { address, why, again ->
                if (address != "" || !again || tries >= CONNECT_TRIES) return@connectOnce done(address, why)
                plugin.main.postDelayed({ attempt(p2p, ch, device, number, tries + 1, done) }, RETRY_MS)
            }
        }
    }

    @SuppressLint("MissingPermission")
    private fun connectOnce(
        p2p: WifiP2pManager, ch: WifiP2pManager.Channel, device: String, number: Int,
        then: (String, String, Boolean) -> Unit,
    ) {
        var settled = false
        val timeout = Runnable {
            if (settled) return@Runnable
            settled = true
            unlistenConnect()
            then("", "The other phone never answered. Check it for an invitation to accept.", false)
        }
        fun finish(address: String, why: String, again: Boolean) {
            if (settled || number != joinNumber) return
            settled = true
            plugin.main.removeCallbacks(timeout)
            unlistenConnect()
            then(address, why, again)
        }
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context, intent: Intent) {
                // Asked rather than read off the intent, which only has it on
                // some versions.
                p2p.requestConnectionInfo(ch) { info ->
                    if (info == null || !info.groupFormed) return@requestConnectionInfo
                    if (info.isGroupOwner) {
                        finish("", "This phone ended up owning the group, so the other one isn't hosting.", false)
                    } else {
                        @Suppress("DEPRECATION")
                        finish(info.groupOwnerAddress?.hostAddress ?: "", "", false)
                    }
                }
            }
        }
        connectReceiver = receiver
        plugin.listen(plugin.appContext!!, receiver, IntentFilter(WifiP2pManager.WIFI_P2P_CONNECTION_CHANGED_ACTION))
        val config = WifiP2pConfig().apply {
            deviceAddress = device
            @Suppress("DEPRECATION")
            wps.setup = WpsInfo.PBC
            // The host already owns its group, so this one mustn't want to.
            groupOwnerIntent = 0
        }
        p2p.connect(ch, config, result("connecting") { asked, reason ->
            if (!asked) finish("", refusal(reason), true)
        })
        plugin.main.postDelayed(timeout, CONNECT_WAIT_MS)
    }

    @SuppressLint("MissingPermission")
    private fun refind(
        p2p: WifiP2pManager, ch: WifiP2pManager.Channel, device: String, number: Int,
        then: (Boolean) -> Unit,
    ) {
        var waited = 0L
        var settled = false
        fun settle(there: Boolean) {
            if (settled) return
            settled = true
            then(there)
        }
        p2p.discoverPeers(ch, result("looking for the host"))
        fun poll() {
            if (number != joinNumber || settled) return
            p2p.requestPeers(ch) { list ->
                if (list.deviceList.any { it.deviceAddress.equals(device, ignoreCase = true) }) return@requestPeers settle(true)
                if (waited >= REFIND_WAIT_MS) return@requestPeers settle(false)
                waited += REFIND_POLL_MS
                if (waited % REFIND_ASK_AGAIN_MS == 0L) p2p.discoverPeers(ch, result("looking for the host again"))
                plugin.main.postDelayed({ poll() }, REFIND_POLL_MS)
            }
        }
        plugin.main.postDelayed({ poll() }, REFIND_POLL_MS)
        // The poll only carries on from inside Android's answer, so a stack
        // that stops answering can't leave the game waiting forever.
        plugin.main.postDelayed({ settle(false) }, REFIND_WAIT_MS + 1_500L)
    }

    /**
     * Leaves whatever group this phone's in, and waits until it's really gone,
     * since connecting while it's still going away acts like it's still in it.
     */
    @SuppressLint("MissingPermission")
    private fun leaveGroup(p2p: WifiP2pManager, ch: WifiP2pManager.Channel, number: Int, then: (Boolean) -> Unit) {
        var waited = 0L
        var settled = false
        fun settle(left: Boolean) {
            if (settled) return
            settled = true
            then(left)
        }
        fun poll() {
            if (number != joinNumber || settled) return
            p2p.requestGroupInfo(ch) { group ->
                if (group == null) return@requestGroupInfo settle(true)
                if (waited == 0L) {
                    Log.i(TAG, "leaving our own group ${group.networkName} first")
                    p2p.removeGroup(ch, result("leaving our group"))
                }
                if (waited >= LEAVE_WAIT_MS) return@requestGroupInfo settle(false)
                waited += LEAVE_POLL_MS
                plugin.main.postDelayed({ poll() }, LEAVE_POLL_MS)
            }
        }
        poll()
        plugin.main.postDelayed({ settle(false) }, LEAVE_WAIT_MS + 1_000L)
    }

    private fun refusal(reason: Int): String = when (reason) {
        WifiP2pManager.P2P_UNSUPPORTED -> "This phone doesn't do Wi-Fi Direct."
        WifiP2pManager.BUSY -> "Wi-Fi Direct's busy. Try again in a moment."
        else -> "Wi-Fi Direct said no (reason $reason)."
    }

    private fun unlistenConnect() {
        plugin.stopListening(plugin.appContext, connectReceiver)
        connectReceiver = null
    }

    /** Leaves the group after racing on someone else's. */
    @SuppressLint("MissingPermission")
    fun leave() {
        joinNumber++
        unlistenConnect()
        val p2p = manager ?: return
        val ch = channel ?: return
        val context = plugin.appContext ?: return
        if (plugin.granted(context, permissions())) p2p.removeGroup(ch, result("leaving the group"))
    }
}
