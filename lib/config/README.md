# API 配置和使用说明

## 📁 文件结构

```
lib/
├── config/
│   └── api_config.dart       # API配置文件
├── utils/
│   └── http_client.dart      # HTTP客户端封装
└── services/
    └── api_service.dart      # API服务层
```

## 🔧 配置说明

### 1. API网关地址配置

在 `lib/config/api_config.dart` 中已配置：

```dart
// 当前所有环境都指向生产环境
static String devBaseUrl = 'https://1.kscspeed.online/api/v1';
static String stagingBaseUrl = 'https://1.kscspeed.online/api/v1';
static String prodBaseUrl = 'https://1.kscspeed.online/api/v1';
```

### 2. 切换环境

```dart
// 设置为开发环境
ApiConfig.setEnvironment(Environment.development);

// 设置为测试环境
ApiConfig.setEnvironment(Environment.staging);

// 设置为生产环境（默认）
ApiConfig.setEnvironment(Environment.production);
```

### 3. 自定义网关地址

```dart
// 动态修改当前环境的API地址
ApiConfig.setCustomBaseUrl('https://your-custom-api.com/api/v1');
```

## 📝 使用示例

### 1. 用户登录

```dart
import 'package:demo2/services/api_service.dart';

// 创建API服务实例
final apiService = ApiService();

// 调用登录接口
final response = await apiService.login(
  '949684777@qq.com',
  '168168wwWW',
);

// 处理响应
if (response.success) {
  // 登录成功
  final token = response.data['token'];
  final authData = response.data['auth_data'];
  final isAdmin = response.data['is_admin'];
  
  print('登录成功！Token: $token');
  print('Message: ${response.message}');
  
  // token 已自动保存，后续请求会自动带上
} else {
  // 登录失败
  print('登录失败：${response.message}');
}
```

### 2. 获取用户信息

```dart
final response = await apiService.getUserInfo();

if (response.success) {
  final userData = response.data;
  print('用户信息：$userData');
}
```

### 3. 获取节点列表

```dart
final response = await apiService.getNodeList();

if (response.success) {
  final nodes = response.data;
  print('节点列表：$nodes');
}
```

### 4. 连接代理

```dart
final response = await apiService.connectProxy(
  'node_id_123',  // 节点ID
  'global',       // 代理模式
);

if (response.success) {
  print('代理连接成功');
}
```

### 5. 获取使用统计

```dart
final response = await apiService.getStatistics(
  page: 1,
  pageSize: 10,
);

if (response.success) {
  final statistics = response.data;
  print('统计数据：$statistics');
}
```

## 🔐 Token 管理

Token 会自动管理，无需手动处理：

- **登录成功**：自动保存 token 到本地
- **后续请求**：自动在请求头中添加 `Authorization: Bearer {token}`
- **登出**：调用 `apiService.logout()` 会自动清除 token
- **Token过期**：收到401响应时自动清除 token

## 📋 响应格式

所有API响应都遵循统一格式：

```dart
class ApiResponse {
  final bool success;        // 业务是否成功
  final int? statusCode;     // HTTP状态码
  final dynamic data;        // 响应数据
  final String? message;     // 提示消息
  final String? error;       // 错误信息
}
```

### 服务端标准响应格式

```json
{
  "status": "success",           // 或 "error"
  "message": "操作成功",
  "data": { ... },              // 实际数据
  "error": null
}
```

## ⚙️ 高级配置

### 1. 修改超时时间

在 `api_config.dart` 中：

```dart
static const int connectTimeout = 15000;   // 连接超时（毫秒）
static const int receiveTimeout = 15000;   // 接收超时（毫秒）
static const int sendTimeout = 15000;      // 发送超时（毫秒）
```

### 2. 启用/禁用日志

```dart
ApiConfig.enableLog = true;   // 启用日志
ApiConfig.enableLog = false;  // 禁用日志
```

### 3. 直接使用 HTTP 客户端

如果需要调用未封装的接口：

```dart
import 'package:demo2/utils/http_client.dart';

final httpClient = HttpClient();

// GET 请求
final response = await httpClient.get('/custom/path', params: {'key': 'value'});

// POST 请求
final response = await httpClient.post('/custom/path', data: {'key': 'value'});

// PUT 请求
final response = await httpClient.put('/custom/path', data: {'key': 'value'});

// DELETE 请求
final response = await httpClient.delete('/custom/path', params: {'id': '123'});
```

## 🚨 错误处理

```dart
final response = await apiService.login(email, password);

if (response.success) {
  // 成功处理
  print('成功：${response.message}');
} else {
  // 错误处理
  if (response.statusCode == 401) {
    print('未授权，请重新登录');
  } else if (response.statusCode == 404) {
    print('资源不存在');
  } else if (response.statusCode == 500) {
    print('服务器错误');
  } else {
    print('错误：${response.message}');
  }
}
```

## 📚 API 路径列表

所有接口路径都在 `api_config.dart` 中定义：

- **用户相关**
  - `/passport/auth/login` - 登录
  - `/passport/auth/register` - 注册
  - `/user/logout` - 登出
  - `/user/info` - 获取用户信息
  
- **节点相关**
  - `/node/list` - 节点列表
  - `/node/select` - 选择节点
  - `/node/ping` - 测试延迟
  
- **代理相关**
  - `/proxy/connect` - 连接代理
  - `/proxy/disconnect` - 断开代理
  - `/proxy/status` - 代理状态
  
- **统计相关**
  - `/statistics/usage` - 使用统计

根据实际后端接口调整这些路径。

