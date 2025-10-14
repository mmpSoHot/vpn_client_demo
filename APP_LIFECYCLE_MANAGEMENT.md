# 应用生命周期管理

## 🔄 完整的资源清理机制

为了防止 sing-box 进程和系统代理残留，我们实现了完整的应用生命周期管理。

## 📋 三个关键时机的清理

### 1. **应用启动时清理** (`lib/main.dart`)

```dart
Future<void> _cleanupOnAppStart() async {
  try {
    print('🧹 应用启动，检查并清理残留资源...');
    
    // 清理残留的 sing-box 进程
    if (Platform.isWindows) {
      await Process.run('taskkill', ['/F', '/IM', 'sing-box.exe'], runInShell: true);
    } else if (Platform.isLinux || Platform.isMacOS) {
      await Process.run('pkill', ['-9', 'sing-box']);
    }
    
    // 清除系统代理
    await SystemProxyHelper.clearProxy();
    
    print('✅ 资源清理完成');
  } catch (e) {
    print('🔍 清理检查: $e');
  }
}
```

**清理内容**：
- ✅ 杀掉所有残留的 sing-box.exe 进程
- ✅ 清除系统代理设置
- ✅ 确保干净的启动状态

**调用时机**：
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 应用启动时清理残留资源
  await _cleanupOnAppStart();
  
  // ... 其他初始化
}
```

### 2. **窗口关闭时清理** (`lib/main.dart`)

```dart
class _AuthWrapperState extends State<AuthWrapper> with WindowListener {
  @override
  void onWindowClose() async {
    print('🪟 窗口即将关闭，清理资源...');
    
    try {
      // 清理 sing-box 进程
      if (Platform.isWindows) {
        await Process.run('taskkill', ['/F', '/IM', 'sing-box.exe'], runInShell: true);
      } else if (Platform.isLinux || Platform.isMacOS) {
        await Process.run('pkill', ['-9', 'sing-box']);
      }
      
      // 清除系统代理
      await SystemProxyHelper.clearProxy();
      
      print('✅ 资源清理完成，窗口关闭');
    } catch (e) {
      print('⚠️ 清理时出错: $e');
    }
    
    // 允许窗口关闭
    await windowManager.destroy();
  }
}
```

**清理内容**：
- ✅ 强制终止 sing-box 进程
- ✅ 清除系统代理
- ✅ 安全关闭窗口

**监听设置**：
```dart
@override
void initState() {
  super.initState();
  
  // 添加窗口关闭监听
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    windowManager.addListener(this);
  }
}

@override
void dispose() {
  // 移除窗口监听
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    windowManager.removeListener(this);
  }
  super.dispose();
}
```

### 3. **页面销毁时清理** (`lib/pages/home_page.dart`)

```dart
class _HomePageState extends State<HomePage> {
  @override
  void dispose() {
    // 移除监听器
    _userService.removeListener(_onUserServiceChanged);
    
    // 应用关闭时清理资源
    _cleanupOnAppClose();
    
    super.dispose();
  }

  Future<void> _cleanupOnAppClose() async {
    try {
      // 如果 VPN 正在连接，清理资源
      if (_isProxyEnabled) {
        print('🧹 应用关闭，清理 VPN 资源...');
        
        // 清除系统代理
        await SystemProxyHelper.clearProxy();
        
        // 停止 sing-box
        await SingboxManager.stop();
        
        print('✅ 资源清理完成');
      }
    } catch (e) {
      print('⚠️ 清理资源时出错: $e');
    }
  }
}
```

**清理内容**：
- ✅ 检查 VPN 连接状态
- ✅ 清除系统代理
- ✅ 停止 sing-box 进程

## 🛡️ 防御性清理机制

### sing-box 启动前强制清理

在每次启动 sing-box 前，都会清理可能的残留进程：

```dart
// lib/utils/singbox_manager.dart
static Future<bool> start() async {
  try {
    // 检查是否已经运行
    if (_process != null) {
      print('⚠️ sing-box 已在运行中，先停止旧进程');
      await stop();
    }

    // 强制清理所有可能残留的 sing-box 进程
    await _killAllSingboxProcesses();

    // 等待进程完全终止
    // ... 启动新进程
  }
}

