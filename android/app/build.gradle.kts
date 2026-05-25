import java.io.FileInputStream
import java.util.Properties
import org.gradle.api.GradleException

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val rootKeyPropertiesFile = rootProject.file("key.properties")
val appKeyPropertiesFile = project.file("key.properties")
val keyPropertiesFile = when {
    rootKeyPropertiesFile.exists() -> rootKeyPropertiesFile
    appKeyPropertiesFile.exists() -> appKeyPropertiesFile
    else -> null
}
if (keyPropertiesFile != null) {
    keystoreProperties.load(FileInputStream(keyPropertiesFile))
}
val requiredSigningProperties = listOf(
    "storeFile",
    "storePassword",
    "keyAlias",
    "keyPassword",
)
fun signingProperty(name: String): String? =
    keystoreProperties.getProperty(name)?.trim()?.takeIf { it.isNotEmpty() }

val hasCompleteReleaseSigning =
    keyPropertiesFile != null && requiredSigningProperties.all { signingProperty(it) != null }
if (keyPropertiesFile != null && !hasCompleteReleaseSigning) {
    throw GradleException(
        "Release signing file ${keyPropertiesFile.path} is missing one of: " +
            requiredSigningProperties.joinToString(", ")
    )
}
val releaseStoreFile = signingProperty("storeFile")?.let { rootProject.file(it) }
val canSignRelease = hasCompleteReleaseSigning && releaseStoreFile?.exists() == true
val requestedReleaseBuild = gradle.startParameter.taskNames.any {
    it.contains("Release", ignoreCase = true)
}
if (requestedReleaseBuild && !canSignRelease) {
    throw GradleException(
        "Release build requires android/key.properties (or android/app/key.properties) " +
            "and a valid keystore file. Example storeFile: app/upload-keystore.jks"
    )
}

android {
    namespace = "com.taichi963.tikbox"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.taichi963.tikbox"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (canSignRelease) {
            create("release") {
                keyAlias = signingProperty("keyAlias")
                keyPassword = signingProperty("keyPassword")
                storeFile = releaseStoreFile
                storePassword = signingProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            if (canSignRelease) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

flutter {
    source = "../.."
}
