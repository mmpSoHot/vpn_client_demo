import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

/// Geo 规则文件下载器
/// 用于下载 geosite 和 geoip 规则文件
class GeoRulesDownloader {
  // 规则文件的 GitHub 仓库地址
  static const String _baseUrl = 'https://github.com/SagerNet/sing-geosite/releases/latest/download';
  static const String _geoipUrl = 'https://github.com/SagerNet/sing-geoip/releases/latest/download';
  
  /// 获取规则文件存储目录
  static String getRulesDirectory() {
    if (Platform.isWindows) {
      final homeDir = Platform.environment['USERPROFILE'] ?? 'C:\\Users\\Default';
      return '$homeDir\\.vpn_client_demo\\rules';
    } else if (Platform.isMacOS || Platform.isLinux) {
      final homeDir = Platform.environment['HOME'] ?? '/tmp';
      return '$homeDir/.vpn_client_demo/rules';
    } else if (Platform.isAndroid) {
      return '/data/data/com.example.vpn_client_demo/files/rules';
    } else if (Platform.isIOS) {
      return '/var/mobile/Containers/Data/Application/vpn_client_demo/Documents/rules';
    }
    return './rules';
  }
  
  /// 检查规则文件是否存在
  static Future<Map<String, bool>> checkRulesExist() async {
    final rulesDir = getRulesDirectory();
    
    return {
      'geosite-cn': await File('$rulesDir/geosite-cn.srs').exists(),
      'geosite-private': await File('$rulesDir/geosite-private.srs').exists(),
      'geoip-cn': await File('$rulesDir/geoip-cn.srs').exists(),
    };
  }
  
  /// 下载单个规则文件
  static Future<bool> downloadRule(String ruleName, {Function(double)? onProgress}) async {
    try {
      final rulesDir = getRulesDirectory();
      
      // 确保目录存在
      final dir = Directory(rulesDir);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      
      // 确定下载 URL
      String downloadUrl;
      if (ruleName.startsWith('geosite-')) {
        downloadUrl = '$_baseUrl/$ruleName.srs';
      } else if (ruleName.startsWith('geoip-')) {
        downloadUrl = '$_geoipUrl/$ruleName.srs';
      } else {
        throw Exception('未知的规则文件类型: $ruleName');
      }
      
      print('📥 开始下载规则文件: $ruleName');
      print('   URL: $downloadUrl');
      
      // 下载文件
      final response = await http.get(Uri.parse(downloadUrl));
      
      if (response.statusCode == 200) {
        final filePath = '$rulesDir/$ruleName.srs';
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        
        print('✅ 规则文件下载成功: $ruleName');
        print('   路径: $filePath');
        print('   大小: ${(response.bodyBytes.length / 1024).toStringAsFixed(2)} KB');
        
        return true;
      } else {
        print('❌ 规则文件下载失败: $ruleName (HTTP ${response.statusCode})');
        return false;
      }
    } catch (e) {
      print('❌ 规则文件下载出错: $ruleName - $e');
      return false;
    }
  }
  
  /// 下载所有必需的规则文件
  static Future<Map<String, bool>> downloadAllRules({Function(String, double)? onProgress}) async {
    final rules = ['geosite-cn', 'geosite-private', 'geoip-cn'];
    final results = <String, bool>{};
    
    print('🚀 开始下载规则文件...');
    
    for (final rule in rules) {
      results[rule] = await downloadRule(
        rule,
        onProgress: (progress) => onProgress?.call(rule, progress),
      );
      
      // 稍微延迟一下，避免请求过快
      await Future.delayed(const Duration(milliseconds: 500));
    }
    
    final successCount = results.values.where((v) => v).length;
    print('✅ 规则文件下载完成: $successCount/${rules.length} 成功');
    
    return results;
  }
  
  /// 删除所有规则文件
  static Future<void> deleteAllRules() async {
    try {
      final rulesDir = getRulesDirectory();
      final dir = Directory(rulesDir);
      
      if (dir.existsSync()) {
        await dir.delete(recursive: true);
        print('✅ 已删除所有规则文件');
      }
    } catch (e) {
      print('❌ 删除规则文件失败: $e');
    }
  }
  
  /// 获取规则文件信息
  static Future<Map<String, Map<String, dynamic>>> getRulesInfo() async {
    final rulesDir = getRulesDirectory();
    final rules = ['geosite-cn', 'geosite-private', 'geoip-cn'];
    final info = <String, Map<String, dynamic>>{};
    
    for (final rule in rules) {
      final filePath = '$rulesDir/$rule.srs';
      final file = File(filePath);
      
      if (await file.exists()) {
        final stat = await file.stat();
        info[rule] = {
          'exists': true,
          'size': stat.size,
          'modified': stat.modified,
          'path': filePath,
        };
      } else {
        info[rule] = {
          'exists': false,
          'size': 0,
          'modified': null,
          'path': filePath,
        };
      }
    }
    
    return info;
  }
}

