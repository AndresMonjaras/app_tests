import java.util.Properties

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.inputStream().use(localProperties::load)
}
val facebookAppId = localProperties.getProperty("FACEBOOK_APP_ID", "")
val facebookClientToken = localProperties.getProperty("FACEBOOK_CLIENT_TOKEN", "")
val googleMapsApiKey = localProperties.getProperty("GOOGLE_MAPS_API_KEY", "")

android {
    namespace = "com.lincefood.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.lincefood.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["GOOGLE_MAPS_API_KEY"] = googleMapsApiKey
        manifestPlaceholders["FACEBOOK_APP_ID"] = facebookAppId
        manifestPlaceholders["FACEBOOK_CLIENT_TOKEN"] = facebookClientToken
        manifestPlaceholders["FACEBOOK_LOGIN_PROTOCOL_SCHEME"] = "fb$facebookAppId"
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
