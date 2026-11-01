import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
}

android {
    namespace = "top.talyra42.keycase"
    compileSdk {
        version = release(37)
    }

    defaultConfig {
        applicationId = "top.talyra42.keycase"
        minSdk = 26
        targetSdk = 37
        versionCode = 3
        versionName = "0.1.2"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    signingConfigs {
        create("release") {
            val signingProperties = Properties()
            val propertiesFile = rootProject.file("signing/keystore.properties")
            if (propertiesFile.isFile) {
                propertiesFile.inputStream().use { signingProperties.load(it) }
            }
            val configuredStore: String? = signingProperties.getProperty("storeFile")
            val storePath = System.getenv("KEYCASE_KEYSTORE_PATH")
                ?: configuredStore?.let { rootProject.file(it).absolutePath }
                ?: rootProject.file("signing/keycase-release.jks").absolutePath
            val storePassword = System.getenv("KEYCASE_STORE_PASSWORD")
                ?: signingProperties.getProperty("storePassword")
            val keyAlias = System.getenv("KEYCASE_KEY_ALIAS")
                ?: signingProperties.getProperty("keyAlias")
            val keyPassword = System.getenv("KEYCASE_KEY_PASSWORD")
                ?: signingProperties.getProperty("keyPassword")
            if (file(storePath).isFile && !storePassword.isNullOrBlank() &&
                !keyAlias.isNullOrBlank() && !keyPassword.isNullOrBlank()
            ) {
                storeFile = file(storePath)
                this.storePassword = storePassword
                this.keyAlias = keyAlias
                this.keyPassword = keyPassword
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release")
            optimization {
                enable = true
            }
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            isShrinkResources = true
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    buildFeatures {
        compose = true
    }
}

dependencies {
    implementation(project(":core"))
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.fragment.ktx)
    implementation(libs.androidx.biometric)
    implementation(libs.androidx.compose.material3)
    implementation(libs.androidx.compose.material.icons.extended)
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.ui.graphics)
    implementation(libs.androidx.compose.ui.tooling.preview)
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.lifecycle.viewmodel.ktx)
    implementation(libs.androidx.lifecycle.process)
    implementation(libs.zxing.android.embedded)
    implementation(libs.androidsvg)
    implementation(libs.androidx.documentfile)
    testImplementation(libs.junit)
    androidTestImplementation(platform(libs.androidx.compose.bom))
    androidTestImplementation(libs.androidx.compose.ui.test.junit4)
    androidTestImplementation(libs.androidx.espresso.core)
    androidTestImplementation(libs.androidx.junit)
    debugImplementation(libs.androidx.compose.ui.test.manifest)
    debugImplementation(libs.androidx.compose.ui.tooling)
}