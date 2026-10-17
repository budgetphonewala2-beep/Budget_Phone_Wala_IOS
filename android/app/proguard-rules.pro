# Razorpay
-keepattributes *Annotation*
-dontwarn com.razorpay.**
-keep class com.razorpay.** {*;}
-optimizations !method/inlining/*
-keepclasseswithmembers class * { public void onPayment*(...); }
-keep class proguard.annotation.Keep
-keep class proguard.annotation.KeepClassMembers
-dontwarn proguard.annotation.**
