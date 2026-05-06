// Copyright (c) Simi Connect — Next Support fork.
// Original work: RustDesk, GPL-3.0. This file is GPL-3.0.
// Modifications: see git history of SIMI-CONNECT/simi-next-support-android.
//
// build.gradle.simi.kts — Simi Next Support overrides applied on top of
// upstream RustDesk's flutter/android/app/build.gradle.kts.
//
// Wiring:
//   This snippet is included from the upstream build.gradle.kts via a
//   line added by patches/0001-applicationId-build-arg.patch:
//
//       apply(from = "build.gradle.simi.kts")
//
//   That patch also rewrites the upstream `applicationId = "..."` line
//   to read from the Gradle property `simi.applicationId` (with a
//   default that matches what we set below), so everything funnels
//   through one place.
//
// Build-arg contract (passed by CI via -P, defaulted here for local
// smoke builds — never commit real values):
//   simi.applicationId       Android applicationId (default below)
//   simi.versionName         human version, e.g. "0.1.0"
//   simi.versionCode         monotonic int, e.g. 1
//   simi.rendezvousServer    e.g. help.simiconnect.com
//   simi.rsPubKey            base64 ed25519 pubkey from server/data/id_ed25519.pub
//   simi.apiServer           usually empty (we don't run RustDesk Pro)
//   simi.backendBaseUrl      Simi backend, e.g. https://api.simiconnect.com
//
// All four runtime values are exposed two ways:
//   1. BuildConfig.<NAME>            — for Kotlin / Java code
//   2. manifestPlaceholders["<key>"] — for AndroidManifest <meta-data>
//                                       and for string resources
//                                       (simi-config.xml uses these)

import com.android.build.gradle.AppExtension

fun prop(key: String, default: String): String =
    (project.findProperty(key) as String?) ?: default

val simiApplicationId    = prop("simi.applicationId",    "com.simiconnect.next.support")
val simiVersionName      = prop("simi.versionName",      "0.1.0-dev")
val simiVersionCode      = prop("simi.versionCode",      "1").toInt()
val simiRendezvousServer = prop("simi.rendezvousServer", "help.simiconnect.com")
val simiRsPubKey         = prop("simi.rsPubKey",         "PLACEHOLDER_RS_PUB_KEY")
val simiApiServer        = prop("simi.apiServer",        "")
val simiBackendBaseUrl   = prop("simi.backendBaseUrl",   "https://api.simiconnect.example")

extensions.configure<AppExtension>("android") {
    defaultConfig {
        applicationId = simiApplicationId
        versionName   = simiVersionName
        versionCode   = simiVersionCode

        // BuildConfig fields — referenced from Kotlin / Java glue and
        // (via patches/0002-rendezvous-key-from-buildconfig.patch) from
        // the Dart bridge layer through --dart-define mirrors injected
        // by the Flutter wrapper.
        buildConfigField("String", "SIMI_RENDEZVOUS_SERVER", "\"$simiRendezvousServer\"")
        buildConfigField("String", "SIMI_RS_PUB_KEY",        "\"$simiRsPubKey\"")
        buildConfigField("String", "SIMI_API_SERVER",        "\"$simiApiServer\"")
        buildConfigField("String", "SIMI_BACKEND_BASE_URL",  "\"$simiBackendBaseUrl\"")

        // Manifest placeholders — back the values referenced from
        // simi-config.xml as ${simiRendezvousServer} etc., and from
        // AndroidManifest.xml <meta-data android:value="${...}"/>.
        manifestPlaceholders["simiRendezvousServer"] = simiRendezvousServer
        manifestPlaceholders["simiRsPubKey"]         = simiRsPubKey
        manifestPlaceholders["simiApiServer"]        = simiApiServer
        manifestPlaceholders["simiBackendBaseUrl"]   = simiBackendBaseUrl
    }

    buildFeatures {
        buildConfig = true
    }
}

// Mirror Gradle props into --dart-define so Flutter sees the same values.
// The Flutter Gradle plugin reads `dart-defines` from extra properties.
project.extensions.extraProperties.set(
    "dart-defines",
    listOf(
        "SIMI_RENDEZVOUS_SERVER=$simiRendezvousServer",
        "SIMI_RS_PUB_KEY=$simiRsPubKey",
        "SIMI_API_SERVER=$simiApiServer",
        "SIMI_BACKEND_BASE_URL=$simiBackendBaseUrl",
    ).joinToString(",")
)
