package com.rm.snapracers.net

import android.content.BroadcastReceiver
import android.content.Context
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.location.LocationManager
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import org.godotengine.godot.Dictionary
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.UsedByGodot
import java.util.concurrent.ConcurrentLinkedQueue

/**
 * The game's way into Android's networking: NSD for finding games on the same
 * Wi-Fi, Wi-Fi Direct for racing with no router or hotspot, and Bluetooth for
 * racing with no Wi-Fi at all. It's ScorchDroid's LanDiscovery,
 * WifiDirectTransport and BluetoothTransport, moved over and kept to what
 * SnapRacers needs.
 *
 * The game asks for things by calling the methods here, and everything that
 * comes back (a game found, a group formed, a Bluetooth packet) goes into one
 * queue that the game empties every frame with [poll]. Android answers on its
 * own threads, and a queue is the one thing that's safe to hand across, so
 * nothing here ever calls into Godot. See scripts/net/net_plugin.gd for the
 * other end.
 */
class SnapRacersNet(godot: Godot) : GodotPlugin(godot) {
    private val events = ConcurrentLinkedQueue<Dictionary>()
    val main = Handler(Looper.getMainLooper())
    private var multicastLock: WifiManager.MulticastLock? = null
    private val nsd = Nsd(this)
    private val direct = WifiDirect(this)
    private val bluetooth = Bluetooth(this)

    override fun getPluginName() = "SnapRacersNet"

    /** The app's context, once there's an activity to get it from. */
    val appContext: Context?
        get() = activity?.applicationContext

    /** Puts something in the queue for the game. */
    fun tell(kind: String, vararg values: Pair<String, Any>) {
        val event = Dictionary()
        event["kind"] = kind
        for ((key, value) in values) event[key] = value
        events.add(event)
    }

    /** The next thing that's happened, or an empty one when there's nothing. */
    @UsedByGodot
    fun poll(): Dictionary = events.poll() ?: Dictionary()

    // Finding games on the same Wi-Fi.

    @UsedByGodot
    fun nsd_advertise(name: String, port: Int) = main.post { nsd.advertise(name, port) }

    @UsedByGodot
    fun nsd_stop_advertising() = main.post { nsd.stopAdvertising() }

    @UsedByGodot
    fun nsd_look() = main.post { nsd.look() }

    @UsedByGodot
    fun nsd_stop_looking() = main.post { nsd.stopLooking() }

    /**
     * Keeps broadcast and multicast packets coming in, for the game's own
     * broadcast and for NSD. Some phones drop them to save power otherwise,
     * and then nothing's ever found.
     */
    @UsedByGodot
    fun hear_broadcasts(on: Boolean) = main.post {
        if (on) holdMulticast("broadcast") else letGoMulticast("broadcast")
    }

    private val multicastUsers = mutableSetOf<String>()

    fun holdMulticast(who: String) {
        multicastUsers.add(who)
        if (multicastLock?.isHeld == true) return
        val wifi = appContext?.getSystemService(Context.WIFI_SERVICE) as? WifiManager ?: return
        multicastLock = wifi.createMulticastLock("snapracers").apply {
            setReferenceCounted(false)
            acquire()
        }
    }

    fun letGoMulticast(who: String) {
        multicastUsers.remove(who)
        if (multicastUsers.isNotEmpty()) return
        multicastLock?.let { if (it.isHeld) it.release() }
        multicastLock = null
    }

    // Wi-Fi Direct.

    /** Why Wi-Fi Direct can't be used right now, for the player, or "". */
    @UsedByGodot
    fun direct_why_not(): String = appContext?.let { direct.whyNot(it) } ?: "the game isn't ready yet"

    /** The permissions it needs, for the game to ask for. */
    @UsedByGodot
    fun direct_permissions(): Array<String> = direct.permissions()

    @UsedByGodot
    fun direct_host(name: String, port: Int) = main.post { direct.host(name, port) }

