package com.simiconnect.next.support.autoregister

import android.content.Context
import com.simiconnect.next.support.BuildConfig
import com.squareup.moshi.Moshi
import com.squareup.moshi.kotlin.reflect.KotlinJsonAdapterFactory
import okhttp3.OkHttpClient
import retrofit2.Response
import retrofit2.Retrofit
import retrofit2.converter.moshi.MoshiConverterFactory
import retrofit2.http.Body
import retrofit2.http.POST
import java.util.concurrent.TimeUnit

// `@JsonClass(generateAdapter = true)` would require the moshi-codegen
// KSP. We don't wire that here; KotlinJsonAdapterFactory + reflection
// is plenty for two trivial DTOs.
data class SupportRegistrationRequest(
    val rustdesk_id: String,
    val password_ciphertext: String,
    val client_pub_key_fp: String,
)

data class SupportRegistrationResponse(val ok: Boolean = true)

interface SupportAutoRegisterApi {

    @POST("user/device/support-registration")
    suspend fun register(
        @Body body: SupportRegistrationRequest,
    ): Response<SupportRegistrationResponse>

    companion object {
        fun build(
            context: Context,
            pairing: DeviceCredentials,
        ): SupportAutoRegisterApi {
            val client = OkHttpClient.Builder()
                .addInterceptor(
                    SupportDeviceHeadersInterceptor(
                        appVersion = BuildConfig.VERSION_NAME,
                        appBuild = BuildConfig.VERSION_CODE,
                        pairingProvider = { pairing },
                    ),
                )
                .connectTimeout(15, TimeUnit.SECONDS)
                .readTimeout(30, TimeUnit.SECONDS)
                .writeTimeout(30, TimeUnit.SECONDS)
                .build()

            val moshi = Moshi.Builder()
                .add(KotlinJsonAdapterFactory())
                .build()

            return Retrofit.Builder()
                .baseUrl(ensureTrailingSlash(BuildConfig.BACKEND_BASE_URL))
                .client(client)
                .addConverterFactory(MoshiConverterFactory.create(moshi))
                .build()
                .create(SupportAutoRegisterApi::class.java)
        }

        private fun ensureTrailingSlash(s: String): String =
            if (s.endsWith("/")) s else "$s/"
    }
}
