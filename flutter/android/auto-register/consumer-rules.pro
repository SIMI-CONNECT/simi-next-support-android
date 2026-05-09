# Keep retrofit + moshi reflective access.
-keep class com.simiconnect.next.support.autoregister.** { *; }
-keepclassmembers class * extends androidx.work.CoroutineWorker {
    public <init>(...);
}

# JNA — required by lazysodium-android. JNA's native methods initIDs()
# resolve Java fields by name at runtime; R8 obfuscation strips the
# field/class names and breaks the native binding with
# `Can't obtain peer field ID for class com.sun.jna.Pointer`.
-keep class com.sun.jna.** { *; }
-keep class * extends com.sun.jna.** { *; }
-keepclassmembers class * extends com.sun.jna.Structure {
    *;
}

# Lazysodium — keeps the native interface bindings findable.
-keep class com.goterl.lazysodium.** { *; }
-keepnames class com.goterl.lazysodium.**

# Retrofit + Moshi reflective method/field access.
-keep,allowobfuscation,allowshrinking interface retrofit2.Call
-keep,allowobfuscation,allowshrinking class retrofit2.Response
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.squareup.moshi.** { *; }

# Keep Kotlin metadata + the API DTOs so KotlinJsonAdapterFactory can
# read property names and constructor params reflectively.
-keepattributes RuntimeVisible*Annotations
-keep class kotlin.Metadata { *; }
-keep class kotlin.reflect.** { *; }
-keep class com.simiconnect.next.support.autoregister.SupportRegistrationRequest { *; }
-keep class com.simiconnect.next.support.autoregister.SupportRegistrationResponse { *; }
-keepclassmembers class com.simiconnect.next.support.autoregister.SupportRegistration* {
    <init>(...);
    <fields>;
}
