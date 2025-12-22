plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

import java.util.Properties
import java.io.FileInputStream
import java.util.Base64
import java.io.File
import java.io.FileOutputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.XXXppp233.FCMBox"
    compileSdk = flutter.compileSdkVersion
    // ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    signingConfigs {
        create("release") {
            val envKeyAlias = System.getenv("KEY_STORE_ALIAS")
            val envKeyPassword = System.getenv("KEY_PASSWORD")
            val envStorePassword = System.getenv("KEY_STORE_PASSWORD")
            val envStoreBase64 = System.getenv("KEY_STORE_BASE64")

            keyAlias = keystoreProperties["keyAlias"] as String? ?: envKeyAlias
            keyPassword = keystoreProperties["keyPassword"] as String? ?: envKeyPassword
            storePassword = keystoreProperties["storePassword"] as String? ?: envStorePassword
            
            val propStoreFile = keystoreProperties["storeFile"] as String?
            if (propStoreFile != null) {
                storeFile = file(propStoreFile)
            } else if (envStoreBase64 != null) {
                val keystoreFile = File(rootProject.buildDir, "release.jks")
                keystoreFile.parentFile.mkdirs()
                try {
                    val decodedBytes = Base64.getDecoder().decode(envStoreBase64)
                    FileOutputStream(keystoreFile).use { it.write(decodedBytes) }
                    storeFile = keystoreFile
                } catch (e: Exception) {
                    println("Failed to decode KEY_STORE_BASE64: ${e.message}")
                }
            }
        }
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.XXXppp233.FCMBox"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        ndk {
            abiFilters.add("arm64-v8a")
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
