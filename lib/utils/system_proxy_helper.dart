import 'dart:io';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// Windows 系统代理管理工具
/// 用于设置和清除 Windows 系统代理
class SystemProxyHelper {
  // 注册表路径
  static const String _registryPath =
      r'Software\Microsoft\Windows\CurrentVersion\Internet Settings';

  /// 设置系统代理
  /// [host] 代理服务器地址，如 "127.0.0.1"
  /// [port] 代理端口，如 15808
  static Future<bool> setProxy(String host, int port) async {
    if (!Platform.isWindows) {
      print('⚠️ 系统代理设置仅支持 Windows 平台');
      return false;
    }

    try {
      final proxyServer = '$host:$port';
      print('🔧 设置系统代理: $proxyServer');

      // 打开注册表键
      final hKey = calloc<HKEY>();
      var result = RegOpenKeyEx(
        HKEY_CURRENT_USER,
        _registryPath.toNativeUtf16(),
        0,
        REG_SAM_FLAGS.KEY_SET_VALUE,
        hKey,
      );

      if (result != WIN32_ERROR.ERROR_SUCCESS) {
        print('❌ 打开注册表失败: $result');
        calloc.free(hKey);
        return false;
      }

      try {
        // 设置 ProxyEnable = 1
        final enableValue = calloc<DWORD>();
        enableValue.value = 1;
        result = RegSetValueEx(
          hKey.value,
          'ProxyEnable'.toNativeUtf16(),
          0,
          REG_VALUE_TYPE.REG_DWORD,
          enableValue.cast(),
          sizeOf<DWORD>(),
        );
        calloc.free(enableValue);

        if (result != WIN32_ERROR.ERROR_SUCCESS) {
          print('❌ 设置 ProxyEnable 失败: $result');
          return false;
        }

        // 设置 ProxyServer = "host:port"
        final serverValue = proxyServer.toNativeUtf16();
        result = RegSetValueEx(
          hKey.value,
          'ProxyServer'.toNativeUtf16(),
          0,
          REG_VALUE_TYPE.REG_SZ,
          serverValue.cast(),
          (proxyServer.length + 1) * 2, // Unicode 字符串长度
        );
        calloc.free(serverValue);

        if (result != WIN32_ERROR.ERROR_SUCCESS) {
          print('❌ 设置 ProxyServer 失败: $result');
          return false;
        }

        // 设置 ProxyOverride = "<local>" (本地地址不走代理)
        final overrideValue = '<local>'.toNativeUtf16();
        result = RegSetValueEx(
          hKey.value,
          'ProxyOverride'.toNativeUtf16(),
          0,
          REG_VALUE_TYPE.REG_SZ,
          overrideValue.cast(),
          ('<local>'.length + 1) * 2,
        );
        calloc.free(overrideValue);

        // 通知系统代理设置已更改
        _notifyProxyChange();

        print('✅ 系统代理设置成功: $proxyServer');
        return true;
      } finally {
        RegCloseKey(hKey.value);
        calloc.free(hKey);
      }
    } catch (e) {
      print('❌ 设置系统代理失败: $e');
      return false;
    }
  }

  /// 清除系统代理
  static Future<bool> clearProxy() async {
    if (!Platform.isWindows) {
      print('⚠️ 系统代理清除仅支持 Windows 平台');
      return false;
    }

    try {
      print('🔧 清除系统代理');

      // 打开注册表键
      final hKey = calloc<HKEY>();
      var result = RegOpenKeyEx(
        HKEY_CURRENT_USER,
        _registryPath.toNativeUtf16(),
        0,
        REG_SAM_FLAGS.KEY_SET_VALUE,
        hKey,
      );

      if (result != WIN32_ERROR.ERROR_SUCCESS) {
        print('❌ 打开注册表失败: $result');
        calloc.free(hKey);
        return false;
      }

      try {
        // 设置 ProxyEnable = 0
        final enableValue = calloc<DWORD>();
        enableValue.value = 0;
        result = RegSetValueEx(
          hKey.value,
          'ProxyEnable'.toNativeUtf16(),
          0,
          REG_VALUE_TYPE.REG_DWORD,
          enableValue.cast(),
          sizeOf<DWORD>(),
        );
        calloc.free(enableValue);

        if (result != WIN32_ERROR.ERROR_SUCCESS) {
          print('❌ 设置 ProxyEnable 失败: $result');
          return false;
        }

        // 清空 ProxyServer
        final emptyValue = ''.toNativeUtf16();
        result = RegSetValueEx(
          hKey.value,
          'ProxyServer'.toNativeUtf16(),
          0,
          REG_VALUE_TYPE.REG_SZ,
          emptyValue.cast(),
          2, // 空字符串
        );
        calloc.free(emptyValue);

        // 通知系统代理设置已更改
        _notifyProxyChange();

        print('✅ 系统代理已清除');
        return true;
      } finally {
        RegCloseKey(hKey.value);
        calloc.free(hKey);
      }
    } catch (e) {
      print('❌ 清除系统代理失败: $e');
      return false;
    }
  }

