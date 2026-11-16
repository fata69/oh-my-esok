import java.io.File

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseSigningEnvironment = listOf(
    "OH_MY_ESOK_KEYSTORE",
    "OH_MY_ESOK_STORE_PASSWORD",
    "OH_MY_ESOK_KEY_ALIAS",
    "OH_MY_ESOK_KEY_PASSWORD",
).associateWith { providers.environmentVariable(it).orNull?.takeIf(String::isNotBlank) }
val hasReleaseSigning = releaseSigningEnvironment.values.all { it != null }

val validateForkReleaseSigning = tasks.register("validateForkReleaseSigning") {
    doLast {
        val missing = releaseSigningEnvironment.filterValues { it == null }.keys
        check(missing.isEmpty()) {
            "Release signing requires these environment variables: ${missing.joinToString()}. " +
                "Oh My Esok release builds never use the debug key."
        }
        val keystore = File(releaseSigningEnvironment.getValue("OH_MY_ESOK_KEYSTORE")!!)
        check(keystore.isAbsolute && keystore.isFile) {
            "OH_MY_ESOK_KEYSTORE must point to an existing absolute keystore path."
        }
    }
}

tasks.configureEach {
    if (name == "preReleaseBuild") dependsOn(validateForkReleaseSigning)
}

android {
    namespace = "com.habib.jadwal"
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "io.github.fata69.ohmyesok"
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("forkRelease") {
            if (hasReleaseSigning) {
                storeFile = file(releaseSigningEnvironment.getValue("OH_MY_ESOK_KEYSTORE")!!)
                storePassword = releaseSigningEnvironment.getValue("OH_MY_ESOK_STORE_PASSWORD")
                keyAlias = releaseSigningEnvironment.getValue("OH_MY_ESOK_KEY_ALIAS")
                keyPassword = releaseSigningEnvironment.getValue("OH_MY_ESOK_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("forkRelease")
        }
    }

    lint {
        // Lint 31.x crashes on some dependency JavaDoc under JDK 17.
        checkReleaseBuilds = false
        abortOnError = false
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.core:core:1.19.0")
}
