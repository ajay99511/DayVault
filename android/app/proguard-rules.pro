# ProGuard rules for DayVault

# flutter_gemma / MediaPipe - Suppress warnings for missing protobuf classes
# These classes are referenced via reflection/optional dependencies
-dontwarn com.google.mediapipe.proto.**
-dontwarn com.google.mediapipe.framework.**
-dontwarn com.google.mediapipe.**
-dontwarn com.google.protobuf.**

# Flutter Play Core Deferred Components - Suppress warnings
# Flutter references these but we don't use deferred components
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
-dontwarn com.google.android.play.core.splitcompat.**

# Keep MediaPipe classes that ARE present
-keep class com.google.mediapipe.** { *; }

# Keep all proto classes from obfuscation
-keep class com.google.protobuf.** { *; }

# flutter_gemma
-keep class org.flutter_gemma.** { *; }

# ML Kit GenAI
-keep class com.google.mlkit.genai.** { *; }

# LiteRT / TensorFlow Lite
-keep class org.tensorflow.lite.** { *; }
-keep class org.tensorflow.lite.support.** { *; }

# Keep native methods
-keepclasseswithmembernames,includedescriptorclasses class * {
    native <methods>;
}

# Keep Flutter classes
-keep class io.flutter.** { *; }
-keep class com.example.dayvault.** { *; }

