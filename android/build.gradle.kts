allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")

    // 모든 서브프로젝트(플러그인)의 minSdk를 앱과 동일하게 강제 설정
    // home_widget, pedometer, flutter_local_notifications 등의
    // androidTest minSdkVersion 16 충돌 방지
    project.plugins.whenPluginAdded {
        if (this is com.android.build.gradle.LibraryPlugin) {
            project.extensions.configure<com.android.build.gradle.LibraryExtension> {
                if (defaultConfig.minSdk == null || defaultConfig.minSdk!! < 26) {
                    defaultConfig.minSdk = 26
                }
            }
        }
    }

    // 모든 모듈의 Java/Kotlin 컴파일 타깃을 JVM 17로 통일.
    // - home_widget 0.9.0: 기본 1.8 타깃으로 JVM 11 바이트코드 인라인 실패
    // - device_info_plus: Java 17 ↔ Kotlin 타깃 불일치
    // 플러그인마다 제각각인 타깃을 최고치(17)로 맞춰 둘 다 해결한다.
    val forceJvm17: (Project) -> Unit = { p ->
        p.extensions.findByType(com.android.build.gradle.BaseExtension::class.java)
            ?.compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }
    }
    // 이미 평가 완료된 프로젝트(:app)는 compileOptions가 finalize되어 수정 불가.
    // :app은 자체 build.gradle.kts에서 직접 17로 설정하므로 건너뛴다.
    if (!project.state.executed) {
        project.afterEvaluate { forceJvm17(this) }
    }
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
