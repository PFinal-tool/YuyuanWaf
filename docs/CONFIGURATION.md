# 御渊WAF 配置指南

版本: 1.0.0  
更新时间: 2025-11-18

## 配置文件位置

- **主配置**: `lua/config.lua`
- **Nginx配置**: `conf/waf.conf`
- **规则文件**: `rules/` 目录

---

## 基础配置

### 运行模式

```lua
-- lua/config.lua
mode = "protection"  -- off | detection | protection
```

**模式说明**：
- `off`: 关闭WAF，所有请求正常通过
- `detection`: 检测模式，记录攻击但不拦截
- `protection`: 防护模式，检测并拦截攻击

### WAF路径

```lua
waf_path = "/usr/local/YuyuanWaf/"  -- WAF根目录
```

### 代理设置

```lua
trust_proxy = true  -- 是否信任X-Forwarded-For等代理头
```

### POST数据检查

```lua
check_post_data = true  -- 是否检查POST请求体
```

---

## 白名单配置

### IP白名单

```lua
whitelist = {
    ips = {
        "127.0.0.1",      -- 本地回环
        "::1",            -- IPv6本地
        "192.168.1.0/24", -- CIDR格式
        "10.0.0.100",     -- 单个IP
    }
}
```

### URI白名单

```lua
whitelist = {
    uris = {
        "^/health$",        -- 健康检查
        "^/api/public/",    -- 公开API
        "^/static/",        -- 静态资源
    }
}
```

### User-Agent白名单

```lua
whitelist = {
    user_agents = {
        "Googlebot",
        "Bingbot",
        "监控工具名称",
    }
}
```

---

## IP过滤配置

### 基础设置

```lua
ip_filter = {
    enabled = true,
    
    -- 黑名单文件
    blacklist_file = "rules/ip_blacklist.txt",
    
    -- 白名单文件
    whitelist_file = "rules/ip_whitelist.txt",
    
    -- 缓存时间（秒）
    cache_ttl = 3600,
}
```

### 黑名单文件格式

```text
# rules/ip_blacklist.txt
# 每行一个IP或CIDR

1.2.3.4
5.6.7.8
10.0.0.0/8
192.168.1.100
```

---

## GeoIP地理位置过滤

### 基础配置

```lua
geoip = {
    enabled = true,
    
    -- GeoIP数据库路径
    database_path = "data/geoip/GeoLite2-Country.mmdb",
    
    -- 国家黑名单（ISO 3166-1 alpha-2代码）
    blacklist_countries = {
        "KP",  -- 朝鲜
        "IR",  -- 伊朗
    },
    
    -- 国家白名单（仅允许这些国家访问）
    whitelist_countries = {
        "CN",  -- 中国
        "US",  -- 美国
    },
    
    -- 白名单模式开关
    whitelist_mode = false,  -- true=白名单模式, false=黑名单模式
    
    -- 缓存时间（秒）
    cache_ttl = 3600,
}
```

### 获取GeoIP数据库

```bash
# 下载GeoLite2数据库（需要注册MaxMind账号）
cd data/geoip/
wget https://download.maxmind.com/app/geoip_download?...
```

---

## 频率限制配置

### 全局限制

```lua
rate_limit = {
    enabled = true,
    
    global = {
        enabled = true,
        rate = 1000,      -- 每秒1000次
        burst = 2000,     -- 突发2000次
    }
}
```

### 单IP限制

```lua
rate_limit = {
    per_ip = {
        enabled = true,
        rate = 10,        -- 每秒10次
        burst = 20,       -- 突发20次
        window = 1,       -- 时间窗口（秒）
    }
}
```

### 单URI限制

```lua
rate_limit = {
    per_uri = {
        enabled = true,
        rate = 100,       -- 每秒100次
        burst = 200,
    }
}
```

### 限流动作

```lua
rate_limit = {
    action = "block",  -- block | challenge | captcha
}
```

### 存储后端

