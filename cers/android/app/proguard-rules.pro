# Flutter specific
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Keep model classes used by Firestore
-keepclassmembers class * {
    @com.google.firebase.firestore.PropertyName *;
}

# Keep Gson/Serialization
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.** { *; }
-keepattributes EnclosingMethod

# Keep HTTP client
-keep class org.apache.http.** { *; }
-dontwarn org.apache.http.**
-dontwarn android.net.http.AndroidHttpClient

# Keep geolocator
-keep class com.baseflow.geolocator.** { *; }

# Keep image_picker
-keep class io.flutter.plugins.imagepicker.** { *; }

# Keep permission_handler
-keep class com.baseflow.permissionhandler.** { *; }