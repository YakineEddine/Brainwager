import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing : android/key.properties local (jamais commité, voir
// android/key.properties.example). Absent en CI/repo => le build release
// échoue avec une erreur explicite (fail-closed), jamais de clé debug.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

fun hasReleaseSigning(): Boolean {
    if (!keystorePropertiesFile.exists()) return false
    return listOf("storePassword", "keyPassword", "keyAlias", "storeFile").all {
        !keystoreProperties.getProperty(it).isNullOrEmpty()
    }
}

android {
    namespace = "com.yakineeddine.brainwager"
    // Exigence Play (nouvelles apps depuis 31/08/2026) : API 36 / Android 16.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.yakineeddine.brainwager"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = 36
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
            storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
            storePassword = keystoreProperties.getProperty("storePassword")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

// Fail-closed : une tâche release/assemble/bundle sans key.properties
// (ou incomplet) échoue avec un message clair. Debug/profile non affectés.
gradle.taskGraph.whenReady {
    val wantsRelease = allTasks.any { task ->
        val name = task.name.lowercase()
        name.contains("release") &&
            (name.contains("assemble") || name.contains("bundle"))
    }
    if (wantsRelease && !hasReleaseSigning()) {
        throw GradleException(
            "Release signing not configured: create android/key.properties " +
                "(storePassword, keyPassword, keyAlias, storeFile) from " +
                "android/key.properties.example. Never commit the keystore or " +
                "key.properties. Debug/profile builds are unaffected."
        )
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
