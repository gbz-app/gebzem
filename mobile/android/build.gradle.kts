allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
// ⚠️⚠️⚠️ TURU 180z — EKLENTILERIN `compileSdk` DEGERI UYGULAMAYLA HIZALANIR.
//
// SORUN (OLCULDU, turu 87'nin BIREBIR TEKRARI): `file_picker` (compileSdk 34)
// ve `flutter_video_thumbnail_plus` (34) eklendiginde Gradle
// `:file_picker:checkDebugAarMetadata` ile PATLADI:
//	 "Dependency ':flutter_plugin_android_lifecycle' requires libraries and
//	  applications that depend on it to compile against version 36 or later
//	  ... :file_picker is currently compiled against android-34."
// Yani hata BIZIM kodumuzda degil, iki eklentinin eski `compileSdk`inda.
//
// ⚠️ `compileSdk` YUKSELTMEK GERIYE UYUMLUDUR: yalnizca hangi API'lerin
//	DERLENEBILECEGINI belirler; `minSdk`/`targetSdk`e DOKUNMAZ ve
//	calisma-zamani davranisini DEGISTIRMEZ.
// ⚠️ YAPMA: bunun yerine `file_picker`i eski surume dusurme — o zaman
//	`flutter_plugin_android_lifecycle` ile catisma SURER.
// ⚠️ Sabit 36: uygulamanin `flutter.compileSdkVersion` degeriyle hizali.
//	Flutter SDK bunu yukseltirse BU SAYI DA yukseltilmeli — aksi halde
//	ayni `checkAarMetadata` hatasi geri doner.
// ⚠️ Yeni bir eklenti eklerken Gradle bu blok sayesinde patlamaz; yine de
//	paketin `android/build.gradle` dosyasindaki `compileSdk`e BAK
//	(CLAUDE.md turu 87 kurali).
// ⚠️⚠️ `afterEvaluate` KULLANILAMAZ: yukaridaki `evaluationDependsOn(":app")`
//	bazi projeleri ZATEN degerlendirmis oluyor ve Gradle
//	*"Cannot run Project.afterEvaluate(Action) when the project is already
//	evaluated"* ile PATLIYOR (olculdu). `plugins.withId` zamanlamadan
//	BAGIMSIZ calisir: eklenti uygulandigi anda tetiklenir.
// ⚠️ YAPMA: burayi `afterEvaluate`e cevirme.
val kEklentiCompileSdk = 36

subprojects {
    plugins.withId("com.android.library") {
        extensions.configure<com.android.build.gradle.LibraryExtension> {
            // ⚠️ YALNIZ DUSUKSE yukseltilir: zaten 36+ olan bir eklentiyi
            //	GERI CEKMEK yeni bir uyumsuzluk uretirdi.
            if (compileSdk == null || compileSdk!! < kEklentiCompileSdk) {
                compileSdk = kEklentiCompileSdk
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
