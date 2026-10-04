package com.bssparking.timemark.bssparking_timemark

import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.bssparking.timemark/direct_share"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "shareDirect") {
                val target = call.argument<String>("target") // "whatsapp" atau "telegram"
                val text = call.argument<String>("text") ?: ""
                val imagePath = call.argument<String>("imagePath")
                val imagePaths = call.argument<List<String>>("imagePaths")

                try {
                    val pm = packageManager
                    val packageName = when (target) {
                        "whatsapp" -> {
                            val isWaInstalled = try { pm.getPackageInfo("com.whatsapp", 0); true } catch (e: Exception) { false }
                            val isW4bInstalled = try { pm.getPackageInfo("com.whatsapp.w4b", 0); true } catch (e: Exception) { false }
                            if (isWaInstalled) "com.whatsapp" else if (isW4bInstalled) "com.whatsapp.w4b" else null
                        }
                        "telegram" -> {
                            val tgPackages = listOf(
                                "org.telegram.messenger",
                                "org.thunderdog.challegram",
                                "org.telegram.plus",
                                "nekox.messenger",
                                "tw.nekomimi.nekogram",
                                "org.telegram.messenger.web"
                            )
                            tgPackages.firstOrNull { pkg ->
                                try { pm.getPackageInfo(pkg, 0); true } catch (e: Exception) { false }
                            }
                        }
                        else -> null
                    }

                    if (packageName != null) {
                        val intent = if (imagePaths != null && imagePaths.size > 1) {
                            Intent(Intent.ACTION_SEND_MULTIPLE).apply {
                                type = "image/*"
                                if (text.isNotEmpty()) {
                                    putExtra(Intent.EXTRA_TEXT, text)
                                }
                                val uriList = ArrayList<Uri>()
                                for (p in imagePaths) {
                                    val f = File(p)
                                    if (f.exists()) {
                                        val u = FileProvider.getUriForFile(
                                            this@MainActivity,
                                            "${applicationContext.packageName}.direct_share_provider",
                                            f
                                        )
                                        uriList.add(u)
                                    }
                                }
                                putParcelableArrayListExtra(Intent.EXTRA_STREAM, uriList)
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            }
                        } else {
                            val singlePath = if (imagePaths != null && imagePaths.isNotEmpty()) imagePaths[0] else imagePath
                            val singleFile = if (singlePath != null) File(singlePath) else null
                            if (singleFile != null && singleFile.exists()) {
                                Intent(Intent.ACTION_SEND).apply {
                                    type = "image/*"
                                    if (text.isNotEmpty()) putExtra(Intent.EXTRA_TEXT, text)
                                    val u = FileProvider.getUriForFile(
                                        this@MainActivity,
                                        "${applicationContext.packageName}.direct_share_provider",
                                        singleFile
                                    )
                                    putExtra(Intent.EXTRA_STREAM, u)
                                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                }
                            } else {
                                Intent(Intent.ACTION_SEND).apply {
                                    type = "text/plain"
                                    putExtra(Intent.EXTRA_TEXT, text)
                                }
                            }
                        }

                        intent.setPackage(packageName)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } else {
                        // Package target belum terinstall di HP
                        result.success(false)
                    }
                } catch (e: Exception) {
                    result.error("SHARE_ERROR", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
