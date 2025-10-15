# 小米手机 VPN 应用配置指南

## 小米手机的特殊问题

小米手机(MIUI系统)对 VPN 应用有额外的限制和优化,需要特别配置才能正常工作。

### 常见问题

1. **后台被杀死** - MIUI 激进的电池优化会杀死 VPN 服务
2. **网络权限受限** - 需要额外的权限才能正常工作
3. **自启动限制** - VPN 服务可能无法自动重启
4. **省电模式冲突** - 省电模式会限制 VPN 功能

## 必需的权限配置

### 1. AndroidManifest.xml 已配置

你的 `android/app/src/main/AndroidManifest.xml` 已经包含了基本权限:

```xml
<!-- VPN 相关权限 -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_SPECIAL_USE" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

### 2. 小米手机用户需要手动设置

告知用户在小米手机上进行以下设置:

#### A. 关闭电池优化

1. 设置 → 应用设置 → 应用管理 → 找到你的应用
2. 省电策略 → 选择 **无限制**
3. 自启动 → **允许**

#### B. 锁定后台

1. 打开应用后,在最近任务界面
2. 下拉应用卡片,点击锁定图标 🔒
3. 防止被系统清理

#### C. 允许后台弹出界面

1. 设置 → 应用设置 → 应用管理 → 找到你的应用
2. 后台弹出界面 → **允许**

#### D. 允许通知

1. 设置 → 通知 → 应用通知 → 找到你的应用
2. 允许通知 → **开启**
3. 前台服务 → **允许**

## 代码优化建议

### 1. 增强前台服务通知

小米手机特别注重前台服务,需要优化通知:

```kotlin
// VpnService.kt
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
        .setOngoing(true)  // 重要: 防止被滑掉
        .setAutoCancel(false)  // 重要: 防止自动取消
        .setPriority(Notification.PRIORITY_MAX)  // 最高优先级
        .setCategory(Notification.CATEGORY_SERVICE)  // 标记为服务
        .build()
}
```

### 2. 增加 Service 重启机制

在 VpnService 中添加:

```kotlin
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
    
    // 重要: 返回 START_STICKY 确保服务被杀后会重启
    return START_STICKY
}
```

(你的代码已经这样配置了 ✅)

### 3. 添加唤醒锁 (可选)

对于小米手机,可能需要唤醒锁来保持 VPN 运行:

```kotlin
// 在 AndroidManifest.xml 中添加权限:
<uses-permission android:name="android.permission.WAKE_LOCK" />

// 在 VpnService 中:
private var wakeLock: PowerManager.WakeLock? = null

private fun startVpn(configJson: String) {
    try {
        // 获取唤醒锁
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "VpnService::WakeLock"
        )
        wakeLock?.acquire()
        
        // ... 启动 VPN 逻辑
    } catch (e: Exception) {
        // ...
    }
}

private fun stopVpn() {
    try {
        // ... 停止 VPN 逻辑
        
        // 释放唤醒锁
        wakeLock?.release()
        wakeLock = null
    } catch (e: Exception) {
        // ...
    }
}
```

## 小米手机特定的 UI 提示

### 在应用中添加设置指引

建议在首次连接时显示对话框,指导小米用户进行设置:

```dart
// lib/pages/home_page.dart

