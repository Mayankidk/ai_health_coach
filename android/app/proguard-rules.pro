# ProGuard Rules for Supabase and dependencies
-keepattributes Signature,Annotation,EnclosingMethod,InnerClasses

# Keep Supabase and related models
-keep class com.supabase_flutter.** { *; }
-keep class io.github.jan.supabase.** { *; }
-keep class io.ktor.** { *; }

# Keep your own models that are used with Supabase/Hive
-keep class com.aihealthcoach.ai_health_coach_app.core.** { *; }
-keep class com.aihealthcoach.ai_health_coach_app.features.plans.** { *; }

# Hive specific
-keep class io.hive_flutter.** { *; }
-keep class io.hive.** { *; }
