import 'package:shared_preferences/shared_preferences.dart';

enum ProxyMode {
  bypassCN,
  global,
}

class ProxyModeService {
  static const String _key = 'proxy_mode';

  static Future<ProxyMode> getMode() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_key) ?? 'bypass_cn';
    return v == 'global' ? ProxyMode.global : ProxyMode.bypassCN;
  }

  static Future<void> setMode(ProxyMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode == ProxyMode.global ? 'global' : 'bypass_cn');
  }
}


