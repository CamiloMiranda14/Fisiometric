pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    // AGP 9.x hard-fails the build when two Android library artifacts share
    // the same manifest namespace — a known, still-open upstream issue with
    // published TensorFlow Lite artifacts (org.tensorflow.lite is declared
    // by tensorflow-lite, tensorflow-lite-gpu AND tensorflow-lite-api,
    // pulled in transitively by flutter_pose_detection's MediaPipe
    // dependency). AGP 8.x only warns about this instead of failing, so
    // pinned to the latest stable 8.x (supports compileSdk 36) until the
    // TF Lite artifacts are republished with unique namespaces.
    id("com.android.application") version "8.10.0" apply false
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
}

include(":app")
