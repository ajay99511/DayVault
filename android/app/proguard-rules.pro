# ProGuard rules for DayVault

# Keep native methods
-keepclasseswithmembernames,includedescriptorclasses class * {
    native <methods>;
}

# Keep Flutter classes
-keep class io.flutter.** { *; }
-keep class com.example.dayvault.** { *; }

# Keep Google Play Core classes (required for Flutter deferred components)
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# Keep Google Play Install Referrer
-keep class com.google.android.finsky.installation.** { *; }
-dontwarn com.google.android.finsky.installation.**

# Keep Android Billing
-keep class com.android.billingclient.** { *; }
-dontwarn com.android.billingclient.**