```lua
rate_limit = {
    backend = "shared_dict",  -- shared_dict | redis
}
```

---

## CC攻击防护

### 基础配置

```lua
cc_defense = {
    enabled = true,
    
    -- QPS阈值
    threshold = 10000,
    
    -- 检测窗口（秒）
    window = 10,
    
    -- 动作
    action = "challenge",  -- challenge | captcha | block
    
    -- 自动封禁
    auto_ban = {
        enabled = true,
        duration = 3600,  -- 封禁时长（秒）
    }
}
```

---

## 防爬虫配置

### User-Agent检测

```lua
anti_crawler = {
    enabled = true,
    
    ua_check = {
        enabled = true,
        crawler_ua_file = "rules/crawler_ua.json",
        good_bot_file = "rules/good_bot_ua.json",
    }
}
```

### 行为分析

```lua
anti_crawler = {
    behavior_analysis = {
        enabled = true,
        request_threshold = 100,      -- 每分钟请求数阈值
        session_max_requests = 1000,  -- 单会话最大请求数
        session_timeout = 1800,       -- 会话超时（秒）
    }
}
```

### 指纹识别

```lua
anti_crawler = {
    fingerprint = {
        enabled = true,
        check_headers = true,   -- 检查HTTP头
        check_empty_ua = true,  -- 检测空UA
    }
}
```

### JS挑战

```lua
anti_crawler = {
    js_challenge = {
        enabled = true,
        valid_time = 300,  -- 挑战有效期（秒）
        difficulty = 2,    -- 难度 (1-5)
    }
}
```

### 验证码

```lua
anti_crawler = {
    captcha = {
        enabled = false,
        threshold = 80,  -- 触发阈值（爬虫评分）
    }
}
```

### 爬虫评分

```lua
anti_crawler = {
    score_threshold = 70,  -- 超过此分数视为爬虫
    action = "challenge",  -- log | challenge | captcha | block
}
```

---

## 攻击防护配置

### SQL注入防护

```lua
attack_defense = {
    enabled = true,
    
    sql_injection = {
        enabled = true,
        check_args = true,     -- 检查URL参数
        check_post = true,     -- 检查POST参数
        check_cookie = false,  -- 检查Cookie
    }
}
```

### XSS防护

```lua
attack_defense = {
    xss = {
        enabled = true,
        check_args = true,
        check_post = true,
    }
}
```

### 命令注入防护

```lua
attack_defense = {
    command_injection = {
        enabled = true,
        check_args = true,
        check_post = true,
    }
}
```

### 文件包含防护

```lua
attack_defense = {
    file_inclusion = {
        enabled = true,
        check_args = true,
    }
}
```

### 路径遍历防护

```lua
attack_defense = {
    path_traversal = {
        enabled = true,
        check_uri = true,
        check_args = true,
    }
}
```

### 敏感文件访问防护

```lua
attack_defense = {
    sensitive_file = {
        enabled = true,
        extensions = {
            ".bak", ".sql", ".zip", 
            ".tar", ".gz", ".log"
        },
    }
}
```

---

## Redis配置（可选）

### 基础设置

```lua
redis = {
    enabled = false,
    host = "127.0.0.1",
    port = 6379,
    password = "",
    database = 0,
    timeout = 1000,  -- 毫秒
    pool_size = 100,
    keepalive_timeout = 60000,  -- 毫秒
}
```

### 使用Redis

当启用Redis后，频率限制和缓存数据可以存储在Redis中，支持多个WAF节点共享数据。

---

## 日志配置

### 基础设置

```lua
logging = {
    enabled = true,
    
    -- 日志级别
    level = "INFO",  -- DEBUG | INFO | WARN | ERROR | CRITICAL
    
    -- 日志格式
    format = "json",  -- json | text
    
    -- 日志文件路径
    access_log = "logs/access.log",
    attack_log = "logs/attack.log",
    error_log = "logs/error.log",
    
    -- 是否记录正常请求
    log_normal_request = false,
}
```

