import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 发布签名材料按项目所有者要求入库在仓库根目录 signing/ 下。
// 属性文件缺失时 release 构建会直接失败，而不是静默用 debug 签名。
val repoRoot: File = project.rootProject.projectDir.parentFile
val keystoreProperties = Properties().apply {
    val file = File(repoRoot, "signing/keystore.properties")
    check(file.isFile) { "缺少签名配置: ${file.absolutePath}" }
    // 属性文件可能带 UTF-8 BOM；直接 load 会把 BOM 当成第一个键的一部分，
    // 导致 storeFile 读不到、签名配置静默为空。这里统一去 BOM 再解析。
    val text = file.readText(Charsets.UTF_8).removePrefix("\uFEFF")
    text.reader().use { load(it) }
}

android {
    namespace = "top.talyra42.keycase"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "top.talyra42.keycase"
        // 与旧 Kotlin 版一致：minSdk 26。local_auth 要求 >= 23，
        // Keystore 封装密钥与 mobile_scanner 在 26 上均可用。
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            val storePath = keystoreProperties.getProperty("storeFile")
            storeFile = File(repoRoot, storePath)
            storePassword = keystoreProperties.getProperty("storePassword")
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            // 与 verifin 一致的发布口径：R8 代码压缩 + 资源裁剪。
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
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
