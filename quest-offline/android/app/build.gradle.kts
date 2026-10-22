import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

val localProps = Properties().apply {
    val f = rootProject.file("local.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
val oculusAppId: String =
    (localProps.getProperty("oculus.app.id")
        ?: System.getenv("OCULUS_APP_ID")
        ?: project.findProperty("oculus.app.id") as String?
        ?: "0").trim()

android {
    namespace = "com.smallerbytes.defuseprotocol.offline"
    compileSdk = 34

    defaultConfig {
        // Must stay forever = Meta dashboard package for this Alpha / Store app.
        applicationId = "com.smallerbytes.defuseprotocol"
        minSdk = 34
        targetSdk = 34
        versionCode = 8
        versionName = "1.2.0"

        resValue("string", "oculus_app_id", oculusAppId)

        ndk {
            abiFilters += listOf("arm64-v8a")
        }
    }

    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }

    buildFeatures {
        prefab = true
    }

    signingConfigs {
        create("release") {
            val ks = file("../../../../defusalapplab/android.keystore")
            if (ks.exists()) {
                storeFile = ks
                storePassword = System.getenv("BUBBLEWRAP_KEYSTORE_PASSWORD") ?: ""
                keyAlias = "android"
                keyPassword = System.getenv("BUBBLEWRAP_KEY_PASSWORD")
                    ?: System.getenv("BUBBLEWRAP_KEYSTORE_PASSWORD")
                    ?: ""
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            val rel = signingConfigs.findByName("release")
            if (rel != null && rel.storeFile?.exists() == true && !rel.storePassword.isNullOrEmpty()) {
                signingConfig = rel
            }
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.appcompat:appcompat:1.7.0")
    implementation("org.nanohttpd:nanohttpd:2.3.1")
    // Follow the working offline WebXR Quest recipe (dashboard validation).
    implementation("com.meta.metavr:metavr-os-jsdk:207")
    implementation("org.khronos.openxr:openxr_loader_for_android:1.0.34")
}

// Prefab does not package libopenxr_loader.so into the APK by itself — copy it.
val copyOpenXrLoader by tasks.registering(Copy::class) {
    val config = configurations.detachedConfiguration(
        dependencies.create("org.khronos.openxr:openxr_loader_for_android:1.0.34")
    )
    config.isTransitive = false
    from({
        config.resolve().flatMap { aar ->
            zipTree(aar).matching {
                include("prefab/modules/openxr_loader/libs/android.arm64-v8a/libopenxr_loader.so")
            }.files
        }
    })
    into(layout.projectDirectory.dir("src/main/jniLibs/arm64-v8a"))
    eachFile {
        path = name // drop prefab/... nesting
    }
    includeEmptyDirs = false
    doFirst {
        println("Copying libopenxr_loader.so into jniLibs/arm64-v8a …")
    }
}

tasks.named("preBuild").configure { dependsOn(copyOpenXrLoader) }
