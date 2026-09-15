plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.kapt")
    id("dev.flutter.flutter-gradle-plugin")
}


android {

    namespace = "com.example.datashield_fyp"

    compileSdk = flutter.compileSdkVersion

    ndkVersion = flutter.ndkVersion



    compileOptions {

        sourceCompatibility =
            JavaVersion.VERSION_11

        targetCompatibility =
            JavaVersion.VERSION_11

    }



    kotlinOptions {

        jvmTarget =
            JavaVersion.VERSION_11.toString()

    }



    defaultConfig {

        applicationId =
            "com.example.datashield_fyp"


        minSdk =
            flutter.minSdkVersion


        targetSdk =
            flutter.targetSdkVersion


        versionCode =
            flutter.versionCode


        versionName =
            flutter.versionName

    }



    buildTypes {

        release {

            signingConfig =
                signingConfigs.getByName("debug")

        }

    }

}



flutter {

    source = "../.."

}



dependencies {


    // DocumentFile API (folder picker)
    implementation(
        "androidx.documentfile:documentfile:1.0.1"
    )


    // Android core extensions
    implementation(
        "androidx.core:core-ktx:1.13.1"
    )



    // Room Database
    implementation(
        "androidx.room:room-runtime:2.7.0"
    )


    implementation(
        "androidx.room:room-ktx:2.7.0"
    )


    kapt(
        "androidx.room:room-compiler:2.7.0"
    )

    implementation(
    "org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.0"
    )

    implementation(
    "androidx.media3:media3-exoplayer:1.9.2"
    )

    implementation(
    "androidx.media3:media3-ui:1.9.2"
    )

}