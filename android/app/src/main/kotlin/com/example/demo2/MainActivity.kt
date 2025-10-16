package com.example.demo2

import android.content.Intent
import android.net.VpnService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.nekohasekai.libbox.Libbox
import io.nekohasekai.libbox.SetupOptions
import java.io.File

class MainActivity : FlutterActivity() {
    
    companion object {
        private const val CHANNEL = "vpn_service"
        private const val VPN_REQUEST_CODE = 100
    }
    
    private var pendingResult: MethodChannel.Result? = null
    
    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        
        android.util.Log.d("MainActivity", "🚀 MainActivity.onCreate() 开始")
        
        // 初始化 libbox (重要!)
        setupLibbox()
        
        android.util.Log.d("MainActivity", "✅ MainActivity.onCreate() 完成")
    }
    
    private fun setupLibbox() {
        android.util.Log.d("MainActivity", "🔧 开始初始化 Libbox...")
        try {
            val baseDir = File(filesDir, "sing-box")
            val workingDir = File(baseDir, "run")
            val tempDir = cacheDir
            
            android.util.Log.d("MainActivity", "📁 创建目录...")
            android.util.Log.d("MainActivity", "   baseDir: ${baseDir.path}")
            android.util.Log.d("MainActivity", "   workingDir: ${workingDir.path}")
            android.util.Log.d("MainActivity", "   tempDir: ${tempDir.path}")
            
            baseDir.mkdirs()
            workingDir.mkdirs()
            tempDir.mkdirs()
            
            // 复制 assets 中的 .srs 文件到 working directory
            android.util.Log.d("MainActivity", "📦 开始复制 .srs 文件...")
            copyAssetsToWorkingDir(workingDir)
            android.util.Log.d("MainActivity", "✅ .srs 文件复制完成")
            
            android.util.Log.d("MainActivity", "⚙️ 调用 Libbox.setup()...")
            Libbox.setup(SetupOptions().also {
                it.basePath = baseDir.path
                it.workingPath = workingDir.path
                it.tempPath = tempDir.path
            })
            
            android.util.Log.d("MainActivity", "✅ Libbox 初始化成功")
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "❌ Libbox 初始化失败", e)
            e.printStackTrace()
        }
    }
    
    private fun copyAssetsToWorkingDir(workingDir: File) {
        // 规则文件映射：文件名 -> assets 子目录
        val srsFilesMap = mapOf(
            "geosite-private.srs" to "geosite",
            "geosite-cn.srs" to "geosite",
            "geoip-cn.srs" to "geoip"
        )
        
        android.util.Log.d("MainActivity", "📦 开始复制 ${srsFilesMap.size} 个规则文件到: ${workingDir.path}")
        
        // 先列出 assets 目录中的文件（用于调试）
        try {
            val geositeFiles = assets.list("flutter_assets/assets/datas/geosite")
            val geoipFiles = assets.list("flutter_assets/assets/datas/geoip")
            if (geositeFiles != null) {
                android.util.Log.d("MainActivity", "📁 geosite 文件: ${geositeFiles.joinToString(", ")}")
            }
            if (geoipFiles != null) {
                android.util.Log.d("MainActivity", "📁 geoip 文件: ${geoipFiles.joinToString(", ")}")
            }
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "❌ 列出 assets 文件失败", e)
        }
        
        for ((fileName, subDir) in srsFilesMap) {
            val destFile = File(workingDir, fileName)
            try {
                android.util.Log.d("MainActivity", "   处理文件: $fileName (从 $subDir)")
                
                // 打开 assets 文件（Flutter assets 需要加 flutter_assets/ 前缀）
                val assetPath = "flutter_assets/assets/datas/$subDir/$fileName"
                android.util.Log.d("MainActivity", "      assets 路径: $assetPath")
                assets.open(assetPath).use { input ->
                    val fileSize = input.available()
                    android.util.Log.d("MainActivity", "      原文件大小: $fileSize 字节")
                    
                    // 写入目标文件
                    destFile.outputStream().use { output ->
                        val bytesCopied = input.copyTo(output)
                        android.util.Log.d("MainActivity", "      已复制: $bytesCopied 字节")
                    }
                }
                
                // 验证文件是否存在且有内容
                if (destFile.exists()) {
                    val size = destFile.length()
                    android.util.Log.d("MainActivity", "   ✅ 复制成功: ${destFile.path} ($size 字节)")
                } else {
                    android.util.Log.e("MainActivity", "   ❌ 文件不存在: ${destFile.path}")
                }
            } catch (e: Exception) {
                android.util.Log.e("MainActivity", "   ❌ 复制规则文件失败: $fileName", e)
                android.util.Log.e("MainActivity", "      错误类型: ${e.javaClass.simpleName}")
                android.util.Log.e("MainActivity", "      错误消息: ${e.message}")
            }
        }
        
        // 列出工作目录中的所有文件（验证）
        try {
            val files = workingDir.listFiles()
            if (files != null && files.isNotEmpty()) {
                android.util.Log.d("MainActivity", "📁 工作目录中的文件:")
                files.forEach { file ->
                    android.util.Log.d("MainActivity", "   - ${file.name} (${file.length()} 字节)")
                }
            } else {
                android.util.Log.w("MainActivity", "⚠️ 工作目录为空: ${workingDir.path}")
            }
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "❌ 列出工作目录文件失败", e)
        }
    }
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "checkPermission" -> {
                        // 检查 VPN 权限
                        val intent = VpnService.prepare(this)
                        result.success(intent == null)
                    }
                    
                    "requestPermission" -> {
                        // 请求 VPN 权限
                        val intent = VpnService.prepare(this)
                        if (intent != null) {
                            pendingResult = result
                            startActivityForResult(intent, VPN_REQUEST_CODE)
                        } else {
                            result.success(true)
                        }
                    }
                    
                    "startVpn" -> {
                        // 启动 VPN
                        val config = call.argument<String>("config")
                        if (config != null) {
                            val intent = Intent(this, com.example.demo2.VpnService::class.java).apply {
                                action = com.example.demo2.VpnService.ACTION_START
                                putExtra(com.example.demo2.VpnService.EXTRA_CONFIG, config)
                            }
                            startService(intent)
                            result.success(true)
                        } else {
                            result.error("INVALID_CONFIG", "配置为空", null)
                        }
                    }
                    
                    "stopVpn" -> {
                        // 停止 VPN
                        val intent = Intent(this, com.example.demo2.VpnService::class.java).apply {
                            action = com.example.demo2.VpnService.ACTION_STOP
                        }
                        startService(intent)
                        result.success(true)
                    }
                    
                    "isRunning" -> {
                        // 检查 VPN 是否运行中
                        // 通过检查 VPN 服务是否在运行来判断
                        val isRunning = com.example.demo2.VpnService.isServiceRunning
                        result.success(isRunning)
                    }
                    
                    else -> result.notImplemented()
                }
            }
    }
    
    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        
        if (requestCode == VPN_REQUEST_CODE) {
            pendingResult?.success(resultCode == RESULT_OK)
            pendingResult = null
        }
    }
}
