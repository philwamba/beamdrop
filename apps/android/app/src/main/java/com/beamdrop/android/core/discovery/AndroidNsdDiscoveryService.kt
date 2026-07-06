package com.beamdrop.android.core.discovery

import android.content.Context
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.os.Build
import com.beamdrop.android.core.pairing.DeviceIdentity
import com.beamdrop.android.core.pairing.EndpointHint

class AndroidNsdDiscoveryService(context: Context) : BeamDropDiscoveryService {
    private val nsdManager = context.getSystemService(Context.NSD_SERVICE) as NsdManager
    private var registrationListener: NsdManager.RegistrationListener? = null
    private var discoveryListener: NsdManager.DiscoveryListener? = null

    override fun register(identity: DeviceIdentity, port: Int, onFailure: (String) -> Unit) {
        val serviceInfo = NsdServiceInfo().apply {
            serviceName = identity.displayName
            serviceType = BEAMDROP_NSD_SERVICE_TYPE
            this.port = port
            setAttribute("device_id", identity.deviceId)
            setAttribute("platform", identity.platform.wireName)
            setAttribute("protocol", identity.protocolVersion.toString())
            setAttribute("public_key", identity.publicKey)
        }

        val listener = object : NsdManager.RegistrationListener {
            override fun onServiceRegistered(info: NsdServiceInfo) = Unit
            override fun onRegistrationFailed(info: NsdServiceInfo, errorCode: Int) {
                onFailure("NSD registration failed: $errorCode")
            }

            override fun onServiceUnregistered(info: NsdServiceInfo) = Unit
            override fun onUnregistrationFailed(info: NsdServiceInfo, errorCode: Int) {
                onFailure("NSD unregistration failed: $errorCode")
            }
        }
        registrationListener = listener
        nsdManager.registerService(serviceInfo, NsdManager.PROTOCOL_DNS_SD, listener)
    }

    override fun discover(onEvent: (DiscoveryEvent) -> Unit) {
        val listener = object : NsdManager.DiscoveryListener {
            override fun onDiscoveryStarted(serviceType: String) {
                onEvent(DiscoveryEvent.Started)
            }

            override fun onServiceFound(serviceInfo: NsdServiceInfo) {
                if (serviceInfo.serviceType != BEAMDROP_NSD_SERVICE_TYPE) return
                nsdManager.resolveServiceCompat(serviceInfo) { resolved, error ->
                    if (resolved != null) {
                        onEvent(DiscoveryEvent.Found(resolved.toDiscoveredService()))
                    } else {
                        onEvent(DiscoveryEvent.Failed("NSD resolve failed: $error"))
                    }
                }
            }

            override fun onServiceLost(serviceInfo: NsdServiceInfo) {
                onEvent(DiscoveryEvent.Lost(serviceInfo.serviceName))
            }

            override fun onDiscoveryStopped(serviceType: String) {
                onEvent(DiscoveryEvent.Stopped)
            }

            override fun onStartDiscoveryFailed(serviceType: String, errorCode: Int) {
                onEvent(DiscoveryEvent.Failed("NSD discovery failed: $errorCode"))
                stop()
            }

            override fun onStopDiscoveryFailed(serviceType: String, errorCode: Int) {
                onEvent(DiscoveryEvent.Failed("NSD stop failed: $errorCode"))
            }
        }
        discoveryListener = listener
        nsdManager.discoverServices(BEAMDROP_NSD_SERVICE_TYPE, NsdManager.PROTOCOL_DNS_SD, listener)
    }

    override fun stop() {
        discoveryListener?.let { runCatching { nsdManager.stopServiceDiscovery(it) } }
        registrationListener?.let { runCatching { nsdManager.unregisterService(it) } }
        discoveryListener = null
        registrationListener = null
    }

    private fun NsdManager.resolveServiceCompat(
        serviceInfo: NsdServiceInfo,
        callback: (NsdServiceInfo?, Int?) -> Unit,
    ) {
        @Suppress("DEPRECATION")
        resolveService(
            serviceInfo,
            object : NsdManager.ResolveListener {
                override fun onResolveFailed(info: NsdServiceInfo, errorCode: Int) {
                    callback(null, errorCode)
                }

                override fun onServiceResolved(info: NsdServiceInfo) {
                    callback(info, null)
                }
            },
        )
    }

    private fun NsdServiceInfo.toDiscoveredService(): DiscoveredBeamDropService {
        val hostAddress = if (Build.VERSION.SDK_INT >= 34) {
            hostAddresses.firstOrNull()?.hostAddress
        } else {
            @Suppress("DEPRECATION")
            host?.hostAddress
        }
        return DiscoveredBeamDropService(
            serviceInstanceName = serviceName,
            endpoint = EndpointHint(host = hostAddress, port = port, route = "local"),
            deviceId = attribute("device_id"),
            displayName = serviceName,
            publicKey = attribute("public_key"),
        )
    }

    private fun NsdServiceInfo.attribute(name: String): String? =
        attributes[name]?.toString(Charsets.UTF_8)
}
