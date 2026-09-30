package com.rm.snapracers.net

import android.Manifest
import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothServerSocket
import android.bluetooth.BluetoothSocket
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import java.io.IOException
import java.io.InputStream
import java.io.OutputStream
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger

/**
 * Racing over Bluetooth, with no Wi-Fi at all. It's just the sockets and
 * threads, with nothing about the game. The game's end is
 * scripts/net/bluetooth_peer.gd, which makes it look like any other network
 * to Godot.
 *
 * An RFCOMM socket is a stream, so every packet goes out behind a four byte
 * length and comes in whole.
 *
 * Each link has its own thread for writing, so the game never waits on the
 * radio. When a link backs up, packets that don't matter if they're lost (a
 * kart's position, which the next one replaces) are dropped instead of
 * queueing up and making everything late.
 */
class Bluetooth(private val plugin: SnapRacersNet) {
    companion object {
        private const val TAG = "SnapRacersBluetooth"
        // What a SnapRacers host is told apart from headphones by.
        private val SERVICE_UUID: UUID = UUID.fromString("5c1d7e2a-8b3f-4e61-a9d4-3f0b6c2e8a17")
        private const val SERVICE_NAME = "SnapRacers"
        private const val FINDABLE_SECONDS = 300
        private const val MOST_BYTES = 1_000_000
        // Packets that can be lost are dropped once this many are waiting.
        private const val BACKED_UP = 6
    }

    private class Link(val socket: BluetoothSocket, val output: OutputStream) {
        val waiting = LinkedBlockingQueue<ByteArray>()
        @Volatile var open = true
    }

    private val nextPeer = AtomicInteger(2)
    private val links = ConcurrentHashMap<Int, Link>()
    private var server: BluetoothServerSocket? = null
    @Volatile private var stopping = false
    private var lookReceiver: BroadcastReceiver? = null
    private var lookingEnds: Runnable? = null

