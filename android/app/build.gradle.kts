plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Cargar propiedades del keystore
import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

android {
    namespace = "com.jakao.gestorpocket"
    compileSdk = 35 // Mantenemos compileSdk en 35
    ndkVersion = "27.0.12077973"

    // Configuración para el NDK
    // No es necesario especificar ABI, ya que Flutter lo maneja automáticamente

    // Configuración para SQLite
    packagingOptions {
        jniLibs {
            useLegacyPackaging = true
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.devsolutions.gestor_pocket"  // Asegúrate de que este ID sea único
        minSdk = 21  // Mínimo requerido por Flutter
        targetSdk = 34  // Usamos 34 que es la última versión estable
        versionCode = 3  // Actualizado para la nueva versión
        versionName = "1.0.1" // Actualizado para la nueva versión
        multiDexEnabled = true
        
        // Configuración para in-app purchases
        manifestPlaceholders += mapOf(
            "billingClientVersion" to "6.1.0"  // Versión de la biblioteca de facturación de Google Play
        )
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}