---

## 告警配置

### 邮件告警

```lua
alert = {
    enabled = true,
    
    email = {
        enabled = true,
        smtp_server = "smtp.example.com",
        smtp_port = 587,
        from = "waf@example.com",
        to = {"admin@example.com"},
    }
}
```

### Webhook告警（钉钉/企业微信）

```lua
alert = {
    webhook = {
        enabled = true,
        url = "https://oapi.dingtalk.com/robot/send?access_token=xxx",
        token = "",
    }
}
```

### 告警阈值

```lua
alert = {
    threshold = {
        attack_per_minute = 100,  -- 每分钟攻击次数
        ban_per_minute = 10,      -- 每分钟封禁IP数
    }
}
```

---

## 性能配置

### 共享内存大小

```nginx
# conf/waf.conf
lua_shared_dict waf_cache 100m;
lua_shared_dict waf_blacklist 50m;
lua_shared_dict waf_stats 100m;
lua_shared_dict waf_rate_limit 50m;
```

### 缓存TTL

```lua
performance = {
    cache = {
        ip_ttl = 3600,      -- IP查询缓存（秒）
        rule_ttl = 300,     -- 规则缓存（秒）
        geoip_ttl = 3600,   -- GeoIP缓存（秒）
    }
}
```

---

## 配置示例

### 高安全模式

```lua
mode = "protection"

-- 启用所有防护
ip_filter.enabled = true
geoip.enabled = true
rate_limit.enabled = true
anti_crawler.enabled = true
attack_defense.enabled = true
cc_defense.enabled = true

-- 严格的频率限制
rate_limit.per_ip.rate = 5
rate_limit.per_ip.burst = 10

-- 严格的爬虫检测
anti_crawler.score_threshold = 50
anti_crawler.action = "block"
```

### 开发模式

```lua
mode = "detection"  -- 仅检测，不拦截

-- 宽松的白名单
whitelist.ips = {
    "192.168.0.0/16",
    "10.0.0.0/8"
}

-- 日志详细
logging.level = "DEBUG"
logging.log_normal_request = true
```

### 生产模式

```lua
mode = "protection"

-- 合理的频率限制
rate_limit.per_ip.rate = 10
rate_limit.per_ip.burst = 20

-- 启用告警
alert.enabled = true
alert.email.enabled = true

-- 启用Redis（集群部署）
redis.enabled = true
redis.host = "redis-cluster.example.com"
```

---

## 配置重载

修改配置后需要重载Nginx：

```bash
# 测试配置
nginx -t

# 重载配置
nginx -s reload

# 或使用 Docker
docker exec <container> nginx -s reload
```

---

## 配置验证

使用提供的测试工具验证配置：

```bash
# 运行测试
cd tests
./run_tests.sh

# 测试特定规则
lua unit/test_sql_injection.lua
```

---

## 常见配置场景

### API服务器

```lua
-- 高频率限制
rate_limit.per_ip.rate = 100

-- 宽松的爬虫检测
anti_crawler.enabled = false

-- 重点防护
attack_defense.enabled = true
```

### 静态网站

```lua
-- 严格的爬虫检测
anti_crawler.enabled = true
anti_crawler.score_threshold = 60

-- 较低的频率限制
rate_limit.per_ip.rate = 5
```

### 内部系统

```lua
-- IP白名单模式
whitelist.ips = {
    "10.0.0.0/8",
    "172.16.0.0/12"
}

-- 关闭公网防护
geoip.whitelist_mode = true
geoip.whitelist_countries = {"CN"}
```

---

## 最佳实践

1. **渐进式启用**：先用detection模式观察，再切换到protection
2. **白名单优先**：将信任的IP/URI添加到白名单
3. **监控告警**：配置告警及时发现问题
4. **定期更新**：更新爬虫特征库和规则
5. **性能调优**：根据实际情况调整缓存大小
6. **备份配置**：修改前备份配置文件
7. **日志分析**：定期分析日志优化规则

