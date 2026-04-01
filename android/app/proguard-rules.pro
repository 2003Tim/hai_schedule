# flutter_local_notifications uses Gson TypeToken for serializing scheduled notifications.
# R8 strips generic signatures by default, causing TypeToken to crash at runtime.
# These rules preserve the signatures so Gson can reflect on them.
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keep class com.dexterous.flutterlocalnotifications.** { *; }
