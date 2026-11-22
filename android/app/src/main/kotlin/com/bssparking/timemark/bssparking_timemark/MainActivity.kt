package com.bssparking.timemark.bssparking_timemark

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.zip.ZipFile

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.bssparking.timemark/direct_share"
    private val UPDATER_CHANNEL = "com.bssparking.timemark/app_updater"
    private val PICK_APK_REQUEST_CODE = 4154

    private var pendingApkPickResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UPDATER_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getSupportedAbis" -> {
                    result.success(Build.SUPPORTED_ABIS.toList())
                }
                "canInstallPackages" -> {
                    val allowed = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        packageManager.canRequestPackageInstalls()
                    } else {
                        true
                    }
                    result.success(allowed)
                }
                "openInstallPermissionSettings" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            val intent = Intent(
                                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                Uri.parse("package:${applicationContext.packageName}")
                            ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    } catch (e: Exception) {
                        result.error("SETTINGS_ERROR", e.message, null)
                    }
                }
                "installApk" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrBlank()) {
                        result.error("INVALID_ARG", "Missing APK path", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val file = File(path)
                        val updatesDir = File(cacheDir, "updates").canonicalFile
                        val canonicalFile = file.canonicalFile
                        if (!canonicalFile.path.startsWith(updatesDir.path + File.separator)) {
                            result.error("INVALID_PATH", "APK path must reside in updates cache", null)
                            return@setMethodCallHandler
                        }
                        if (!canonicalFile.exists() || !canonicalFile.isFile || canonicalFile.length() <= 0L) {
                            result.error("MISSING_FILE", "APK file not found", null)
                            return@setMethodCallHandler
                        }
                        val providerAuthority = "${applicationContext.packageName}.direct_share_provider"
                        val uri = FileProvider.getUriForFile(this@MainActivity, providerAuthority, canonicalFile)
                        val intent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(uri, "application/vnd.android.package-archive")
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        android.util.Log.e("MainActivity", "Error in installApk", e)
                        result.error("INSTALL_ERROR", e.message, null)
                    }
                }
                "readApkInfo" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrBlank()) {
                        result.error("INVALID_ARG", "Missing APK path", null)
                        return@setMethodCallHandler
                    }
                    Thread {
                        try {
                            val file = File(path)
                            if (!file.exists() || !file.isFile || file.length() <= 0L) {
                                runOnUiThread { result.success(null) }
                                return@Thread
                            }
                            val pm = packageManager
                            val pkgInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                                pm.getPackageArchiveInfo(path, PackageManager.PackageInfoFlags.of(0))
                            } else {
                                @Suppress("DEPRECATION")
                                pm.getPackageArchiveInfo(path, 0)
                            }
                            if (pkgInfo == null) {
                                runOnUiThread { result.success(null) }
                                return@Thread
                            }
                            val versionCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                                pkgInfo.longVersionCode
                            } else {
                                @Suppress("DEPRECATION")
                                pkgInfo.versionCode.toLong()
                            }
                            val abis = mutableSetOf<String>()
                            ZipFile(file).use { zip ->
                                val entries = zip.entries()
                                while (entries.hasMoreElements()) {
                                    val entryName = entries.nextElement().name
                                    when {
                                        entryName.startsWith("lib/arm64-v8a/") -> abis.add("arm64-v8a")
                                        entryName.startsWith("lib/armeabi-v7a/") -> abis.add("armeabi-v7a")
                                        entryName.startsWith("lib/x86_64/") -> abis.add("x86_64")
                                    }
                                }
                            }
                            val payload = mapOf(
                                "packageName" to (pkgInfo.packageName ?: ""),
                                "versionName" to (pkgInfo.versionName ?: ""),
                                "versionCode" to versionCode,
                                "abis" to abis.toList()
                            )
                            runOnUiThread { result.success(payload) }
                        } catch (e: Exception) {
                            android.util.Log.e("MainActivity", "Error in readApkInfo", e)
                            runOnUiThread { result.error("APK_PARSE_ERROR", e.message, null) }
                        }
                    }.start()
                }
                "pickApkFile" -> {
                    if (pendingApkPickResult != null) {
                        result.error("PICK_IN_PROGRESS", "APK picker already active", null)
                        return@setMethodCallHandler
                    }
                    try {
                        pendingApkPickResult = result
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "*/*"
                        }
                        @Suppress("DEPRECATION")
                        startActivityForResult(intent, PICK_APK_REQUEST_CODE)
                    } catch (e: Exception) {
                        pendingApkPickResult = null
                        result.error("PICK_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

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
                            // 0. Foto + video campur: satu album, mime */* (kalau tidak, video terbuang)
                            imageFiles.isNotEmpty() && videoFiles.isNotEmpty() -> {
                                val uriList = ArrayList<Uri>()
                                for (f in validFiles) {
                                    val u = FileProvider.getUriForFile(this@MainActivity, providerAuthority, f)
                                    uriList.add(u)
                                    grantUriToTargets(u)
                                }
                                Intent(Intent.ACTION_SEND_MULTIPLE).apply {
                                    type = "*/*"
                                    if (text.isNotEmpty()) putExtra(Intent.EXTRA_TEXT, text)
                                    putParcelableArrayListExtra(Intent.EXTRA_STREAM, uriList)
                                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                }
                            }

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

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != PICK_APK_REQUEST_CODE) return

        val pending = pendingApkPickResult ?: return
        pendingApkPickResult = null

        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            pending.success(null)
            return
        }

        val uri = data.data!!
        Thread {
            try {
                val updatesDir = File(cacheDir, "updates")
                if (!updatesDir.exists()) updatesDir.mkdirs()
                updatesDir.listFiles()?.forEach { f ->
                    if (f.name.startsWith("picked-") && f.name.endsWith(".apk")) {
                        f.delete()
                    }
                }

                var displayName = "release.apk"
                contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        val idx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                        if (idx >= 0) {
                            val n = cursor.getString(idx)
                            if (!n.isNullOrBlank()) displayName = n
                        }
                    }
                }

                val dest = File(updatesDir, "picked-${System.currentTimeMillis()}.apk")
                contentResolver.openInputStream(uri)?.use { input ->
                    dest.outputStream().use { output ->
                        input.copyTo(output, 64 * 1024)
                    }
                } ?: throw IllegalStateException("Cannot open selected file")

                val payload = mapOf(
                    "path" to dest.absolutePath,
                    "name" to displayName,
                    "sizeBytes" to dest.length()
                )
                runOnUiThread { pending.success(payload) }
            } catch (e: Exception) {
                android.util.Log.e("MainActivity", "Error copying picked APK", e)
                runOnUiThread { pending.error("PICK_COPY_ERROR", e.message, null) }
            }
        }.start()
    }
}