  /// 获取当前系统代理状态
  static Future<ProxyStatus> getProxyStatus() async {
    if (!Platform.isWindows) {
      return ProxyStatus(enabled: false, server: '');
    }

    try {
      final hKey = calloc<HKEY>();
      var result = RegOpenKeyEx(
        HKEY_CURRENT_USER,
        _registryPath.toNativeUtf16(),
        0,
        REG_SAM_FLAGS.KEY_QUERY_VALUE,
        hKey,
      );

      if (result != WIN32_ERROR.ERROR_SUCCESS) {
        calloc.free(hKey);
        return ProxyStatus(enabled: false, server: '');
      }

      try {
        // 读取 ProxyEnable
        final enableValue = calloc<DWORD>();
        final enableSize = calloc<DWORD>();
        enableSize.value = sizeOf<DWORD>();

        result = RegQueryValueEx(
          hKey.value,
          'ProxyEnable'.toNativeUtf16(),
          nullptr,
          nullptr,
          enableValue.cast(),
          enableSize,
        );

        final enabled = result == WIN32_ERROR.ERROR_SUCCESS && enableValue.value == 1;
        calloc.free(enableValue);
        calloc.free(enableSize);

        if (!enabled) {
          return ProxyStatus(enabled: false, server: '');
        }

        // 读取 ProxyServer
        final serverBuffer = calloc<Uint16>(256);
        final serverSize = calloc<DWORD>();
        serverSize.value = 256 * 2;

        result = RegQueryValueEx(
          hKey.value,
          'ProxyServer'.toNativeUtf16(),
          nullptr,
          nullptr,
          serverBuffer.cast(),
          serverSize,
        );

        String server = '';
        if (result == WIN32_ERROR.ERROR_SUCCESS) {
          server = serverBuffer.cast<Utf16>().toDartString();
        }

        calloc.free(serverBuffer);
        calloc.free(serverSize);

        return ProxyStatus(enabled: enabled, server: server);
      } finally {
        RegCloseKey(hKey.value);
        calloc.free(hKey);
      }
    } catch (e) {
      print('❌ 获取代理状态失败: $e');
      return ProxyStatus(enabled: false, server: '');
    }
  }

  /// 通知系统代理设置已更改
  static void _notifyProxyChange() {
    try {
      // Windows 需要手动刷新Internet设置
      // 这里使用命令行方式通知系统
      Process.runSync('reg', [
        'add',
        r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
        '/v',
        'ProxySettingsPerUser',
        '/t',
        'REG_DWORD',
        '/d',
        '1',
        '/f'
      ]);

      print('✅ 已通知系统代理设置更改');
    } catch (e) {
      print('⚠️ 通知系统更改失败: $e');
    }
  }

  /// 检查系统代理是否指向指定地址
  static Future<bool> isProxySetTo(String host, int port) async {
    final status = await getProxyStatus();
    final expected = '$host:$port';
    return status.enabled && status.server == expected;
  }
}

/// 代理状态
class ProxyStatus {
  final bool enabled;
  final String server;

  ProxyStatus({required this.enabled, required this.server});

  @override
  String toString() => 'ProxyStatus(enabled: $enabled, server: $server)';
}

