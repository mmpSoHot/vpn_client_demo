package com.example.demo2

import android.annotation.SuppressLint
import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.VpnService
import android.os.Build
import android.os.Process
import android.system.OsConstants
import android.util.Log
import io.nekohasekai.libbox.InterfaceUpdateListener
import io.nekohasekai.libbox.Libbox
import io.nekohasekai.libbox.LocalDNSTransport
import io.nekohasekai.libbox.NetworkInterfaceIterator
import io.nekohasekai.libbox.Notification
import io.nekohasekai.libbox.PlatformInterface
import io.nekohasekai.libbox.StringIterator
import io.nekohasekai.libbox.TunOptions
import io.nekohasekai.libbox.WIFIState
import java.net.Inet6Address
import java.net.InetAddress
import java.net.InterfaceAddress
import java.net.NetworkInterface
import io.nekohasekai.libbox.NetworkInterface as LibboxNetworkInterface

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
        Log.w(TAG, "⚠️⚠️⚠️ autoDetectInterfaceControl() 被调用, fd=$fd ⚠️⚠️⚠️")
        val protected = vpnService.protect(fd)
        if (protected) {
            Log.d(TAG, "✅ 保护 socket 成功: fd=$fd")
        } else {
            Log.e(TAG, "❌ 保护 socket 失败: fd=$fd")
        }
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
            var hasIPv4 = false
            while (inet4Address.hasNext()) {
                val addr = inet4Address.next()
                builder.addAddress(addr.address(), addr.prefix())
                Log.d(TAG, "  添加地址: ${addr.address()}/${addr.prefix()}")
                hasIPv4 = true
            }
            
            // 添加 IPv6 地址
            val inet6Address = options.inet6Address
            var hasIPv6 = false
            while (inet6Address.hasNext()) {
                val addr = inet6Address.next()
                builder.addAddress(addr.address(), addr.prefix())
                Log.d(TAG, "  添加地址: ${addr.address()}/${addr.prefix()}")
                hasIPv6 = true
            }
            
            // 配置路由
            if (options.autoRoute) {
                // 添加 DNS (使用 .value 属性)
                try {
                    val dnsAddr = InetAddress.getByName(options.dnsServerAddress.value)
                    builder.addDnsServer(dnsAddr)
                    Log.d(TAG, "  DNS: ${options.dnsServerAddress.value}")
                } catch (e: Exception) {
                    Log.e(TAG, "DNS 地址解析失败: ${options.dnsServerAddress.value}", e)
                }
                
                // 添加默认路由 (所有流量都走 VPN)
                if (hasIPv4) {
                    builder.addRoute("0.0.0.0", 0)
                    Log.d(TAG, "  ✅ 添加路由: 0.0.0.0/0 (所有 IPv4 流量)")
                }
                
                // 如果有 IPv6,也添加 IPv6 路由
                if (hasIPv6) {
                    try {
                        builder.addRoute("::", 0)
                        Log.d(TAG, "  ✅ 添加路由: ::/0 (所有 IPv6 流量)")
                    } catch (e: Exception) {
                        Log.w(TAG, "添加 IPv6 路由失败", e)
                    }
                }
                
                Log.d(TAG, "  路由配置完成")
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
        // 输出 sing-box 日志
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
        Log.d(TAG, "⚠️ 开始默认接口监控")
        
        if (listener == null) {
            Log.w(TAG, "listener 为 null,跳过接口初始化")
            return
        }
        
        // 立即触发一次接口更新 (关键!)
        // 这会初始化 sing-box 的网络接口列表
        try {
            val connectivityManager = vpnService.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            val activeNetwork = connectivityManager.activeNetwork
            
            if (activeNetwork != null) {
                val linkProperties = connectivityManager.getLinkProperties(activeNetwork)
                if (linkProperties != null) {
                    val interfaceName = linkProperties.interfaceName
                    val networkInterface = NetworkInterface.getByName(interfaceName)
                    if (networkInterface != null) {
                        val interfaceIndex = networkInterface.index
                        Log.d(TAG, "✅ 初始化默认接口: $interfaceName, index: $interfaceIndex")
                        listener.updateDefaultInterface(interfaceName, interfaceIndex, false, false)
                    } else {
                        Log.w(TAG, "无法获取网络接口: $interfaceName")
                        listener.updateDefaultInterface("", -1, false, false)
                    }
                } else {
                    Log.w(TAG, "无法获取 LinkProperties")
                    listener.updateDefaultInterface("", -1, false, false)
                }
            } else {
                Log.w(TAG, "没有活跃的网络")
                listener.updateDefaultInterface("", -1, false, false)
            }
        } catch (e: Exception) {
            Log.e(TAG, "初始化默认接口失败", e)
            listener.updateDefaultInterface("", -1, false, false)
        }
    }
    
    override fun closeDefaultInterfaceMonitor(listener: InterfaceUpdateListener?) {
        // 简化实现
        Log.d(TAG, "关闭默认接口监控")
    }
    
    override fun getInterfaces(): NetworkInterfaceIterator {
        // 完全参照 sing-box-for-android 实现
        Log.w(TAG, "⚠️ getInterfaces() 被调用")
        
        val connectivityManager = vpnService.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val networks = connectivityManager.allNetworks
        val networkInterfaces = NetworkInterface.getNetworkInterfaces().toList()
        val interfaces = mutableListOf<LibboxNetworkInterface>()
        
        for (network in networks) {
            val boxInterface = LibboxNetworkInterface()
            val linkProperties = connectivityManager.getLinkProperties(network) ?: continue
            val networkCapabilities = connectivityManager.getNetworkCapabilities(network) ?: continue
            
            boxInterface.name = linkProperties.interfaceName
            val networkInterface = networkInterfaces.find { it.name == boxInterface.name } ?: continue
            
            // DNS 服务器
            boxInterface.dnsServer = StringArray(
                linkProperties.dnsServers.mapNotNull { it.hostAddress }.iterator()
            )
            
            // 接口类型
            boxInterface.type = when {
                networkCapabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> Libbox.InterfaceTypeWIFI
                networkCapabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> Libbox.InterfaceTypeCellular
                networkCapabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> Libbox.InterfaceTypeEthernet
                else -> Libbox.InterfaceTypeOther
            }
            
            boxInterface.index = networkInterface.index
            
            // MTU
            runCatching {
                boxInterface.mtu = networkInterface.mtu
            }.onFailure {
                Log.e(TAG, "获取 MTU 失败: ${boxInterface.name}", it)
            }
            
            // 地址
            boxInterface.addresses = StringArray(
                networkInterface.interfaceAddresses.map { it.toPrefix() }.iterator()
            )
            
            // 标志
            var dumpFlags = 0
            if (networkCapabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)) {
                dumpFlags = OsConstants.IFF_UP or OsConstants.IFF_RUNNING
            }
            if (networkInterface.isLoopback) {
                dumpFlags = dumpFlags or OsConstants.IFF_LOOPBACK
            }
            if (networkInterface.isPointToPoint) {
                dumpFlags = dumpFlags or OsConstants.IFF_POINTOPOINT
            }
            if (networkInterface.supportsMulticast()) {
                dumpFlags = dumpFlags or OsConstants.IFF_MULTICAST
            }
            boxInterface.flags = dumpFlags
            
            // 是否计费
            boxInterface.metered = !networkCapabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED)
            
            interfaces.add(boxInterface)
            Log.d(TAG, "  接口: ${boxInterface.name}, type: ${boxInterface.type}, index: ${boxInterface.index}")
        }
        
        Log.d(TAG, "  共 ${interfaces.size} 个网络接口")
        
        return InterfaceArray(interfaces.iterator())
    }
    
    // 辅助类
    private class InterfaceArray(private val iterator: Iterator<LibboxNetworkInterface>) : NetworkInterfaceIterator {
        override fun hasNext(): Boolean = iterator.hasNext()
        override fun next(): LibboxNetworkInterface = iterator.next()
    }
    
    private class StringArray(private val iterator: Iterator<String>) : StringIterator {
        override fun len(): Int = 0  // not used by core
        override fun hasNext(): Boolean = iterator.hasNext()
        override fun next(): String = iterator.next()
    }
    
    private fun InterfaceAddress.toPrefix(): String {
        return if (address is Inet6Address) {
            "${Inet6Address.getByAddress(address.address).hostAddress}/${networkPrefixLength}"
        } else {
            "${address.hostAddress}/${networkPrefixLength}"
        }
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
