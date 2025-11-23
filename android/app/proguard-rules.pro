# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-keep class io.flutter.embedding.** { *; }

# Keep InAppWebView classes
-keep class com.pichillilorenzo.flutter_inappwebview.** { *; }
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# Keep Hive
-keep class * extends hive.HiveObject { *; }
-keep @interface hive.HiveField

# Gson
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.examples.android.model.** { <fields>; }
-keep class * implements com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Preserve line numbers for debugging
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# Play Core library (optional features)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# Ignore missing Play Store classes
-dontnote com.google.android.play.core.splitcompat.SplitCompatApplication
-dontnote com.google.android.play.core.splitinstall.**

# Optimization settings
-optimizationpasses 5
-dontusemixedcaseclassnames
-dontskipnonpubliclibraryclasses
-verbose

# Remove logging in release builds
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}

# Remove debug code
-assumenosideeffects class kotlin.jvm.internal.Intrinsics {
    static void checkParameterIsNotNull(java.lang.Object, java.lang.String);
}

# Keep data classes for JSON serialization
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Keep Riverpod providers
-keep class * extends io.flutter.riverpod.StateNotifier { *; }
-keep class * extends io.flutter.riverpod.Provider { *; }

# Keep Dio classes for network
-keep class dio.** { *; }
-keep interface dio.** { *; }

# Keep Hive models
-keep class * extends hive.TypeAdapter { *; }
-keep @hive.HiveType class * { *; }

# Keep data models for JSON serialization
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Remove unused code
-assumenosideeffects class kotlin.jvm.internal.Intrinsics {
    static void checkParameterIsNotNull(java.lang.Object, java.lang.String);
}

# Optimize string operations
-optimizations !code/simplification/arithmetic,!code/simplification/cast,!field/*,!class/merging/*

