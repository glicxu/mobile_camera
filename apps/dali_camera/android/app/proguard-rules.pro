# Room loads WorkManager's generated database implementation by name at startup.
-keep class androidx.work.impl.WorkDatabase_Impl { *; }

# ML Kit discovers these registrars by class name from AndroidManifest.xml.
-keep class * implements com.google.firebase.components.ComponentRegistrar { *; }