    @UsedByGodot
    fun direct_stop_hosting() = main.post { direct.stopHosting() }

    @UsedByGodot
    fun direct_look(seconds: Int) = main.post { direct.look(seconds * 1000L) }

    @UsedByGodot
    fun direct_stop_looking() = main.post { direct.stopLooking() }

    @UsedByGodot
    fun direct_join(device: String) = main.post { direct.join(device) }

    @UsedByGodot
    fun direct_leave() = main.post { direct.leave() }

    // Bluetooth.

    @UsedByGodot
    fun bt_why_not(): String = appContext?.let { bluetooth.whyNot(it) } ?: "the game isn't ready yet"

    @UsedByGodot
    fun bt_permissions(): Array<String> = bluetooth.permissions()

    /** The phone's Bluetooth name, which is how others find it. */
    @UsedByGodot
    fun bt_name(): String = bluetooth.name()

    @UsedByGodot
    fun bt_is_off(): Boolean = appContext?.let { bluetooth.isOff(it) } ?: false

    @UsedByGodot
    fun bt_is_findable(): Boolean = bluetooth.isFindable()

    /** Android's own "turn Bluetooth on?" question. */
    @UsedByGodot
    fun bt_ask_to_turn_on() = main.post { activity?.startActivityForResult(bluetooth.turnOnIntent(), 7301) }

    /** Android's own "let other phones find this one?" question. */
    @UsedByGodot
    fun bt_ask_to_be_findable() = main.post { activity?.startActivityForResult(bluetooth.findableIntent(), 7302) }

    @UsedByGodot
    fun bt_host(): Boolean = bluetooth.host()

    @UsedByGodot
    fun bt_join(device: String): Boolean = bluetooth.join(device)

    @UsedByGodot
    fun bt_send(peer: Int, data: ByteArray, reliable: Boolean): Boolean = bluetooth.send(peer, data, reliable)

    @UsedByGodot
    fun bt_disconnect(peer: Int) = bluetooth.disconnect(peer)

    @UsedByGodot
    fun bt_stop() = bluetooth.stop()

    @UsedByGodot
    fun bt_look(seconds: Int) = main.post { bluetooth.look(seconds * 1000L) }

    @UsedByGodot
    fun bt_stop_looking() = main.post { bluetooth.stopLooking() }

    override fun onMainDestroy() {
        nsd.stopAdvertising()
        nsd.stopLooking()
        direct.stopLooking()
        direct.stopHosting()
        bluetooth.stopLooking()
        bluetooth.stop()
        multicastUsers.clear()
        letGoMulticast("")
        super.onMainDestroy()
    }

    // Things the three of them all need.

    fun granted(context: Context, permissions: Array<String>) = permissions.all {
        context.checkSelfPermission(it) == PackageManager.PERMISSION_GRANTED
    }

    fun locationOn(context: Context): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val manager = context.getSystemService(Context.LOCATION_SERVICE) as? LocationManager ?: return false
            return manager.isLocationEnabled
        }
        @Suppress("DEPRECATION")
        return Settings.Secure.getInt(context.contentResolver, Settings.Secure.LOCATION_MODE, 0) != 0
    }

    /**
     * Listens for some of Android's broadcasts. [exported] is for ones sent by
     * another app, which Bluetooth's are since Android 12 (it's its own app
     * now). They're protected broadcasts, so only the system can send them.
     */
    fun listen(context: Context, receiver: BroadcastReceiver, filter: IntentFilter, exported: Boolean = false) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(receiver, filter, if (exported) Context.RECEIVER_EXPORTED else Context.RECEIVER_NOT_EXPORTED)
        } else {
            context.registerReceiver(receiver, filter)
        }
    }

    fun stopListening(context: Context?, receiver: BroadcastReceiver?) {
        if (context == null || receiver == null) return
        try {
            context.unregisterReceiver(receiver)
        } catch (e: IllegalArgumentException) {
            // It was never listening, or it's already stopped.
        }
    }
}
