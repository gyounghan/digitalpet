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
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
