package com.simiconnect.next.support.autoregister

import okhttp3.Interceptor
import okhttp3.Response

/**
 * Mirrors `simi-next-android`'s [DeviceHeadersInterceptor] header set
 * for device-facing routes — `device-access-key`, `mac-address`,
 * `x-app-version`, `x-app-build`. The Next Support APK is the SAME
 * device from the backend's point of view, so it must present the
 * same headers; otherwise the backend's
 * `ValidateDeviceAccessKeyGuard` 422s.
 *
 * Only the `support-registration` endpoint is hit from this module
 * and it is device-facing, so the device-access-key header is
 * unconditionally added. If you ever extend the API surface here,
 * gate by path the same way `simi-next-android` does.
 *
 * TODO(verify): mac-address derivation — confirm with operators that
 * `pairingProvider().macAddress` matches the value
 * `simi-next-android`'s `DeviceIdentity.deviceMacAddress` produces
 * (ANDROID_ID-derived). The pairing ContentProvider is the canonical
 * source: as long as both apps read it from the same provider, drift
 * is impossible by construction.
 */
class SupportDeviceHeadersInterceptor(
    private val appVersion: String,
    private val appBuild: Int,
    private val pairingProvider: () -> DeviceCredentials,
) : Interceptor {

    override fun intercept(chain: Interceptor.Chain): Response {
        val pairing = pairingProvider()
        val req = chain.request().newBuilder()
            .addHeader("x-app-version", appVersion)
            .addHeader("x-app-build", appBuild.toString())
            .addHeader("mac-address", pairing.macAddress)
            .addHeader("device-access-key", pairing.deviceAccessKey)
            .build()
        return chain.proceed(req)
    }
}