Future<void> _showMiuiSetupDialog() async {
  if (!Platform.isAndroid) return;
  
  // 检测是否是小米手机
  // 可以通过读取 Build.MANUFACTURER 判断
  
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('小米手机设置提示'),
      content: Text(
        '为确保 VPN 正常运行,请进行以下设置:\n\n'
        '1. 省电策略 → 选择"无限制"\n'
        '2. 自启动 → 允许\n'
        '3. 后台弹出界面 → 允许\n'
        '4. 锁定应用(最近任务中下拉锁定)\n\n'
        '是否前往设置?'
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('稍后'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            // 打开应用设置页面
            AndroidIntent(
              action: 'android.settings.APPLICATION_DETAILS_SETTINGS',
              data: 'package:com.example.demo2',
            ).launch();
          },
          child: Text('去设置'),
        ),
      ],
    ),
  );
}
```

### 检测小米手机

```kotlin
// 在 MainActivity.kt 或工具类中
companion object {
    fun isMiui(): Boolean {
        return !TextUtils.isEmpty(getSystemProperty("ro.miui.ui.version.name"))
    }
    
    private fun getSystemProperty(propName: String): String? {
        return try {
            val process = Runtime.getRuntime().exec("getprop $propName")
            process.inputStream.bufferedReader().use { it.readText().trim() }
        } catch (e: Exception) {
            null
        }
    }
}
```

## AndroidManifest 补充配置

### 添加小米手机优化属性

```xml
<application
    android:label="demo2"
    android:name="${applicationName}"
    android:icon="@mipmap/ic_launcher">
    
    <!-- 小米手机特殊配置 -->
    <meta-data
        android:name="android.max_aspect"
        android:value="2.4" />
    
    <!-- VPN 服务 -->
    <service
        android:name=".VpnService"
        android:exported="false"
        android:foregroundServiceType="specialUse"
        android:permission="android.permission.BIND_VPN_SERVICE"
        android:stopWithTask="false">  <!-- 重要: 防止任务移除时停止 -->
        <intent-filter>
            <action android:name="android.net.VpnService" />
        </intent-filter>
        <!-- 小米手机前台服务说明 -->
        <property
            android:name="android.app.PROPERTY_SPECIAL_USE_FGS_SUBTYPE"
            android:value="vpn" />
    </service>
</application>
```

## 测试清单

在小米手机上测试以下场景:

- [ ] 正常连接 VPN
- [ ] 锁屏后 VPN 是否保持连接
- [ ] 切换到其他应用后 VPN 是否保持
- [ ] 清理后台任务后 VPN 是否保持
- [ ] 重启手机后 VPN 状态
- [ ] 开启省电模式后 VPN 是否正常
- [ ] 飞行模式切换
- [ ] WiFi ↔ 移动数据切换

## 常见问题解决

### 问题 1: VPN 频繁断开

**原因**: MIUI 电池优化杀死进程

**解决**: 
1. 设置为无限制省电策略
2. 锁定后台
3. 确保前台服务通知一直显示

### 问题 2: 通知被自动隐藏

**原因**: MIUI 通知管理

**解决**:
1. 设置 → 通知 → 应用通知 → 允许
2. 代码中设置 `.setOngoing(true)` 和 `.setPriority(PRIORITY_MAX)`

### 问题 3: 重启后 VPN 不自动连接

**原因**: MIUI 自启动限制

**解决**:
1. 允许应用自启动
2. (可选) 实现 BOOT_COMPLETED 广播接收器

### 问题 4: 网络频繁切换

**原因**: MIUI 网络优化

**解决**:
在代码中处理网络变化:

```kotlin
// 监听网络变化
private val networkCallback = object : ConnectivityManager.NetworkCallback() {
    override fun onAvailable(network: Network) {
        Log.d(TAG, "网络可用: $network")
        // 重新连接或验证 VPN
    }
    
    override fun onLost(network: Network) {
        Log.d(TAG, "网络丢失: $network")
    }
}
```

## 小米手机型号特别注意

某些小米机型有额外的限制:

- **红米 K30 Pro** (你的手机) - Android 12 MIUI 13+
  - 需要特别注意电池优化
  - 建议在设置中完全关闭省电模式
  
- **小米 11/12/13 系列** - MIUI 14+
  - 新版 MIUI 对 VPN 限制更严格
  - 需要在"特殊权限"中允许 VPN

## 发布前优化

如果要发布到应用市场,针对小米手机:

1. **添加使用说明** - 在应用介绍中说明小米手机需要的设置
2. **首次启动引导** - 检测 MIUI 并显示设置指引
3. **定期检查** - 监控 VPN 状态,异常时提示用户检查设置
4. **日志记录** - 记录被杀死的情况,帮助调试

## 总结

小米手机(MIUI)对 VPN 应用确实有额外的限制,但通过:

1. ✅ 正确的前台服务配置 (已完成)
2. ✅ START_STICKY 返回值 (已完成)
3. ⚠️ 用户手动设置权限 (需要用户操作)
4. ⚠️ 应用内引导说明 (建议添加)

可以确保 VPN 在小米手机上稳定运行。

关键是**让用户知道要进行这些设置**,这是小米手机的特性,不是你的应用问题!

