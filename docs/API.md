# 御渊WAF API文档

版本: 1.0.0  
更新时间: 2025-11-18

## 概述

御渊WAF提供REST风格的HTTP API，用于管理和监控WAF运行状态。

## 认证

### API Token

所有API请求需要提供API Token进行认证（本地127.0.0.1除外）。

```bash
# 方式1: HTTP Header
curl -H "X-API-Token: your-token-here" http://localhost/api/stats

# 方式2: URL参数
curl http://localhost/api/stats?token=your-token-here
```

## 基础端点

### 健康检查

检查WAF是否正常运行。

```http
GET /api/health
```

**响应示例**：
```json
{
  "success": true,
  "status": "ok",
  "timestamp": 1700400000
}
```

---

## 统计API

### 获取所有统计

获取WAF的完整统计信息。

```http
GET /api/stats
```

**响应示例**：
```json
{
  "success": true,
  "data": {
    "attacks": {
      "sql_injection": 150,
      "xss": 80,
      "command_injection": 30,
      "path_traversal": 20,
      "file_inclusion": 10,
      "total": 290
    },
    "rate_limit": {
      "ip_blocked": 45,
      "uri_blocked": 12,
      "global_blocked": 5,
      "cc_detected": 8
    },
    "ip_filter": {
      "blacklist_count": 25,
      "whitelist_count": 10,
      "blocked": 120
    },
    "crawler": {
      "detected": 300,
      "good_bot": 50,
      "blocked": 250
    },
    "summary": {
      "total_requests": 10000,
      "total_blocked": 500,
      "total_challenges": 100,
      "uptime": 3600
    }
  },
  "message": "获取统计成功",
  "timestamp": 1700400000
}
```

### 获取QPS

获取当前的每秒请求数（QPS）。

```http
GET /api/stats/qps
```

**响应示例**：
```json
{
  "success": true,
  "data": {
    "qps": 125,
    "window": 60,
    "total": 7500
  },
  "message": "获取QPS成功",
  "timestamp": 1700400000
}
```

### 获取Top攻击IP

获取攻击次数最多的IP地址列表。

```http
GET /api/stats/top-ips?limit=10
```

**参数**：
- `limit` (可选): 返回数量，默认10

**响应示例**：
```json
{
  "success": true,
  "data": [
    {
      "ip": "1.2.3.4",
      "reason": "SQL注入攻击",
      "blocked_at": 1700400000
    },
    {
      "ip": "5.6.7.8",
      "reason": "频繁违反频率限制",
      "blocked_at": 1700399800
    }
  ],
  "message": "获取Top IP成功",
  "timestamp": 1700400000
}
```

### 获取攻击趋势

获取指定时间范围内的攻击趋势数据。

```http
GET /api/stats/trend?hours=24
```

**参数**：
- `hours` (可选): 时间范围（小时），默认24

**响应示例**：
```json
{
  "success": true,
  "data": [
    {
      "timestamp": 1700395200,
      "hour": "12:00",
      "attacks": 45
    },
    {
      "timestamp": 1700398800,
      "hour": "13:00",
      "attacks": 52
    }
  ],
  "message": "获取趋势成功",
  "timestamp": 1700400000
}
```

---

## IP黑名单管理

### 添加IP到黑名单

将指定IP添加到黑名单。

```http
POST /api/blacklist/add
Content-Type: application/json

{
  "ip": "1.2.3.4",
  "duration": 3600,
  "reason": "恶意攻击"
}
```

**参数**：
- `ip` (必需): IP地址
- `duration` (可选): 封禁时长（秒），默认3600
- `reason` (可选): 封禁原因

**响应示例**：
```json
{
  "success": true,
  "data": {},
  "message": "添加成功",
  "timestamp": 1700400000
}
```

### 从黑名单移除IP

从黑名单中移除指定IP。

```http
POST /api/blacklist/remove
Content-Type: application/json

{
  "ip": "1.2.3.4"
}
```

**响应示例**：
```json
{
  "success": true,
  "data": {},
  "message": "移除成功",
  "timestamp": 1700400000
}
```

### 检查IP状态

检查指定IP是否在黑名单中。

```http
GET /api/blacklist/check?ip=1.2.3.4
```

**响应示例**：
```json
{
  "success": true,
  "data": {
    "ip": "1.2.3.4",
    "in_blacklist": true,
    "reason": "恶意攻击"
  },
  "message": "查询成功",
  "timestamp": 1700400000
}
```

### 获取黑名单列表

获取当前黑名单中的所有IP。

```http
GET /api/blacklist/list?limit=100&offset=0
```

