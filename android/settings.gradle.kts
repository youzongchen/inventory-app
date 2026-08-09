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
    // Pinned to a stable AGP 8.x line: AGP 9's "Built-in Kotlin" default doesn't
    // actually compile the Kotlin sources of file_picker/mobile_scanner in this
    // setup (both plugins detect AGP9 and skip applying their own Kotlin plugin,
    // expecting AGP to do it - it doesn't, so their classes go missing at link time).
    // AGP 8.x restores the traditional path where each plugin applies its own KGP.
    id("com.android.application") version "8.13.2" apply false
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
}

include(":app")
