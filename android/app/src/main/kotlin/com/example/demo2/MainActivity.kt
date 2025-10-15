package com.example.demo2

import android.content.Intent
import android.net.VpnService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    
    companion object {
        private const val CHANNEL = "vpn_service"
        private const val VPN_REQUEST_CODE = 100
    }
    
    private var pendingResult: MethodChannel.Result? = null
    
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
                        // TODO: 实现状态检查
                        result.success(false)
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
