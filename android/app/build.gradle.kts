import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = listOf(
    rootProject.file("local/key.properties"),
    rootProject.file("key.properties"),
).firstOrNull { it.exists() }
if (keystorePropertiesFile != null) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

android {
    namespace = "com.hainanu.hai_schedule"
    compileSdk = maxOf(flutter.compileSdkVersion, 34)
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.hainanu.hai_schedule"
        minSdk = flutter.minSdkVersion
        multiDexEnabled = true
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile != null) {
            create("release") {
                val storeFilePath = keystoreProperties.getProperty("storeFile")
                if (!storeFilePath.isNullOrBlank()) {
                    val configured = file(storeFilePath)
                    val resolved = listOf(
                        configured,
                        keystorePropertiesFile.parentFile.resolve(storeFilePath),
                        keystorePropertiesFile.parentFile.resolve(file(storeFilePath).name),
                    ).firstOrNull { it.exists() } ?: configured
                    storeFile = resolved
                }
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release")
                ?: signingConfigs.getByName("debug")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}


dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.security:security-crypto:1.1.0-alpha06")
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.json:json:20240303")

    // home_widget 0.9.0 传递依赖了 glance-appwidget 1.3.0-alpha01（要求 AGP 9.1.0 / compileSdk 37）。
    // 在升级 AGP 之前，强制锁定到兼容当前工具链的稳定版本。
    constraints {
        implementation("androidx.glance:glance-appwidget") {
            version { strictly("1.1.1") }
            because("glance-appwidget 1.3.0-alpha01 requires AGP 9.1.0 and compileSdk 37; pin to 1.1.1 which is compatible with AGP 8.x / compileSdk 36")
        }
        implementation("androidx.glance:glance") {
            version { strictly("1.1.1") }
            because("keep glance family versions in sync")
        }
        implementation("androidx.glance:glance-material3") {
            version { strictly("1.1.1") }
            because("keep glance family versions in sync")
        }
    }
}
