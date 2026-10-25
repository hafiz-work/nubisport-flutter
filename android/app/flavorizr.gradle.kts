import com.android.build.gradle.AppExtension

val android = project.extensions.getByType(AppExtension::class.java)

android.apply {
    flavorDimensions("flavor-type")

    productFlavors {
        create("dev") {
            dimension = "flavor-type"
            applicationId = "com.hafizbahtiar.nubisport.dev"
            resValue(type = "string", name = "app_name", value = "Nubi Sport Dev")
        }
        create("prod") {
            dimension = "flavor-type"
            applicationId = "com.hafizbahtiar.nubisport"
            resValue(type = "string", name = "app_name", value = "Nubi Sport")
        }
    }

    buildFeatures.resValues = true
}