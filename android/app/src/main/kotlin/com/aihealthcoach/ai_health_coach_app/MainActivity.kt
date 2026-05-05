package com.aihealthcoach.ai_health_coach_app

import android.content.Intent
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "neuralis/health_connect")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openHealthConnect" -> result.success(openHealthConnect())
                    "openGoogleFit" -> result.success(openGoogleFit())
                    else -> result.notImplemented()
                }
            }
    }

    private fun openHealthConnect(): Boolean {
        val intents = mutableListOf<Intent>()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            intents.add(
                Intent("android.health.connect.action.MANAGE_HEALTH_PERMISSIONS")
                    .putExtra(Intent.EXTRA_PACKAGE_NAME, packageName)
            )
            intents.add(Intent("android.health.connect.action.HEALTH_HOME_SETTINGS"))
        }

        intents.add(Intent("androidx.health.ACTION_HEALTH_CONNECT_SETTINGS"))
        packageManager.getLaunchIntentForPackage("com.google.android.apps.healthdata")
            ?.let { intents.add(it) }

        for (intent in intents) {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            if (intent.resolveActivity(packageManager) != null) {
                startActivity(intent)
                return true
            }
        }

        return false
    }

    private fun openGoogleFit(): Boolean {
        val fitIntents = listOf(
            Intent(Intent.ACTION_MAIN)
                .setClassName(
                    "com.google.android.apps.fitness",
                    "com.google.android.apps.fitness.welcome.WelcomeActivity"
                ),
            Intent(Intent.ACTION_MAIN)
                .setClassName(
                    "com.google.android.apps.fitness",
                    "com.google.android.apps.fitness.shared.FitActivity"
                ),
            packageManager.getLaunchIntentForPackage("com.google.android.apps.fitness"),
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                .setData(android.net.Uri.parse("package:com.google.android.apps.fitness"))
        ).filterNotNull()

        for (intent in fitIntents) {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            if (intent.resolveActivity(packageManager) != null) {
                startActivity(intent)
                return true
            }
        }

        val storeIntent = Intent(
            Intent.ACTION_VIEW,
            android.net.Uri.parse("market://details?id=com.google.android.apps.fitness")
        ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

        if (storeIntent.resolveActivity(packageManager) != null) {
            startActivity(storeIntent)
            return true
        }

        val webIntent = Intent(
            Intent.ACTION_VIEW,
            android.net.Uri.parse("https://play.google.com/store/apps/details?id=com.google.android.apps.fitness")
        ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

        if (webIntent.resolveActivity(packageManager) != null) {
            startActivity(webIntent)
            return true
        }

        return false
    }
}
