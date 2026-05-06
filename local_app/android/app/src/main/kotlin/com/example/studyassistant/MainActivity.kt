package com.example.studyassistant

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "study_assistant/external_links").setMethodCallHandler { call, result ->
            if (call.method != "openUrl") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val url = call.argument<String>("url")
            if (url.isNullOrBlank()) {
                result.success(false)
                return@setMethodCallHandler
            }

            runCatching {
                startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
            }.fold(
                onSuccess = { result.success(true) },
                onFailure = { result.success(false) },
            )
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "study_assistant/permissions").setMethodCallHandler { call, result ->
            val opened = when (call.method) {
                "openNotificationSettings" -> openNotificationSettings()
                "openExactAlarmSettings" -> openExactAlarmSettings()
                "openLockScreenNotificationSettings" -> openLockScreenNotificationSettings()
                "openBatterySettings" -> openBatterySettings()
                "openAppSettings" -> openAppSettings()
                else -> {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
            }
            result.success(opened)
        }
    }

    private fun openNotificationSettings(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            openIntent(
                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                    .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
            )
        } else {
            openAppSettings()
        }
    }

    private fun openExactAlarmSettings(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            openIntent(
                Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
                    .setData(Uri.parse("package:$packageName"))
            )
        } else {
            openAppSettings()
        }
    }

    private fun openLockScreenNotificationSettings(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            openIntent(
                Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS)
                    .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                    .putExtra(Settings.EXTRA_CHANNEL_ID, "assignment_deadlines")
            ) || openNotificationSettings()
        } else {
            openNotificationSettings()
        }
    }

    private fun openBatterySettings(): Boolean {
        return openIntent(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)) ||
            openAppSettings()
    }

    private fun openAppSettings(): Boolean {
        return openIntent(
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                .setData(Uri.parse("package:$packageName"))
        )
    }

    private fun openIntent(intent: Intent): Boolean {
        return runCatching {
            startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        }.isSuccess
    }
}
