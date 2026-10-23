plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "org.example.xxread"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.yidu.reader"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // 固定 release 签名：CI 每次生成的 debug 密钥都不同，会导致安装时签名冲突、
    // 必须卸载旧版本才能装新版。这里用仓库内固定的 PKCS12 密钥，保证可以覆盖升级。
    signingConfigs {
        create("release") {
            storeFile = file("yidu-release.p12")
            // 密码由 CI 通过环境变量传入，源码不留明文。
            storePassword = System.getenv("YIDU_STORE_PASSWORD")
            keyAlias = "yidu"
            keyPassword = System.getenv("YIDU_KEY_PASSWORD")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
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
