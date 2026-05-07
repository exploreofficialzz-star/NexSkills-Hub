# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Google Mobile Ads
-keep class com.google.android.gms.ads.** { *; }

# In-App Purchase
-keep class com.android.vending.billing.** { *; }

# Hive
-keep class com.hive.** { *; }

# WebView
-keep class com.pichillilorenzo.flutter_inappwebview.** { *; }

# Kotlin
-keep class kotlin.** { *; }
-keep class kotlinx.** { *; }

# General
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**

# ─── Play Core (Flutter deferred components) ─────────────────────
# Flutter's PlayStoreDeferredComponentManager references Play Core
# split-install classes at compile time. This app doesn't use
# deferred components, so we suppress the missing-class R8 errors.
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
-keep class com.google.android.play.core.splitcompat.SplitCompatApplication { *; }
-keep class com.google.android.play.core.splitinstall.** { *; }
-keep class com.google.android.play.core.tasks.** { *; }
