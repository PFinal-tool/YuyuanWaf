# 御渊WAF 快速开始

## 🚀 5分钟快速体验

### 前提条件

确保你已经安装了 OpenResty:

```bash
# macOS
brew install openresty/brew/openresty

# 或者检查是否已安装
openresty -v
```

### 步骤1: 修改配置文件路径

```bash
cd /Users/pfinal/YuyuanWaf

# 如果你的项目不在这个路径，需要修改以下文件中的路径：
# 1. conf/waf.conf - 修改 lua_package_path 和 init_by_lua_block 中的路径
# 2. conf/nginx.conf.example - 修改所有 /Users/pfinal/YuyuanWaf/ 为你的实际路径
```

### 步骤2: 创建简单的测试后端

创建一个简单的测试服务器（可选，用于测试）：

```bash
# 创建测试HTML
mkdir -p /tmp/waf-test
cat > /tmp/waf-test/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head><title>测试页面</title></head>
<body>
    <h1>✅ WAF正常工作！</h1>
    <p>如果你能看到这个页面，说明请求通过了WAF验证。</p>
    <hr>
    <h2>测试攻击检测：</h2>
    <ul>
        <li><a href="?id=1' OR '1'='1">SQL注入测试</a></li>
        <li><a href="?name=<script>alert('xss')</script>">XSS测试</a></li>
        <li><a href="?file=../../etc/passwd">路径遍历测试</a></li>
    </ul>
</body>
</html>
EOF
```

### 步骤3: 配置Nginx

创建测试用的Nginx配置：

```bash
cat > /tmp/waf-nginx.conf << 'EOF'
worker_processes  1;
error_log  /tmp/waf-error.log  info;
pid        /tmp/waf-nginx.pid;

events {
    worker_connections  1024;
}

http {
    # 包含WAF配置
    lua_package_path "/Users/pfinal/YuyuanWaf/lua/?.lua;/Users/pfinal/YuyuanWaf/lua/lib/?.lua;/Users/pfinal/YuyuanWaf/lua/modules/?.lua;/Users/pfinal/YuyuanWaf/lua/rules/?.lua;;";
    
    lua_shared_dict waf_cache 10m;
    lua_shared_dict waf_blacklist 10m;
    lua_shared_dict waf_stats 10m;
    lua_shared_dict waf_rate_limit 10m;
    
    init_by_lua_block {
        waf = require "waf"
        waf.init("/Users/pfinal/YuyuanWaf/")
    }
    
    init_worker_by_lua_block {
        local init = require "init"
        init.init_worker()
    }
    
    server {
        listen       8080;
        server_name  localhost;
        
        access_log  /tmp/waf-access.log;
        
        # WAF访问控制
        access_by_lua_block {
            waf.run()
        }
        
        location / {
            root   /tmp/waf-test;
            index  index.html;
        }
        
        location = /health {
            return 200 "OK\n";
        }
    }
}
EOF
```

### 步骤4: 启动测试服务器

```bash
# 使用测试配置启动
openresty -p /tmp/waf-test -c /tmp/waf-nginx.conf

# 查看日志
tail -f /tmp/waf-error.log
```

如果看到类似以下日志，说明启动成功：
```
[WAF] 开始初始化御渊WAF...
[WAF] 御渊WAF初始化完成
[WAF] 版本: 1.0.0
```

### 步骤5: 测试WAF功能

打开浏览器或使用curl测试：

#### 1. 正常访问（应该通过）
```bash
curl http://localhost:8080/
# 应该返回测试页面
```

#### 2. SQL注入测试（应该被拦截）
```bash
curl "http://localhost:8080/?id=1' OR '1'='1"
# 应该返回拦截页面
```

#### 3. XSS测试（应该被拦截）
```bash
curl "http://localhost:8080/?name=<script>alert('xss')</script>"
# 应该返回拦截页面
```

