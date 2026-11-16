plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val unsignedReleaseBuild = providers.environmentVariable("OH_MY_ESOK_UNSIGNED_BUILD").orNull == "true"

val requireUnsignedRelease = tasks.register("requireUnsignedRelease") {
    doLast {
        check(unsignedReleaseBuild) {
            "Use scripts/build-android.ps1 for a signed candidate, or explicitly opt in to " +
                "unsigned output with OH_MY_ESOK_UNSIGNED_BUILD=true and no signing credentials."
        }
    }
}

tasks.configureEach {
    if (name == "preReleaseBuild") dependsOn(requireUnsignedRelease)
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

    buildTypes {
        release {
            // Production signing is done by apksigner after Flutter/Gradle exits.
            signingConfig = null
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
