import com.android.build.api.dsl.LibraryExtension
import org.jetbrains.kotlin.gradle.dsl.KotlinAndroidProjectExtension
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

group = "ai.nddev.nds.accounts"
version = "0.0.1-alpha.9"

plugins {
    id("com.android.library")
}

// All consumers resolve the exact Cargo-selected Kotlin verifier from the same
// immutable upstream source. Other groups cannot be served by this repository.
rootProject.allprojects {
    repositories {
        maven {
            url = uri("https://raw.githubusercontent.com/rustls/rustls-platform-verifier/1aa691352a5e0c215210dfc9a3c2f2078639dc91/android-release-support/maven/")
            content { includeModule("org.rustls", "rustls-platform-verifier") }
        }
    }
}

val cargoLock = file("../rust/Cargo.lock").readText()
val verifierVersion = Regex("name = \"rustls-platform-verifier-android\"\\s+version = \"([^\"]+)\"")
    .find(cargoLock)?.groupValues?.get(1) ?: error("Pinned Android TLS verifier missing from Cargo.lock")

dependencies { implementation("org.rustls:rustls-platform-verifier:$verifierVersion") }

extensions.configure<LibraryExtension> {
    namespace = "ai.nddev.nds.accounts"
    compileSdk = 36
    // The locked native Rust toolchain links against Android API 35.
    defaultConfig { minSdk = 35; consumerProguardFiles("consumer-rules.pro") }
    compileOptions { sourceCompatibility = JavaVersion.VERSION_17; targetCompatibility = JavaVersion.VERSION_17 }
}

extensions.configure<KotlinAndroidProjectExtension> {
    compilerOptions { jvmTarget.set(JvmTarget.JVM_17) }
}
