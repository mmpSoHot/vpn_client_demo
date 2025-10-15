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
        val srsFiles = listOf(
            "geosite-private.srs",
            "geosite-cn.srs",
            "geoip-cn.srs"
        )
        
        for (fileName in srsFiles) {
            val destFile = File(workingDir, fileName)
            // 每次都覆盖,确保使用最新的规则文件
            try {
                assets.open("srss/$fileName").use { input ->
                    destFile.outputStream().use { output ->
                        input.copyTo(output)
                    }
                }
                android.util.Log.d("MainActivity", "✅ 复制规则文件: $fileName -> ${destFile.path}")
            } catch (e: Exception) {
                android.util.Log.e("MainActivity", "❌ 复制规则文件失败: $fileName", e)
            }
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
