package com.example.demo2

import android.net.VpnService
import android.os.Build
import android.util.Log
import io.nekohasekai.libbox.InterfaceUpdateListener
import io.nekohasekai.libbox.LocalDNSTransport
import io.nekohasekai.libbox.NetworkInterfaceIterator
import io.nekohasekai.libbox.Notification
import io.nekohasekai.libbox.PlatformInterface
import io.nekohasekai.libbox.StringIterator
import io.nekohasekai.libbox.TunOptions
import io.nekohasekai.libbox.WIFIState

/**
 * sing-box 平台接口实现
 * 基于 sing-box-main 源码适配
 */
class PlatformInterfaceImpl(
    private val vpnService: VpnService
) : PlatformInterface {
    
    companion object {
        private const val TAG = "PlatformInterface"
    }
    
    override fun localDNSTransport(): LocalDNSTransport? {
        // 简化实现：不使用本地 DNS 传输
        return null
    }
    
    override fun usePlatformAutoDetectInterfaceControl(): Boolean {
        return true
    }
    
    override fun autoDetectInterfaceControl(fd: Int) {
        // 保护 socket，避免被 VPN 路由（防止循环）
        vpnService.protect(fd)
        Log.d(TAG, "保护 socket: fd=$fd")
    }
    
    override fun openTun(options: TunOptions): Int {
        try {
            Log.d(TAG, "打开 TUN 接口...")
            Log.d(TAG, "  MTU: ${options.mtu}")
            Log.d(TAG, "  Auto Route: ${options.autoRoute}")
            
            val builder = vpnService.Builder()
            builder.setSession("VPN Client Demo")
            builder.setMtu(options.mtu)
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                builder.setMetered(false)
            }
            
            // 添加 IPv4 地址
            val inet4Address = options.inet4Address
            while (inet4Address.hasNext()) {
                val addr = inet4Address.next()
                builder.addAddress(addr.address(), addr.prefix())
                Log.d(TAG, "  添加地址: ${addr.address()}/${addr.prefix()}")
            }
            
            // 添加 IPv6 地址
            val inet6Address = options.inet6Address
            while (inet6Address.hasNext()) {
                val addr = inet6Address.next()
                builder.addAddress(addr.address(), addr.prefix())
                Log.d(TAG, "  添加地址: ${addr.address()}/${addr.prefix()}")
            }
            
            // 配置路由
            if (options.autoRoute) {
                // 添加 DNS (使用 .value 属性)
                builder.addDnsServer(options.dnsServerAddress.value)
                Log.d(TAG, "  DNS: ${options.dnsServerAddress.value}")
                
                // 添加路由
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    // Android 13+ 使用新的路由 API
                    val inet4RouteAddress = options.inet4RouteAddress
                    if (inet4RouteAddress.hasNext()) {
                        while (inet4RouteAddress.hasNext()) {
                            val route = inet4RouteAddress.next()
                            builder.addRoute(route.address(), route.prefix())
                        }
                    } else if (options.inet4Address.hasNext()) {
                        builder.addRoute("0.0.0.0", 0)
                    }
                } else {
                    // Android 12 及以下
                    val inet4RouteRange = options.inet4RouteRange
                    if (inet4RouteRange.hasNext()) {
                        while (inet4RouteRange.hasNext()) {
                            val route = inet4RouteRange.next()
                            builder.addRoute(route.address(), route.prefix())
                        }
                    } else {
                        builder.addRoute("0.0.0.0", 0)
                    }
                }
                
                Log.d(TAG, "  路由已配置")
            }
            
            // 建立 VPN 连接
            val pfd = builder.establish()
                ?: throw Exception("建立 VPN 连接失败，可能权限被拒绝")
            
            val fd = pfd.fd
            Log.d(TAG, "✅ TUN 接口已建立: fd=$fd")
            
            return fd
            
        } catch (e: Exception) {
            Log.e(TAG, "打开 TUN 失败", e)
            throw e
        }
    }
    
    override fun writeLog(message: String) {
        Log.d("sing-box", message)
    }
    
    override fun useProcFS(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.Q
    }
    
    override fun findConnectionOwner(
        ipProtocol: Int,
        sourceAddress: String,
        sourcePort: Int,
        destinationAddress: String,
        destinationPort: Int
    ): Int {
        // 简化实现：返回 0 表示未知
        return 0
    }
    
    override fun packageNameByUid(uid: Int): String {
        // 简化实现：返回空字符串
        return ""
    }
    
    override fun uidByPackageName(packageName: String): Int {
        // 简化实现：返回 0
        return 0
    }
    
    override fun startDefaultInterfaceMonitor(listener: InterfaceUpdateListener?) {
        // 简化实现：不监控接口变化
        Log.d(TAG, "开始默认接口监控")
    }
    
    override fun closeDefaultInterfaceMonitor(listener: InterfaceUpdateListener?) {
        // 简化实现
        Log.d(TAG, "关闭默认接口监控")
    }
    
    override fun getInterfaces(): NetworkInterfaceIterator? {
        // 简化实现：返回 null
        return null
    }
    
    override fun underNetworkExtension(): Boolean {
        return false
    }
    
    override fun includeAllNetworks(): Boolean {
        return false
    }
    
    override fun readWIFIState(): WIFIState? {
        // 简化实现：不读取 WiFi 状态
        return null
    }
    
    override fun systemCertificates(): StringIterator? {
        // 简化实现：不提供系统证书
        return null
    }
    
    override fun clearDNSCache() {
        // DNS 缓存清理
        Log.d(TAG, "清除 DNS 缓存")
    }
    
    override fun sendNotification(notification: Notification?) {
        // 简化实现：只打印日志
        notification?.let {
            Log.d(TAG, "通知: ${it.title} - ${it.body}")
        }
    }
}
