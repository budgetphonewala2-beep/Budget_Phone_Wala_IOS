# Razorpay
-keepattributes *Annotation*
-dontwarn com.razorpay.**
-keep class com.razorpay.** {*;}
-optimizations !method/inlining/*
-keepclasseswithmembers class * { public void onPayment*(...); }
-keep class proguard.annotation.Keep
-keep class proguard.annotation.KeepClassMembers
-dontwarn proguard.annotation.**

# Flutter plugins use generated Pigeon/Kotlin-coroutine interfaces that R8 must not rename or strip
-keep class io.flutter.plugins.** { *; }
-keep class dev.flutter.pigeon.** { *; }
-keep class kotlin.coroutines.Continuation { *; }
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**
-keep class kotlin.** { *; }
-keep class kotlinx.coroutines.** { *; }
-keep class androidx.datastore.** { *; }
-dontwarn kotlinx.**
