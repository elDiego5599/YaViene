import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// Firma de release con llave propia. La contraseña vive en android/key.properties
// (gitignored; ver key.properties.example) y el keystore en android/app/upload-keystore.jks.
// Sin key.properties el release cae a llaves de debug para no romper builds locales,
// pero NO es publicable así.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.example.ya_viene_pasajero"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // Paquete provisional: Play no acepta `com.example.*` e iOS ya usa
        // `com.yaviene.yaviene`. Cambiarlo exige registrar el paquete y su
        // SHA-1 en Firebase (dueño) y deja sin actualización la APK instalada;
        // va en la T5.7 del plan de remediación.
        applicationId = "com.example.ya_viene_pasajero"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = keystoreProperties["storeFile"]?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    // Firebase valida el SHA-1 del certificado que firma el APK contra los que
    // tenga registrados el proyecto. Están registrados los dos: el de debug
    // (88:9F:80:E4:…:85:E2) y el de release (14:78:C5:8B:…:C6:E0), así que el
    // ingreso con Google sirve en las dos variantes. Si alguna vez se cambia
    // upload-keystore.jks, hay que registrar el SHA-1 nuevo en la consola de
    // Firebase o el ingreso con Google deja de funcionar en release.
    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            // R8: ofusca y poda el código y recorta los recursos sin uso. El
            // plugin de Flutter ya lo prende en release (y le suma sus reglas
            // de ProGuard); se escribe aquí para que quede a la vista y para
            // que plataforma_config_test.dart lo sostenga si algún día el
            // plugin cambia de parecer. `flutter build --no-shrink` no tiene
            // efecto desde hace años; solo los componentes diferidos (que no
            // usamos) lo apagan.
            isMinifyEnabled = true
            isShrinkResources = true
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