**参数**：
- `limit` (可选): 返回数量，默认100
- `offset` (可选): 偏移量，默认0

**响应示例**：
```json
{
  "success": true,
  "data": {
    "items": [
      {
        "ip": "1.2.3.4",
        "reason": "恶意攻击"
      }
    ],
    "total": 25
  },
  "message": "获取列表成功",
  "timestamp": 1700400000
}
```

---

## 频率限制管理

### 重置IP频率限制

重置指定IP的频率限制计数。

```http
POST /api/ratelimit/reset
Content-Type: application/json

{
  "ip": "1.2.3.4"
}
```

**响应示例**：
```json
{
  "success": true,
  "data": {},
  "message": "重置成功",
  "timestamp": 1700400000
}
```

### 获取IP频率统计

获取指定IP的当前频率统计信息。

```http
GET /api/ratelimit/stats?ip=1.2.3.4
```

**响应示例**：
```json
{
  "success": true,
  "data": {
    "ip": "1.2.3.4",
    "stats": {
      "tokens": 8,
      "cc_count": 150,
      "violations": 3
    }
  },
  "message": "获取统计成功",
  "timestamp": 1700400000
}
```

---

## 配置管理

### 获取配置

获取当前WAF配置。

```http
GET /api/config
```

**响应示例**：
```json
{
  "success": true,
  "data": {
    "mode": "protection",
    "ip_filter": {
      "enabled": true
    },
    "rate_limit": {
      "enabled": true,
      "per_ip": {
        "rate": 10,
        "burst": 20
      }
    }
  },
  "message": "获取配置成功",
  "timestamp": 1700400000
}
```

### 设置运行模式

更改WAF的运行模式。

```http
POST /api/config/mode
Content-Type: application/json

{
  "mode": "detection"
}
```

**参数**：
- `mode` (必需): 运行模式
  - `off`: 关闭WAF
  - `detection`: 检测模式（仅记录，不拦截）
  - `protection`: 防护模式（检测并拦截）

**响应示例**：
```json
{
  "success": true,
  "data": {},
  "message": "模式已更新为: detection",
  "timestamp": 1700400000
}
```

---

## 缓存管理

### 清理缓存

清理过期的缓存数据。

```http
POST /api/cache/flush
```

**响应示例**：
```json
{
  "success": true,
  "data": {},
  "message": "缓存已清理",
  "timestamp": 1700400000
}
```

### 获取缓存信息

获取缓存使用情况。

```http
GET /api/cache/info
```

**响应示例**：
```json
{
  "success": true,
  "data": {
    "cache": {
      "capacity": 104857600,
      "free_space": 52428800
    },
    "blacklist": {
      "capacity": 52428800,
      "free_space": 30000000
    },
    "stats": {
      "capacity": 104857600,
      "free_space": 80000000
    }
  },
  "message": "获取缓存信息成功",
  "timestamp": 1700400000
}
```

---

## 错误响应

所有API在出错时返回统一格式：

```json
{
  "success": false,
  "data": {},
  "message": "错误描述",
  "timestamp": 1700400000
}
```

**HTTP状态码**：
- `200`: 成功
- `400`: 请求参数错误
- `401`: 未授权
- `404`: 端点不存在
- `500`: 服务器内部错误

---

## 使用示例

### cURL

```bash
# 获取统计
curl http://localhost/api/stats

# 添加黑名单
curl -X POST http://localhost/api/blacklist/add \
  -H "Content-Type: application/json" \
  -d '{"ip":"1.2.3.4","reason":"测试"}'

# 查看Top攻击IP
curl http://localhost/api/stats/top-ips?limit=5
```

### Python

```python
import requests

# 获取统计
response = requests.get('http://localhost/api/stats')
data = response.json()
print(f"总攻击次数: {data['data']['attacks']['total']}")

# 添加黑名单
response = requests.post(
    'http://localhost/api/blacklist/add',
    json={'ip': '1.2.3.4', 'reason': '测试'}
)
print(response.json())
```

### JavaScript

```javascript
// 获取统计
fetch('http://localhost/api/stats')
  .then(res => res.json())
  .then(data => {
    console.log('总攻击次数:', data.data.attacks.total);
  });

// 添加黑名单
fetch('http://localhost/api/blacklist/add', {
  method: 'POST',
  headers: {'Content-Type': 'application/json'},
  body: JSON.stringify({ip: '1.2.3.4', reason: '测试'})
})
  .then(res => res.json())
  .then(data => console.log(data));
```

---

## 速率限制

API本身也受到速率限制保护：
- 单IP: 60次/分钟
- 全局: 1000次/分钟

超过限制将返回429状态码。

