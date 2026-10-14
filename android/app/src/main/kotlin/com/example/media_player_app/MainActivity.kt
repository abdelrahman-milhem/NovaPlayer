package com.example.media_player_app

import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity: com.ryanheise.audioservice.AudioServiceFragmentActivity() {
    private val CHANNEL = "com.zenora.app/apps"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInstalledApps" -> {
                    Thread {
                        try {
                            val appsList = ArrayList<Map<String, Any>>()
                            val pm = packageManager
                            val intent = Intent(Intent.ACTION_MAIN, null)
                            intent.addCategory(Intent.CATEGORY_LAUNCHER)

                            val resolveInfos = pm.queryIntentActivities(intent, 0)
                            val myPackageName = packageName

                            for (ri in resolveInfos) {
                                val pkgName = ri.activityInfo.packageName
                                if (pkgName == myPackageName) continue

                                val appName = ri.loadLabel(pm).toString()
                                val icon = ri.loadIcon(pm)
                                val iconBytes = drawableToByteArrayFast(icon)
                                val isSystem = (ri.activityInfo.applicationInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0

                                val appMap = HashMap<String, Any>()
                                appMap["packageName"] = pkgName
                                appMap["appName"] = appName
                                if (iconBytes != null) appMap["icon"] = iconBytes
                                appMap["isSystem"] = isSystem
                                appsList.add(appMap)
                            }

                            appsList.sortBy { (it["appName"] as String).lowercase() }

                            runOnUiThread {
                                result.success(appsList)
                            }
                        } catch (e: Exception) {
                            runOnUiThread {
                                result.error("ERROR", e.message, null)
                            }
                        }
                    }.start()
                }
                "launchApp" -> {
                    val pkg = call.argument<String>("packageName")
                    if (pkg != null) {
                        try {
                            val launchIntent = packageManager.getLaunchIntentForPackage(pkg)
                            if (launchIntent != null) {
                                startActivity(launchIntent)
                                result.success(true)
                            } else {
                                result.error("NOT_FOUND", "Could not find launch intent for $pkg", null)
                            }
                        } catch (e: Exception) {
                            result.error("ERROR", e.message, null)
                        }
                    } else {
                        result.error("INVALID_ARG", "Package name is required", null)
                    }
                }
                "isDeviceAdminActive" -> {
                    try {
                        val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
                        val comp = ComponentName(this, ZenoraDeviceAdminReceiver::class.java)
                        result.success(dpm.isAdminActive(comp))
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "isDeviceOwner" -> {
                    try {
                        val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
                        result.success(dpm.isDeviceOwnerApp(packageName))
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "requestDeviceAdmin" -> {
                    try {
                        val comp = ComponentName(this, ZenoraDeviceAdminReceiver::class.java)
                        val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN).apply {
                            putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, comp)
                            putExtra(DevicePolicyManager.EXTRA_ADD_EXPLANATION, "تأكيد صلاحية مسؤول الجهاز لإخفاء وتعطيل التطبيقات من نظام الهاتف")
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "hideApp" -> {
                    val pkg = call.argument<String>("packageName")
                    if (pkg != null) {
                        var hidden = false
                        val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
                        val comp = ComponentName(this, ZenoraDeviceAdminReceiver::class.java)
                        
                        if (dpm.isAdminActive(comp)) {
                            try {
                                hidden = dpm.setApplicationHidden(comp, pkg, true)
                            } catch (e: Exception) {}
                        }
                        if (!hidden) {
                            try {
                                packageManager.setApplicationEnabledSetting(
                                    pkg,
                                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED_USER,
                                    PackageManager.DONT_KILL_APP
                                )
                                hidden = true
                            } catch (e: Exception) {}
                        }
                        if (!hidden) {
                            try {
                                val p = Runtime.getRuntime().exec(arrayOf("su", "-c", "pm hide $pkg"))
                                p.waitFor()
                                if (p.exitValue() == 0) hidden = true
                            } catch (e: Exception) {}
                        }
                        result.success(hidden)
                    } else {
                        result.error("INVALID_ARG", "Package name is required", null)
                    }
                }
                "unhideApp" -> {
                    val pkg = call.argument<String>("packageName")
                    if (pkg != null) {
                        var unhidden = false
                        val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
                        val comp = ComponentName(this, ZenoraDeviceAdminReceiver::class.java)
                        
                        if (dpm.isAdminActive(comp)) {
                            try {
                                unhidden = dpm.setApplicationHidden(comp, pkg, false)
                            } catch (e: Exception) {}
                        }
                        if (!unhidden) {
                            try {
                                packageManager.setApplicationEnabledSetting(
                                    pkg,
                                    PackageManager.COMPONENT_ENABLED_STATE_DEFAULT,
                                    PackageManager.DONT_KILL_APP
                                )
                                unhidden = true
                            } catch (e: Exception) {}
                        }
                        if (!unhidden) {
                            try {
                                val p = Runtime.getRuntime().exec(arrayOf("su", "-c", "pm unhide $pkg"))
                                p.waitFor()
                                if (p.exitValue() == 0) unhidden = true
                            } catch (e: Exception) {}
                        }
                        result.success(unhidden)
                    } else {
                        result.error("INVALID_ARG", "Package name is required", null)
                    }
                }
                "changeAppIcon" -> {
                    val aliasName = call.argument<String>("aliasName")
                    if (aliasName != null) {
                        try {
                            val aliases = listOf(
                                "MainActivity",
                                "IconCalculator",
                                "IconWeather",
                                "IconNotes",
                                "IconGoldVault"
                            )
                            val pm = packageManager
                            for (alias in aliases) {
                                val componentName = android.content.ComponentName(packageName, "com.example.media_player_app.$alias")
                                val state = if (alias == aliasName) {
                                    PackageManager.COMPONENT_ENABLED_STATE_ENABLED
                                } else {
                                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED
                                }
                                try {
                                    pm.setComponentEnabledSetting(componentName, state, PackageManager.DONT_KILL_APP)
                                } catch (e: Exception) {}
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("ERROR", e.message, null)
                        }
                    } else {
                        result.error("INVALID_ARG", "Alias name required", null)
                    }
                }
                "captureIntruderSelfie" -> {
                    captureIntruderSelfie()
                    result.success(true)
                }
                "getIntruderPhotos" -> {
                    try {
                        val intruderDir = java.io.File(filesDir, "intruders")
                        val list = ArrayList<Map<String, Any>>()
                        if (intruderDir.exists()) {
                            val files = intruderDir.listFiles()
                            if (files != null) {
                                for (f in files) {
                                    if (f.isFile && f.name.startsWith("INTRUDER_")) {
                                        val map = HashMap<String, Any>()
                                        map["path"] = f.absolutePath
                                        map["name"] = f.name
                                        map["timestamp"] = f.lastModified()
                                        list.add(map)
                                    }
                                }
                            }
                        }
                        list.sortByDescending { (it["timestamp"] as Long) }
                        result.success(list)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "deleteIntruderPhoto" -> {
                    val path = call.argument<String>("path")
                    if (path != null) {
                        try {
                            val f = java.io.File(path)
                            if (f.exists()) f.delete()
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    } else {
                        result.error("INVALID_ARG", "Path required", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun drawableToByteArrayFast(drawable: Drawable): ByteArray? {
        return try {
            val size = 96
            val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            drawable.setBounds(0, 0, size, size)
            drawable.draw(canvas)

            val stream = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.JPEG, 80, stream)
            stream.toByteArray()
        } catch (e: Exception) {
            null
        }
    }

    private fun captureIntruderSelfie() {
        try {
            val cameraManager = getSystemService(Context.CAMERA_SERVICE) as? android.hardware.camera2.CameraManager ?: return
            var frontCameraId: String? = null
            for (id in cameraManager.cameraIdList) {
                val characteristics = cameraManager.getCameraCharacteristics(id)
                val facing = characteristics.get(android.hardware.camera2.CameraCharacteristics.LENS_FACING)
                if (facing == android.hardware.camera2.CameraCharacteristics.LENS_FACING_FRONT) {
                    frontCameraId = id
                    break
                }
            }
            if (frontCameraId == null) return

            val intruderDir = java.io.File(filesDir, "intruders")
            if (!intruderDir.exists()) intruderDir.mkdirs()

            val timeStamp = java.text.SimpleDateFormat("yyyyMMdd_HHmmss", java.util.Locale.US).format(java.util.Date())
            val photoFile = java.io.File(intruderDir, "INTRUDER_$timeStamp.jpg")

            val imageReader = android.media.ImageReader.newInstance(640, 480, android.graphics.ImageFormat.JPEG, 1)
            imageReader.setOnImageAvailableListener({ reader ->
                val image = reader.acquireLatestImage() ?: return@setOnImageAvailableListener
                val buffer = image.planes[0].buffer
                val bytes = ByteArray(buffer.remaining())
                buffer.get(bytes)
                image.close()
                try {
                    java.io.FileOutputStream(photoFile).use { it.write(bytes) }
                } catch (e: Exception) {}
            }, null)

            if (checkSelfPermission(android.Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) {
                cameraManager.openCamera(frontCameraId, object : android.hardware.camera2.CameraDevice.StateCallback() {
                    override fun onOpened(camera: android.hardware.camera2.CameraDevice) {
                        try {
                            val captureBuilder = camera.createCaptureRequest(android.hardware.camera2.CameraDevice.TEMPLATE_STILL_CAPTURE)
                            captureBuilder.addTarget(imageReader.surface)
                            camera.createCaptureSession(listOf(imageReader.surface), object : android.hardware.camera2.CameraCaptureSession.StateCallback() {
                                override fun onConfigured(session: android.hardware.camera2.CameraCaptureSession) {
                                    try {
                                        session.capture(captureBuilder.build(), object : android.hardware.camera2.CameraCaptureSession.CaptureCallback() {
                                            override fun onCaptureCompleted(session: android.hardware.camera2.CameraCaptureSession, request: android.hardware.camera2.CaptureRequest, result: android.hardware.camera2.TotalCaptureResult) {
                                                camera.close()
                                            }
                                        }, null)
                                    } catch (e: Exception) {
                                        camera.close()
                                    }
                                }
                                override fun onConfigureFailed(session: android.hardware.camera2.CameraCaptureSession) {
                                    camera.close()
                                }
                            }, null)
                        } catch (e: Exception) {
                            camera.close()
                        }
                    }
                    override fun onDisconnected(camera: android.hardware.camera2.CameraDevice) {
                        camera.close()
                    }
                    override fun onError(camera: android.hardware.camera2.CameraDevice, error: Int) {
                        camera.close()
                    }
                }, null)
            }
        } catch (e: Exception) {}
    }
}
