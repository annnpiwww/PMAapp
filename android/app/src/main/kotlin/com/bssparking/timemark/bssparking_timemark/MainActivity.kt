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
                    val targetPackages = when (target) {
                        "whatsapp" -> {
                            val pkgs = mutableListOf<String>()
                            try { pm.getPackageInfo("com.whatsapp", 0); pkgs.add("com.whatsapp") } catch (_: Exception) {}
                            try { pm.getPackageInfo("com.whatsapp.w4b", 0); pkgs.add("com.whatsapp.w4b") } catch (_: Exception) {}
                            pkgs
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
                            val pkgs = mutableListOf<String>()
                            for (pkg in tgPackages) {
                                try { pm.getPackageInfo(pkg, 0); pkgs.add(pkg) } catch (_: Exception) {}
                            }
                            pkgs
                        }
                        else -> emptyList()
                    }

                    if (targetPackages.isNotEmpty()) {
                        val primaryPackage = targetPackages[0]

                        val allPaths = mutableListOf<String>()
                        if (imagePaths != null) {
                            for (p in imagePaths) {
                                if (!p.isNullOrBlank()) allPaths.add(p)
                            }
                        }
                        if (!imagePath.isNullOrBlank()) {
                            allPaths.add(imagePath)
                        }

                        val validFiles = allPaths
                            .map { File(it) }
                            .filter { it.exists() && it.isFile && it.length() > 0 }
                            .distinctBy { it.absolutePath }

                        val isVideoExt = { name: String ->
                            name.endsWith(".mp4") || name.endsWith(".mov") || name.endsWith(".mkv") || name.endsWith(".3gp")
                        }

                        val imageFiles = validFiles.filter { f -> !isVideoExt(f.name.lowercase()) }
                        val videoFiles = validFiles.filter { f -> isVideoExt(f.name.lowercase()) }

                        val providerAuthority = "${applicationContext.packageName}.direct_share_provider"

                        val grantUriToTargets = { uri: Uri ->
                            for (pkg in targetPackages) {
                                try {
                                    grantUriPermission(pkg, uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                } catch (_: Exception) {}
                            }
                        }

                        val intent: Intent = when {
                            // 1. Jika ada foto dokumentasi: kirim foto via image/*
                            imageFiles.isNotEmpty() -> {
                                if (imageFiles.size == 1) {
                                    val f = imageFiles[0]
                                    val uri = FileProvider.getUriForFile(this@MainActivity, providerAuthority, f)
                                    grantUriToTargets(uri)

                                    Intent(Intent.ACTION_SEND).apply {
                                        type = "image/*"
                                        if (text.isNotEmpty()) putExtra(Intent.EXTRA_TEXT, text)
                                        putExtra(Intent.EXTRA_STREAM, uri)
                                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                    }
                                } else {
                                    val uriList = ArrayList<Uri>()
                                    for (f in imageFiles) {
                                        val u = FileProvider.getUriForFile(this@MainActivity, providerAuthority, f)
                                        uriList.add(u)
                                        grantUriToTargets(u)
                                    }

                                    Intent(Intent.ACTION_SEND_MULTIPLE).apply {
                                        type = "image/*"
                                        if (text.isNotEmpty()) putExtra(Intent.EXTRA_TEXT, text)
                                        putParcelableArrayListExtra(Intent.EXTRA_STREAM, uriList)
                                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                    }
                                }
                            }

                            // 2. Jika ada video dokumentasi: kirim video via video/*
                            videoFiles.isNotEmpty() -> {
                                if (videoFiles.size == 1) {
                                    val f = videoFiles[0]
                                    val uri = FileProvider.getUriForFile(this@MainActivity, providerAuthority, f)
                                    grantUriToTargets(uri)

                                    Intent(Intent.ACTION_SEND).apply {
                                        type = if (f.name.lowercase().endsWith(".mp4")) "video/mp4" else "video/*"
                                        if (text.isNotEmpty()) putExtra(Intent.EXTRA_TEXT, text)
                                        putExtra(Intent.EXTRA_STREAM, uri)
                                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                    }
                                } else {
                                    val uriList = ArrayList<Uri>()
                                    for (f in videoFiles) {
                                        val u = FileProvider.getUriForFile(this@MainActivity, providerAuthority, f)
                                        uriList.add(u)
                                        grantUriToTargets(u)
                                    }

                                    Intent(Intent.ACTION_SEND_MULTIPLE).apply {
                                        type = "video/*"
                                        if (text.isNotEmpty()) putExtra(Intent.EXTRA_TEXT, text)
                                        putParcelableArrayListExtra(Intent.EXTRA_STREAM, uriList)
                                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                    }
                                }
                            }

                            // 3. Jika tidak ada media: kirim teks saja
                            else -> {
                                Intent(Intent.ACTION_SEND).apply {
                                    type = "text/plain"
                                    putExtra(Intent.EXTRA_TEXT, text)
                                }
                            }
                        }

                        intent.setPackage(primaryPackage)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } else {
                        // Package target belum terinstall di HP
                        result.success(false)
                    }
                } catch (e: Exception) {
                    android.util.Log.e("MainActivity", "Error in shareDirect", e)
                    result.error("SHARE_ERROR", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
