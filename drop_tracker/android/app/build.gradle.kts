plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.eyedropshop.drop_tracker"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Required by flutter_local_notifications for scheduled reminders.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.eyedropshop.drop_tracker"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            // R8 (on by AGP's own default here, despite no explicit opt-in)
            // was stripping generic-type metadata that flutter_local_notifications
            // relies on for Gson's TypeToken-based reflection — confirmed via a
            // real crash: every zonedSchedule call threw
            // "java.lang.RuntimeException: Missing type parameter" from deep
            // inside FlutterLocalNotificationsPlugin.saveScheduledNotification
            // -> loadScheduledNotifications, hundreds of times per launch (one
            // per scheduled dose x2 retry attempts), tipping the app into a
            // crash loop on real devices. Proper fix is scoped keep rules, but
            // disabling minification is the certain fix until those are added
            // and verified against a real release build again — do not
            // silently re-enable this without retesting notification
            // scheduling end-to-end on a real device.
            isMinifyEnabled = false
            isShrinkResources = false
            // Wired up and ready (see the file's own header) for whenever
            // minification is turned back on — inert while isMinifyEnabled
            // is false above.
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
