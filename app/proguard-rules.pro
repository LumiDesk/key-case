# KeyCase release rules
#
# This is an open-source app: keep readable names. R8 is still useful for
# shrinking unused code and optimizing the release APK.
-dontobfuscate

-keepattributes *Annotation*,InnerClasses,EnclosingMethod,Signature,Exceptions,SourceFile,LineNumberTable

# Kotlin serialization generates serializers and companion accessors reflectively.
-keepclassmembers class **$$serializer {
    *;
}
-keepclasseswithmembers class ** {
    kotlinx.serialization.KSerializer serializer(...);
}
-keepclassmembers class **$Companion {
    kotlinx.serialization.KSerializer serializer(...);
}

# Vault models are the serialized on-disk contract; keep their names and fields.
-keep class top.talyra42.keycase.core.model.** { *; }
-keep class top.talyra42.keycase.core.crypto.KdfParams { *; }

# Argon2 is reached through BouncyCastle implementation classes.
-keep class org.bouncycastle.crypto.generators.Argon2BytesGenerator { *; }
-keep class org.bouncycastle.crypto.params.Argon2Parameters { *; }
-keep class org.bouncycastle.crypto.params.Argon2Parameters$Builder { *; }

# AndroidSVG resolves a few parser/rendering classes by name.
-keep class com.caverock.androidsvg.** { *; }

# The Kotlin collections workaround for R8 on this toolchain.
-keep class kotlin.collections.** { *; }
