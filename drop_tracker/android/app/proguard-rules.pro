# Minification is currently disabled for the release build type (see the
# comment in build.gradle.kts) after a confirmed crash caused by R8 stripping
# generic-type metadata that Gson's reflection-based TypeToken deserialization
# needs — used internally by flutter_local_notifications to persist its own
# scheduled-notification cache (FlutterLocalNotificationsPlugin.
# saveScheduledNotification -> loadScheduledNotifications), which crashed with
# "java.lang.RuntimeException: Missing type parameter" on every single
# scheduled dose, in a tight loop, on a real device.
#
# These rules are kept here, ready to go, for whenever minification is
# re-enabled (e.g. for a real Play Store release) — but re-enabling it
# requires re-verifying notification scheduling end-to-end on a real device
# again before shipping, not just trusting these rules are sufficient.

# Keep generic signatures — required for Gson's TypeToken-based reflection to
# resolve parameterized types (List<T>, Map<K,V>, ...) at runtime.
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# Gson itself.
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken

# flutter_local_notifications' own model classes, which Gson (de)serializes
# reflectively for the scheduled-notification cache and the boot receiver.
-keep class com.dexterous.flutterlocalnotifications.models.** { *; }
-keep class com.dexterous.flutterlocalnotifications.** { *; }
