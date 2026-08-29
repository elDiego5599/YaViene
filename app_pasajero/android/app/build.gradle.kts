import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
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
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        // OJO: cambiarlo exige actualizar google-services.json (package_name) y
        // registrar el nuevo paquete + SHA-1 en la consola de Firebase, o la
        // autenticación deja de funcionar.
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
    // tenga registrados el proyecto. Hoy solo está el de debug
    // (88:9F:80:E4:…:85:E2), así que un release firmado con upload-keystore.jks
    // (14:78:C5:8B:…:C6:E0) hace fallar el ingreso con Google — ApiException 10,
    // que la app enseña como un error genérico.
    //
    // Lo definitivo es registrar el SHA-1 de release en la consola de Firebase.
    // Mientras tanto, esta variable construye el release con la llave de debug
    // para poder probar el ingreso con Google en una APK de release:
    //
    //   YA_VIENE_FIRMA_DEBUG=true flutter build apk --release
    //
    // Es variable de entorno y no propiedad de Gradle porque `flutter build`
    // no reenvía los `-P` de la línea de órdenes al build de Android.
    // Una APK así NO es publicable: sirve para probar, no para entregar.
    val firmarConLlaveDeDebug = System.getenv("YA_VIENE_FIRMA_DEBUG") == "true"

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists() && !firmarConLlaveDeDebug) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
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
