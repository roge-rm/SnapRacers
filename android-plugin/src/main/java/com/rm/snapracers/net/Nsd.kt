package com.rm.snapracers.net

import android.content.Context
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.util.Log

/**
 * Finding games on the same Wi-Fi with NSD (mDNS), the way ScorchDroid's
 * LanDiscovery does. A phone hosting a game puts out a `_snapracers._udp`
 * service, and so does the dedicated server's admin page (see
 * server/web-admin/app/discovery.py). It only finds games: the racing itself
 * is ENet, to the address this turns up.
 *
 * Everything here runs on the main thread.
 */
class Nsd(private val plugin: SnapRacersNet) {
    companion object {
        private const val TAG = "SnapRacersNsd"
        const val SERVICE_TYPE = "_snapracers._udp."
    }

    private var manager: NsdManager? = null
    private var registration: NsdManager.RegistrationListener? = null
    private var discovery: NsdManager.DiscoveryListener? = null

    private fun manager(): NsdManager? {
        if (manager == null) {
            manager = plugin.appContext?.getSystemService(Context.NSD_SERVICE) as? NsdManager
        }
        return manager
    }

    fun advertise(name: String, port: Int) {
        stopAdvertising()
        val nsd = manager() ?: return
        plugin.holdMulticast("nsd advertising")
        val info = NsdServiceInfo().apply {
            serviceName = name
            serviceType = SERVICE_TYPE
            setPort(port)
        }
        val listener = object : NsdManager.RegistrationListener {
            override fun onServiceRegistered(info: NsdServiceInfo) {
                Log.i(TAG, "advertising ${info.serviceName}")
            }
            override fun onRegistrationFailed(info: NsdServiceInfo, errorCode: Int) {
                Log.e(TAG, "couldn't advertise (error $errorCode)")
            }
            override fun onServiceUnregistered(info: NsdServiceInfo) {}
            override fun onUnregistrationFailed(info: NsdServiceInfo, errorCode: Int) {}
        }
        registration = listener
        nsd.registerService(info, NsdManager.PROTOCOL_DNS_SD, listener)
    }

    fun stopAdvertising() {
        registration?.let {
            try {
                manager?.unregisterService(it)
            } catch (e: IllegalArgumentException) {
                // It never got going, or it's already stopped.
            }
        }
        registration = null
        plugin.letGoMulticast("nsd advertising")
    }

    /** Looks until [stopLooking], telling the game about each game found. */
    fun look() {
        stopLooking()
        val nsd = manager() ?: return
        plugin.holdMulticast("nsd looking")
        val listener = object : NsdManager.DiscoveryListener {
            override fun onDiscoveryStarted(serviceType: String) {
                Log.i(TAG, "looking")
            }
            override fun onServiceFound(service: NsdServiceInfo) {
                @Suppress("DEPRECATION")
                nsd.resolveService(service, object : NsdManager.ResolveListener {
                    override fun onResolveFailed(info: NsdServiceInfo, errorCode: Int) {
                        Log.w(TAG, "couldn't find where ${info.serviceName} is (error $errorCode)")
                    }
                    override fun onServiceResolved(info: NsdServiceInfo) {
                        @Suppress("DEPRECATION")
                        val address = info.host?.hostAddress ?: return
                        plugin.tell(
                            "found", "how" to "nsd", "name" to info.serviceName,
                            "address" to address, "port" to info.port,
                        )
                    }
                })
            }
            override fun onServiceLost(service: NsdServiceInfo) {
                plugin.tell("lost", "how" to "nsd", "name" to service.serviceName)
            }
            override fun onDiscoveryStopped(serviceType: String) {}
            override fun onStartDiscoveryFailed(serviceType: String, errorCode: Int) {
                Log.e(TAG, "couldn't start looking (error $errorCode)")
            }
            override fun onStopDiscoveryFailed(serviceType: String, errorCode: Int) {}
        }
        discovery = listener
        nsd.discoverServices(SERVICE_TYPE, NsdManager.PROTOCOL_DNS_SD, listener)
    }

    fun stopLooking() {
        discovery?.let {
            try {
                manager?.stopServiceDiscovery(it)
            } catch (e: IllegalArgumentException) {
                // Already stopped.
            }
        }
        discovery = null
        plugin.letGoMulticast("nsd looking")
    }
}
