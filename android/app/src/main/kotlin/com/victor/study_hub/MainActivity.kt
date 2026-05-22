package com.victor.study_hub

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            UPDATE_INSTALLER_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "canRequestPackageInstalls" -> result.success(canRequestPackageInstalls())
                "openUnknownSourcesSettings" -> {
                    openUnknownSourcesSettings(result)
                }
                "installApk" -> {
                    val apkPath = call.argument<String>("apkPath")
                    installApk(apkPath, result)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun canRequestPackageInstalls(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            packageManager.canRequestPackageInstalls()
        } else {
            true
        }
    }

    private fun openUnknownSourcesSettings(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            result.success(null)
            return
        }

        try {
            val intent = Intent(
                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                Uri.parse("package:$packageName")
            ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            result.success(null)
        } catch (error: ActivityNotFoundException) {
            result.error("settings_unavailable", "Installer permission settings unavailable.", null)
        }
    }

    private fun installApk(apkPath: String?, result: MethodChannel.Result) {
        if (apkPath.isNullOrBlank()) {
            result.error("missing_apk_path", "Missing APK path.", null)
            return
        }

        val apkFile = File(apkPath)
        if (!apkFile.exists()) {
            result.error("apk_not_found", "APK file not found.", null)
            return
        }

        try {
            val apkUri = FileProvider.getUriForFile(
                this,
                "$packageName.update_file_provider",
                apkFile
            )
            val intent = Intent(Intent.ACTION_VIEW)
                .setDataAndType(apkUri, APK_MIME_TYPE)
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            result.success(null)
        } catch (error: Exception) {
            result.error("installer_unavailable", error.message, null)
        }
    }

    companion object {
        private const val UPDATE_INSTALLER_CHANNEL = "study_hub/update_installer"
        private const val APK_MIME_TYPE = "application/vnd.android.package-archive"
    }
}
