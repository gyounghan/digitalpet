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

    // home_widget 0.9.0이 JVM 11로 빌드된 의존성을 쓰는데 자체 타깃이 1.8이라
    // "Cannot inline bytecode built with JVM target 11" 오류가 나던 문제 해결.
    // 다른 플러그인의 compileOptions는 AGP가 finalize 전 읽기를 금지하므로
    // (targetCompatibility is not yet finalized) 문제가 된 home_widget에만
    // 읽기 없이 11을 직접 지정한다.
    if (project.name == "home_widget") {
        val forceJvm11: Project.() -> Unit = {
            extensions.findByType(com.android.build.gradle.BaseExtension::class.java)
                ?.compileOptions
                ?.apply {
                    sourceCompatibility = JavaVersion.VERSION_11
                    targetCompatibility = JavaVersion.VERSION_11
                }
            tasks.withType(org.jetbrains.kotlin.gradle.tasks.KotlinCompile::class.java)
                .configureEach {
                    kotlinOptions {
                        jvmTarget = "11"
                    }
                }
        }
        // evaluationDependsOn(":app") 여파로 이미 평가된 프로젝트에는
        // afterEvaluate 등록이 불가하므로 즉시 적용한다.
        if (project.state.executed) {
            project.forceJvm11()
        } else {
            afterEvaluate { forceJvm11() }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