    private fun adapter(): BluetoothAdapter? {
        val context = plugin.appContext ?: return null
        return (context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter
    }

    fun permissions(): Array<String> =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            arrayOf(
                Manifest.permission.BLUETOOTH_CONNECT,
                Manifest.permission.BLUETOOTH_SCAN,
                Manifest.permission.BLUETOOTH_ADVERTISE,
            )
        } else {
            arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)
        }

    private fun supported(context: Context) =
        context.packageManager.hasSystemFeature(PackageManager.FEATURE_BLUETOOTH) && adapter() != null

    /** Why it can't be used right now, for the player, or "". */
    fun whyNot(context: Context): String {
        if (!supported(context)) return "This phone doesn't have Bluetooth."
        if (!plugin.granted(context, permissions())) {
            return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                "The game needs the Bluetooth permissions for that."
            } else {
                "The game needs the location permission for that. Android ${Build.VERSION.RELEASE} uses it for finding Bluetooth devices."
            }
        }
        if (adapter()?.isEnabled != true) return "Bluetooth's turned off."
        // Before Android 12, with location off, looking runs and finds only
        // the phones you've already paired with, which is a confusing way for
        // a switch to be off.
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S && !plugin.locationOn(context)) {
            return "Location's turned off, and Android ${Build.VERSION.RELEASE} needs it on to find phones you haven't paired with."
        }
        return ""
    }

    fun isOff(context: Context) = supported(context) && adapter()?.isEnabled != true

    @SuppressLint("MissingPermission")
    fun name(): String {
        val context = plugin.appContext ?: return Build.MODEL
        if (whyNot(context) != "") return Build.MODEL
        return adapter()?.name ?: Build.MODEL
    }

    /**
     * Whether phones that have never paired with this one can find it.
     * Without that, only phones already paired with it see it.
     */
    @SuppressLint("MissingPermission")
    fun isFindable(): Boolean {
        val context = plugin.appContext ?: return false
        if (whyNot(context) != "") return false
        return adapter()?.scanMode == BluetoothAdapter.SCAN_MODE_CONNECTABLE_DISCOVERABLE
    }

    fun turnOnIntent() = Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE)

    fun findableIntent() = Intent(BluetoothAdapter.ACTION_REQUEST_DISCOVERABLE).apply {
        putExtra(BluetoothAdapter.EXTRA_DISCOVERABLE_DURATION, FINDABLE_SECONDS)
    }

    /**
     * Lists phones for [forMs]: the ones already paired first, straight
     * away, then whatever a scan finds. It doesn't ask each one whether it's
     * hosting, since that's slow and often gets no answer from a phone that
     * is. Picking one that isn't just fails to connect, and says so.
     */
    @SuppressLint("MissingPermission")
    fun look(forMs: Long) {
        stopLooking()
        val context = plugin.appContext
        val why = if (context == null) "The game isn't ready yet." else whyNot(context)
        val adapter = adapter()
        if (why != "" || adapter == null) {
            plugin.tell("looking_done", "how" to "bluetooth", "why" to why)
            return
        }
        val seen = mutableSetOf<String>()
        fun found(device: BluetoothDevice, paired: Boolean) {
            val address = device.address ?: return
            if (!seen.add(address)) return
            plugin.tell(
                "found", "how" to "bluetooth", "name" to (device.name ?: address),
                "device" to address, "paired" to paired,
            )
        }
        adapter.bondedDevices?.forEach { found(it, true) }
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context, intent: Intent) {
                if (intent.action != BluetoothDevice.ACTION_FOUND) return
                val device = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE, BluetoothDevice::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
                } ?: return
                found(device, false)
            }
        }
        lookReceiver = receiver
        // Exported, unlike the others. Since Android 12, Bluetooth is its own
        // app, and a receiver that isn't exported never hears it: the scan
        // runs, finds the other phone, and the game's told nothing. They're
        // protected broadcasts, so nothing but the system can send them.
        plugin.listen(context!!, receiver, IntentFilter(BluetoothDevice.ACTION_FOUND), exported = true)
        if (adapter.isDiscovering) adapter.cancelDiscovery()
        if (!adapter.startDiscovery()) Log.w(TAG, "Android wouldn't start a scan, so it's only paired phones")
        val ends = Runnable {
            lookingEnds = null
            stopLooking()
            plugin.tell("looking_done", "how" to "bluetooth", "why" to "")
        }
        lookingEnds = ends
        plugin.main.postDelayed(ends, forMs)
    }

    @SuppressLint("MissingPermission")
    fun stopLooking() {
        lookingEnds?.let { plugin.main.removeCallbacks(it) }
        lookingEnds = null
        plugin.stopListening(plugin.appContext, lookReceiver)
        lookReceiver = null
        val context = plugin.appContext ?: return
        if (plugin.granted(context, permissions())) {
            try {
                adapter()?.takeIf { it.isDiscovering }?.cancelDiscovery()
            } catch (e: SecurityException) {
                // The permission went away. It's stopped either way.
            }
        }
    }

    /** Starts taking players. Each one that connects is told to the game. */
    @SuppressLint("MissingPermission")
    fun host(): Boolean {
        val context = plugin.appContext ?: return false
        if (whyNot(context) != "") return false
        val adapter = adapter() ?: return false
        stopping = false
        return try {
            val socket = adapter.listenUsingRfcommWithServiceRecord(SERVICE_NAME, SERVICE_UUID)
            server = socket
            Thread({ acceptLoop(socket) }, "SnapRacers-bt-accept").start()
            true
        } catch (e: IOException) {
            Log.e(TAG, "couldn't start taking players", e)
            false
        } catch (e: SecurityException) {
            Log.e(TAG, "not allowed to take players", e)
            false
        }
    }

    /** Connects to a host, on a thread, since it takes a few seconds. */
    @SuppressLint("MissingPermission")
    fun join(device: String): Boolean {
        val context = plugin.appContext ?: return false
        if (whyNot(context) != "") return false
        val adapter = adapter() ?: return false
        stopping = false
        Thread({
            try {
                // A scan going on slows the radio down so much that
                // connecting often fails.
                if (adapter.isDiscovering) adapter.cancelDiscovery()
                val socket = adapter.getRemoteDevice(device).createRfcommSocketToServiceRecord(SERVICE_UUID)
                socket.connect()
                add(socket)
            } catch (e: IOException) {
                Log.e(TAG, "couldn't connect to $device", e)
                plugin.tell("bt_failed", "why" to "I couldn't connect over Bluetooth. Make sure the other phone's hosting, and try pairing them.")
            } catch (e: SecurityException) {
                plugin.tell("bt_failed", "why" to "The game needs the Bluetooth permissions for that.")
            }
        }, "SnapRacers-bt-connect").start()
        return true
    }

    fun send(peer: Int, data: ByteArray, reliable: Boolean): Boolean {
        val link = links[peer] ?: return false
        if (!reliable && link.waiting.size >= BACKED_UP) return true
        link.waiting.add(data)
        return true
    }

    fun disconnect(peer: Int) = close(peer)

    fun stop() {
        stopping = true
        try {
            server?.close()
        } catch (e: IOException) {
            // Already closed.
        }
        server = null
        links.keys.toList().forEach { close(it) }
    }

    private fun acceptLoop(socket: BluetoothServerSocket) {
        while (!stopping) {
            val accepted = try {
                socket.accept()
            } catch (e: IOException) {
                // How it ends: stop() closed the socket.
                if (!stopping) Log.e(TAG, "stopped taking players", e)
                break
            }
            if (accepted != null) add(accepted)
        }
    }

    private fun add(socket: BluetoothSocket) {
        val peer = nextPeer.getAndIncrement()
        val link = try {
            Link(socket, socket.outputStream)
        } catch (e: IOException) {
            try { socket.close() } catch (_: IOException) {}
            return
        }
        links[peer] = link
        // Told before anything can arrive from them.
        plugin.tell("bt_connected", "peer" to peer)
        Thread({ writeLoop(peer, link) }, "SnapRacers-bt-write-$peer").start()
        Thread({ readLoop(peer, link) }, "SnapRacers-bt-read-$peer").start()
    }

    private fun writeLoop(peer: Int, link: Link) {
        try {
            while (link.open) {
                val data = link.waiting.poll(250, TimeUnit.MILLISECONDS) ?: continue
                val size = data.size
                link.output.write(byteArrayOf((size ushr 24).toByte(), (size ushr 16).toByte(), (size ushr 8).toByte(), size.toByte()))
                link.output.write(data)
                link.output.flush()
            }
        } catch (e: IOException) {
            if (link.open) Log.w(TAG, "couldn't send to $peer", e)
        } catch (e: InterruptedException) {
            // Closing.
        }
        close(peer)
    }

    private fun readLoop(peer: Int, link: Link) {
        val header = ByteArray(4)
        try {
            val input = link.socket.inputStream
            while (link.open) {
                if (!readFully(input, header)) break
                val size = ((header[0].toInt() and 0xff) shl 24) or ((header[1].toInt() and 0xff) shl 16) or
                    ((header[2].toInt() and 0xff) shl 8) or (header[3].toInt() and 0xff)
                // A size that's wrong is wrong by a lot, and making room for
                // it is how a broken stream turns into a crash.
                if (size <= 0 || size > MOST_BYTES) {
                    Log.e(TAG, "$peer sent a packet $size bytes long")
                    break
                }
                val data = ByteArray(size)
                if (!readFully(input, data)) break
                plugin.tell("bt_packet", "peer" to peer, "data" to data)
            }
        } catch (e: IOException) {
            if (link.open) Log.w(TAG, "lost $peer", e)
        }
        close(peer)
    }

    private fun readFully(input: InputStream, into: ByteArray): Boolean {
        var got = 0
        while (got < into.size) {
            val read = input.read(into, got, into.size - got)
            if (read <= 0) return false
            got += read
        }
        return true
    }

    /** Closes a link and tells the game once, however it ended. */
    private fun close(peer: Int) {
        val link = links.remove(peer) ?: return
        link.open = false
        try {
            link.socket.close()
        } catch (e: IOException) {
            // Already closed.
        }
        plugin.tell("bt_left", "peer" to peer)
    }
}
