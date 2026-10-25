import java.util.Properties

// Chiave di firma definitiva: sta fuori dal repository, in ~/.sfasciohub/ (release.jks + release.properties).
// Senza quei file si firma con la chiave di debug (va bene per provare, non per distribuire).
val releaseProps = Properties().apply {
    val f = file("${System.getProperty("user.home")}/.sfasciohub/release.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "it.sfasciohub.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true // richiesto da ota_update
    }

    defaultConfig {
        applicationId = "it.sfasciohub"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Tre app dallo stesso codice: chi cerca ricambi, chi gestisce il piazzale, chi gestisce la piattaforma.
    flavorDimensions += "app"
    productFlavors {
        create("explore") {
            dimension = "app"
            applicationIdSuffix = ".esplora"
        }
        create("gestione") {
            dimension = "app"
            applicationIdSuffix = ".gestione"
        }
        create("admin") {
            dimension = "app"
            applicationIdSuffix = ".admin"
        }
    }

    signingConfigs {
        if (releaseProps.containsKey("storeFile")) {
            create("release") {
                storeFile = file("${System.getProperty("user.home")}/.sfasciohub/${releaseProps["storeFile"]}")
                storePassword = releaseProps["storePassword"] as String
                keyAlias = releaseProps["keyAlias"] as String
                keyPassword = releaseProps["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
