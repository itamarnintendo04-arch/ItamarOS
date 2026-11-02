plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.plugin.compose")
}

android {
    namespace = "org.itamaros.nativeapp"
    compileSdk = 36

    defaultConfig {
        applicationId = "org.itamaros.cloudclimb"
        minSdk = 26
        targetSdk = 36
        versionCode = 1
        versionName = "0.1.0-preview"
        buildConfigField("String", "ITAMAR_SUPABASE_URL", "\"${providers.gradleProperty("ITAMAR_SUPABASE_URL").orElse("https://slqjkysinhfkqjoigfuz.supabase.co").get()}\"")
        buildConfigField("String", "ITAMAR_SUPABASE_PUBLISHABLE_KEY", "\"${providers.gradleProperty("ITAMAR_SUPABASE_PUBLISHABLE_KEY").orElse("sb_publishable__WVo13dRVkDYChuGxHxk9A_CDoVR9ts").get()}\"")
        buildConfigField("String", "ITAMAR_FIREBASE_APP_ID", "\"${providers.gradleProperty("ITAMAR_FIREBASE_APP_ID").orElse("").get()}\"")
        buildConfigField("String", "ITAMAR_FIREBASE_API_KEY", "\"${providers.gradleProperty("ITAMAR_FIREBASE_API_KEY").orElse("").get()}\"")
        buildConfigField("String", "ITAMAR_FIREBASE_SENDER_ID", "\"${providers.gradleProperty("ITAMAR_FIREBASE_SENDER_ID").orElse("").get()}\"")
        buildConfigField("String", "ITAMAR_FIREBASE_PROJECT_ID", "\"${providers.gradleProperty("ITAMAR_FIREBASE_PROJECT_ID").orElse("").get()}\"")
    }

    sourceSets {
        getByName("main") {
            kotlin.directories += "../app/src/main/java"
            res.srcDir("../app/src/main/res")
        }
    }
    buildFeatures {
        compose = true
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }
}

dependencies {
    val composeBom = platform("androidx.compose:compose-bom:2026.05.00")
    implementation(composeBom)
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.foundation:foundation")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.activity:activity-compose:1.12.1")
    implementation("androidx.core:core-ktx:1.17.0")
    implementation("androidx.work:work-runtime-ktx:2.12.0")
    implementation("com.google.zxing:core:3.5.4")
    // Shared AndroidConnect.kt also compiles for the standalone game.
    implementation("com.google.android.gms:play-services-auth:22.0.0")
    implementation(platform("com.google.firebase:firebase-bom:35.1.0"))
    implementation("com.google.firebase:firebase-messaging")
    debugImplementation("androidx.compose.ui:ui-tooling")
}

