plugins {
    id("com.android.application") version "8.7.3"
    id("org.jetbrains.kotlin.android") version "2.1.0"
    id("org.jetbrains.kotlin.plugin.compose") version "2.1.0"
}

android {
    namespace = "com.aboutpainttools.mangastudio"
    compileSdk = 35

    defaultConfig {
        applicationId = "org.aboutpainttools.mangastudio"
        minSdk = 29
        targetSdk = 35
        versionCode = 1
        versionName = "1.1.0-alpha"

        ndk {
            abiFilters += listOf("arm64-v8a", "x86_64")
        }
    }

    buildFeatures {
        compose = true
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
    implementation(platform("androidx.compose:compose-bom:2025.01.00"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.activity:activity-compose:1.9.3")
    // Foldable hinge & Tabletop posture detection
    implementation("androidx.window:window:1.3.0")
    // Low-latency stylus front-buffer rendering (S-Pen / M-Pencil / USI 2.0)
    implementation("androidx.graphics:graphics-core:1.0.2")
}
