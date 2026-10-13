plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}
val uploadKeystorePath = System.getenv("DALI_ANDROID_UPLOAD_KEYSTORE")
val uploadStorePassword = System.getenv("DALI_ANDROID_UPLOAD_STORE_PASSWORD")
val uploadKeyAlias = System.getenv("DALI_ANDROID_UPLOAD_KEY_ALIAS")
val uploadKeyPassword = System.getenv("DALI_ANDROID_UPLOAD_KEY_PASSWORD")

if (releaseRequested) {
    check(
        listOf(uploadKeystorePath, uploadStorePassword, uploadKeyAlias, uploadKeyPassword)
            .all { !it.isNullOrBlank() }
    ) {
        "Android Release requires DALI_ANDROID_UPLOAD_KEYSTORE, " +
            "DALI_ANDROID_UPLOAD_STORE_PASSWORD, DALI_ANDROID_UPLOAD_KEY_ALIAS, " +
            "and DALI_ANDROID_UPLOAD_KEY_PASSWORD."
    }
    check(file(uploadKeystorePath!!).isFile) {
        "Android upload keystore file does not exist."
    }
}

android {
    namespace = "com.dalicamera.dali_camera"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = if (System.getenv("DALI_ANDROID_TEST_APP") == "true")
            "com.dalicamera.dali_camera.test" else "com.dalicamera.dali_camera"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseRequested) {
            create("upload") {
                storeFile = file(uploadKeystorePath!!)
                storePassword = uploadStorePassword
                keyAlias = uploadKeyAlias
                keyPassword = uploadKeyPassword
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("upload")
        }
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