static Future<void> _killAllSingboxProcesses() async {
  if (Platform.isWindows) {
    final result = await Process.run(
      'taskkill',
      ['/F', '/IM', 'sing-box.exe'],
      runInShell: true,
    );
    
    if (result.exitCode == 0) {
      print('🧹 已清理残留的 sing-box 进程');
      
      // 重试检查，确保进程完全终止
      for (int i = 0; i < 10; i++) {
        await Future.delayed(const Duration(milliseconds: 200));
        
        final checkResult = await Process.run(
          'tasklist',
          ['/FI', 'IMAGENAME eq sing-box.exe'],
          runInShell: true,
        );
        
        if (!checkResult.stdout.toString().contains('sing-box.exe')) {
          print('✅ sing-box 进程已完全终止');
          break;
        }
      }
    }
  }
}
```

**特点**：
- ✅ 强制终止所有 sing-box 进程
- ✅ 循环检查确保进程完全终止
- ✅ 最多等待 2 秒（10次 × 200ms）
- ✅ 避免端口占用错误

## 📊 清理时机总览

| 时机 | 触发条件 | 清理内容 | 实现位置 |
|------|---------|---------|----------|
| **应用启动** | main() 执行 | sing-box 进程 + 系统代理 | `lib/main.dart` |
| **窗口关闭** | 用户关闭窗口 | sing-box 进程 + 系统代理 | `lib/main.dart` (WindowListener) |
| **页面销毁** | HomePage dispose | sing-box 进程 + 系统代理 | `lib/pages/home_page.dart` |
| **VPN 启动前** | 每次连接 VPN | sing-box 残留进程 | `lib/utils/singbox_manager.dart` |
| **VPN 断开** | 用户断开连接 | sing-box 进程 + 系统代理 | `lib/pages/home_page.dart` |

## 🔍 清理验证

### 检查清理是否成功

**1. 检查 sing-box 进程**：
```powershell
# Windows
tasklist | findstr sing-box

# 应该没有输出（进程已清理）
```

**2. 检查端口占用**：
```powershell
netstat -ano | findstr :15808

# 应该没有输出（端口已释放）
```

**3. 检查系统代理**：
```
Windows 设置 → 网络和Internet → 代理

应该显示:
- 使用代理服务器: 关闭
```

## ⚙️ 配置说明

### Windows 平台清理命令

```powershell
# 强制终止进程
taskkill /F /IM sing-box.exe

# /F - 强制终止
# /IM - 按映像名称（进程名）
```

### Linux/macOS 平台清理命令

```bash
# 强制终止进程
pkill -9 sing-box

# -9 - SIGKILL 信号（强制终止）
```

## 🎯 最佳实践

### 1. 优雅关闭

应用应该：
- ✅ 监听窗口关闭事件
- ✅ 在关闭前清理资源
- ✅ 确保系统代理被清除

### 2. 防御性编程

启动前应该：
- ✅ 检查并清理残留进程
- ✅ 验证端口是否可用
- ✅ 重试机制

### 3. 用户体验

- ✅ 启动时自动清理，用户无感知
- ✅ 关闭时自动清理，无需手动操作
- ✅ 连接失败时自动重试

## 🐛 调试技巧

### 查看清理日志

应用会在控制台输出清理日志：

```
🧹 应用启动，检查并清理残留资源...
✅ 资源清理完成

🪟 窗口即将关闭，清理资源...
✅ 资源清理完成，窗口关闭

🧹 应用关闭，清理 VPN 资源...
✅ 资源清理完成
```

### 手动清理命令

如果自动清理失败，可以手动执行：

```powershell
# Windows 一键清理
taskkill /F /IM sing-box.exe
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyEnable /t REG_DWORD /d 0 /f
```

## 📚 相关文档

- `TROUBLESHOOTING.md` - 问题排查指南
- `VPN_CONNECTION_IMPLEMENTATION.md` - VPN 连接实现
- `SYSTEM_PROXY_USAGE.md` - 系统代理使用

## ✅ 总结

通过在**三个关键时机**实现资源清理：

1. **应用启动时** - 清理上次异常退出的残留
2. **窗口关闭时** - 确保资源完全释放
3. **页面销毁时** - 双重保险

彻底解决了：
- ❌ sing-box 进程残留
- ❌ 端口占用问题
- ❌ 系统代理未清除
- ❌ 资源泄漏

确保了应用的**稳定性和可靠性**！🎉