#### 4. 路径遍历测试（应该被拦截）
```bash
curl "http://localhost:8080/?file=../../etc/passwd"
# 应该返回拦截页面
```

#### 5. 频率限制测试
```bash
# 快速发送多个请求
for i in {1..30}; do curl http://localhost:8080/ & done
# 部分请求应该被限流
```

#### 6. 爬虫检测测试
```bash
# 使用爬虫UA
curl -A "python-requests/2.28.0" http://localhost:8080/
# 应该触发JS挑战或被拦截
```

#### 7. 空UA测试
```bash
# 空User-Agent
curl -A "" http://localhost:8080/
# 应该被识别为可疑
```

### 步骤6: 查看日志

```bash
# 查看错误日志（包含WAF日志）
tail -f /tmp/waf-error.log | grep WAF

# 查看攻击日志
tail -f /tmp/waf-error.log | grep ATTACK
```

### 步骤7: 停止测试服务器

```bash
# 停止Nginx
openresty -p /tmp/waf-test -c /tmp/waf-nginx.conf -s stop
```

## 🔧 配置调整

### 修改WAF模式

编辑 `lua/config.lua`:

```lua
-- 检测模式（仅记录日志，不拦截）
mode = "detection",

-- 防护模式（检测并拦截）
mode = "protection",

-- 关闭WAF
mode = "off",
```

### 调整频率限制

```lua
rate_limit = {
    per_ip = {
        rate = 100,   -- 改为每秒100次
        burst = 200,
    },
}
```

### 添加IP白名单

编辑 `rules/ip_whitelist.txt`:

```
127.0.0.1
192.168.1.0/24
```

### 配置国家黑名单

编辑 `rules/country_blacklist.txt`:

```
KP  # 朝鲜
IR  # 伊朗
```

注意：需要先下载GeoIP数据库才能使用此功能。

## 📊 查看统计

当前版本可以通过日志查看统计信息。未来版本将提供Web界面和API。

```bash
# 统计攻击次数
grep "ATTACK" /tmp/waf-error.log | wc -l

# 统计SQL注入攻击
grep "SQL注入" /tmp/waf-error.log | wc -l

# 统计爬虫拦截
grep "crawler" /tmp/waf-error.log | wc -l
```

## 🎓 下一步

1. **阅读完整文档**
   - [架构设计](ARCHITECTURE.md)
   - [安装指南](INSTALL.md)
   - [项目总结](PROJECT_SUMMARY.md)

2. **生产环境部署**
   - 下载GeoIP数据库
   - 配置Redis（可选）
   - 设置监控告警
   - 建立白名单

3. **性能优化**
   - 调整共享内存大小
   - 优化缓存配置
   - 启用Redis缓存

4. **自定义规则**
   - 编辑 `lua/rules/custom_rules.lua`
   - 添加业务特定的检测规则

## ❓ 常见问题

### Q: 启动失败，提示找不到模块？
A: 检查 `lua_package_path` 配置是否正确，路径是否存在。

### Q: WAF没有生效？
A: 
1. 确认在 server 块中添加了 `access_by_lua_block`
2. 检查 WAF 模式是否为 `off`
3. 查看错误日志获取详细信息

### Q: 误拦截了正常请求？
A: 
1. 将IP添加到白名单
2. 调整检测阈值
3. 使用 `detection` 模式观察

### Q: 如何验证GeoIP功能？
A: 
1. 确保下载了GeoIP数据库文件
2. 检查数据库路径配置
3. 查看日志中的GeoIP相关信息

## 💡 提示

- 首次使用建议用 `detection` 模式
- 逐步建立白名单后切换到 `protection` 模式
- 定期查看日志，优化规则
- 注意性能监控

## 🆘 获取帮助

- GitHub Issues: https://github.com/yourusername/YuyuanWaf/issues
- 文档: [README.md](README.md)

---

**御渊WAF** - 5分钟快速体验 Web 应用安全防护 🛡️

