package com.example.demo2

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.VpnService as AndroidVpnService
import android.os.Build
import android.os.IBinder
import android.os.ParcelFileDescriptor
import android.util.Log
import io.nekohasekai.libbox.Libbox
import io.nekohasekai.libbox.BoxService

/**
 * Android VPN 服务
 * 基于 sing-box libbox 实现
 * 
 * 注意：需要先获取 libbox.aar 并放置在 android/app/libs/ 目录
 * 取消注释 import libbox.* 相关代码后才能编译
 */
class VpnService : AndroidVpnService() {
    
    private var boxInstance: BoxService? = null
    private var vpnInterface: ParcelFileDescriptor? = null
    
    companion object {
        private const val TAG = "VpnService"
        const val ACTION_START = "com.example.demo2.vpn.START"
        const val ACTION_STOP = "com.example.demo2.vpn.STOP"
        const val EXTRA_CONFIG = "config"
        
        private const val NOTIFICATION_ID = 1
        private const val CHANNEL_ID = "vpn_service_channel"
        
        // 服务运行状态
        @Volatile
        var isServiceRunning = false
            private set
    }
    
    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "VpnService onCreate")
        createNotificationChannel()
        isServiceRunning = true
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "onStartCommand: ${intent?.action}")
        
        when (intent?.action) {
            ACTION_START -> {
                val config = intent.getStringExtra(EXTRA_CONFIG)
                if (config != null) {
                    startVpn(config)
                } else {
                    Log.e(TAG, "配置为空")
                    stopSelf()
                }
            }
            ACTION_STOP -> {
                stopVpn()
            }
        }
        
        return START_STICKY
    }
    
    private fun startVpn(configJson: String) {
        try {
            Log.d(TAG, "启动 VPN...")
            Log.d(TAG, "配置长度: ${configJson.length} 字符")
            
            // 确保规则文件存在（如果不存在则从 assets 复制）
            ensureRuleFilesExist()
            
            // 预先创建 cache.db 文件
            try {
                val cacheFile = java.io.File(cacheDir, "cache.db")
                if (!cacheFile.exists()) {
                    cacheFile.createNewFile()
                    Log.d(TAG, "创建 cache.db: ${cacheFile.absolutePath}")
                }
            } catch (e: Exception) {
                Log.w(TAG, "创建 cache.db 失败: $e")
            }
            
            // 显示前台服务通知
            startForeground(NOTIFICATION_ID, createNotification())
            
            // 创建平台接口
            val platformInterface = PlatformInterfaceImpl(this)
            
            // 创建 sing-box 实例
            Log.d(TAG, "📦 创建 sing-box 实例...")
            boxInstance = Libbox.newService(configJson, platformInterface)
            
            // 启动 sing-box
            Log.d(TAG, "🚀 启动 sing-box...")
            boxInstance?.start()
            
            Log.d(TAG, "✅ VPN 启动成功")
            
        } catch (e: Exception) {
            Log.e(TAG, "启动 VPN 失败", e)
            Log.e(TAG, "错误堆栈:", e)
            stopSelf()
        }
    }
    
    private fun stopVpn() {
        try {
            Log.d(TAG, "停止 VPN...")
            
            boxInstance?.close()
            boxInstance = null
            
            vpnInterface?.close()
            vpnInterface = null
            
            Log.d(TAG, "✅ VPN 已停止")
            
        } catch (e: Exception) {
            Log.e(TAG, "停止 VPN 失败", e)
        } finally {
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
        }
    }
    
    override fun onDestroy() {
        Log.d(TAG, "VpnService onDestroy")
        isServiceRunning = false
        stopVpn()
        super.onDestroy()
    }
    
    override fun onBind(intent: Intent?): IBinder? {
        return null
    }
    
    override fun onRevoke() {
        Log.d(TAG, "VPN 权限被撤销")
        stopVpn()
        super.onRevoke()
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "VPN 服务",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "VPN 连接状态通知"
            }
            
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }
    
    private fun createNotification(): Notification {
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_IMMUTABLE
        )
        
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        
        return builder
            .setContentTitle("VPN 已连接")
            .setContentText("流量正在通过 VPN")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }
    
    /**
     * 确保规则文件存在
     * 如果文件不存在，则从 assets 复制
     */
    private fun ensureRuleFilesExist() {
        val workingDir = java.io.File(filesDir, "sing-box/run")
        
        // 规则文件映射：文件名 -> assets 子目录
        val requiredFilesMap = mapOf(
            "geosite-private.srs" to "geosite",
            "geosite-cn.srs" to "geosite",
            "geoip-cn.srs" to "geoip"
        )
        
        Log.d(TAG, "🔍 检查规则文件...")
        Log.d(TAG, "   工作目录: ${workingDir.path}")
        
        // 确保目录存在
        if (!workingDir.exists()) {
            workingDir.mkdirs()
            Log.d(TAG, "   ✅ 创建工作目录: ${workingDir.path}")
        }
        
        var needCopy = false
        for ((fileName, _) in requiredFilesMap) {
            val file = java.io.File(workingDir, fileName)
            if (!file.exists()) {
                Log.w(TAG, "   ⚠️ $fileName 不存在，需要从 assets 复制")
                needCopy = true
                break
            } else {
                Log.d(TAG, "   ✅ $fileName (${file.length()} 字节)")
            }
        }
        
        // 如果需要，从 assets 复制文件
        if (needCopy) {
            Log.d(TAG, "📦 开始从 assets 复制规则文件...")
            copyAssetsToWorkingDir(workingDir, requiredFilesMap)
            
            // 验证复制后的文件
            Log.d(TAG, "🔍 验证复制的文件...")
            var allFilesExist = true
            for ((fileName, _) in requiredFilesMap) {
                val file = java.io.File(workingDir, fileName)
                if (file.exists()) {
                    Log.d(TAG, "   ✅ $fileName (${file.length()} 字节)")
                } else {
                    Log.e(TAG, "   ❌ $fileName 仍然不存在!")
                    allFilesExist = false
                }
            }
            
            if (!allFilesExist) {
                throw Exception("规则文件复制失败！请检查 assets 目录")
            }
        }
    }
    
    /**
     * 从 assets 复制文件到工作目录
     */
    private fun copyAssetsToWorkingDir(workingDir: java.io.File, filesMap: Map<String, String>) {
        val assetManager = assets
        
        for ((fileName, subDir) in filesMap) {
            val destFile = java.io.File(workingDir, fileName)
            try {
                Log.d(TAG, "   复制: $fileName (从 $subDir)")
                
                // 打开 assets 文件（Flutter assets 需要加 flutter_assets/ 前缀）
                val assetPath = "flutter_assets/assets/datas/$subDir/$fileName"
                Log.d(TAG, "      assets 路径: $assetPath")
                assetManager.open(assetPath).use { input ->
                    // 写入目标文件
                    destFile.outputStream().use { output ->
                        val bytesCopied = input.copyTo(output)
                        Log.d(TAG, "      已复制: $bytesCopied 字节")
                    }
                }
                
                // 验证文件
                if (destFile.exists() && destFile.length() > 0) {
                    Log.d(TAG, "   ✅ 复制成功: ${destFile.name}")
                } else {
                    Log.e(TAG, "   ❌ 复制失败: ${destFile.name}")
                }
            } catch (e: Exception) {
                Log.e(TAG, "   ❌ 复制规则文件失败: $fileName", e)
                Log.e(TAG, "      错误: ${e.message}")
                throw Exception("无法复制规则文件 $fileName: ${e.message}")
            }
        }
    }
}

