# 御渊WAF 故障排查指南

版本: 1.0.0  
更新时间: 2025-11-18

## 常见问题

### 1. WAF无法启动

#### 症状
- Nginx启动失败
- 错误日志显示Lua相关错误

#### 排查步骤

**1.1 检查OpenResty是否安装**
```bash
openresty -v
# 或
nginx -V | grep openresty
```

**1.2 检查Lua模块路径**
```bash
# 查看配置
cat conf/waf.conf | grep lua_package_path

# 确认文件存在
ls -la lua/waf.lua
```

**1.3 查看错误日志**
```bash
tail -f /var/log/nginx/error.log
# 或 Docker环境
docker logs <container-name> 2>&1 | tail -50
```

#### 常见错误及解决方案

**错误**: `module 'waf' not found`
```bash
# 解决：检查lua_package_path配置
lua_package_path "/path/to/YuyuanWaf/lua/?.lua;;";
```

**错误**: `attempt to index global 'waf' (a nil value)`
```bash
# 解决：确认waf.conf在http块中正确包含
http {
    include /path/to/YuyuanWaf/conf/waf.conf;
    # ...
}
```

**错误**: `shared dict not found: waf_cache`
```bash
# 解决：添加共享内存配置
lua_shared_dict waf_cache 100m;
lua_shared_dict waf_blacklist 50m;
lua_shared_dict waf_stats 100m;
lua_shared_dict waf_rate_limit 50m;
```

---

### 2. 位运算错误

#### 症状
```
lua/lib/ip_utils.lua:90: unexpected symbol near '<'
```

#### 原因
使用了Lua 5.3+的位运算符，但OpenResty使用的是LuaJIT (Lua 5.1)。

#### 解决方案
确保使用了最新版本的代码，已修复为使用`bit`库：
```lua
-- 错误写法（Lua 5.3+）
local mask = 0xFFFFFFFF << (32 - prefix)

-- 正确写法（LuaJIT）
local bit = require "bit"
local mask = bit.lshift(0xFFFFFFFF, 32 - prefix)
```

---

### 3. 正常请求被误拦截

#### 症状
- 合法用户访问被拦截
- 返回403 Forbidden

#### 排查步骤

**3.1 检查WAF模式**
```bash
# 查看当前模式
grep 'mode =' lua/config.lua

# 临时切换到detection模式（仅记录不拦截）
curl -X POST http://localhost/api/config/mode \
  -H "Content-Type: application/json" \
  -d '{"mode":"detection"}'
```

**3.2 查看拦截日志**
```bash
# 查看攻击日志
tail -f logs/attack.log

# 在Docker中
docker exec <container> tail -f /usr/local/openresty/nginx/logs/attack.log
```

**3.3 添加白名单**
```lua
-- lua/config.lua
whitelist = {
    ips = {
        "x.x.x.x",  -- 添加被误拦截的IP
    },
    uris = {
        "^/your/path$",  -- 添加被误拦截的URI
    }
}
```

**3.4 使用API添加白名单**
```bash
# 临时添加IP白名单
curl -X POST http://localhost/api/blacklist/remove \
  -H "Content-Type: application/json" \
  -d '{"ip":"x.x.x.x"}'
```

#### 常见误报场景

**场景1：正常SQL查询字符串**
```bash
# 被拦截: /search?q=select * from products
# 解决：URI白名单或参数名白名单
```

**场景2：合法爬虫被拦截**
```bash
# 检查：确认爬虫在good_bot_ua.json中
# 解决：添加到合法爬虫列表
```

**场景3：内部监控工具**
```bash
# 解决：添加监控工具IP到白名单
whitelist.ips = {"monitor.internal.ip"}
```

---

### 4. 性能问题

#### 症状
- 网站响应变慢
- CPU使用率高
- 内存占用高

#### 排查步骤

**4.1 检查共享内存使用**
```bash
curl http://localhost/api/cache/info
```

**4.2 检查规则数量**
```bash
# 统计规则文件大小
wc -l rules/*.txt

# 检查JSON规则文件
cat rules/crawler_ua.json | jq '.categories | to_entries | length'
```

**4.3 分析慢查询**
```nginx
# 添加性能日志
log_by_lua_block {
    local time = ngx.var.request_time
    if tonumber(time) > 0.1 then
        ngx.log(ngx.WARN, "Slow request: ", ngx.var.uri, " time: ", time)
    end
}
```

#### 优化建议

**优化1：调整缓存大小**
```nginx
# 增加共享内存
lua_shared_dict waf_cache 200m;  # 原来100m
```

**优化2：减少检查项**
```lua
-- 关闭不必要的检查
attack_defense.sql_injection.check_cookie = false
attack_defense.xss.check_post = false  -- 如果不需要
```

**优化3：使用Redis**
```lua
-- 多节点部署时使用Redis
redis.enabled = true
redis.host = "redis-server"
rate_limit.backend = "redis"
```

**优化4：优化正则表达式**
```lua
-- 使用compiled regex
local re = require "ngx.re"
local compiled = re.compile("pattern", "jo")
```

---

### 5. 频率限制问题

#### 症状
- 用户频繁被限流
- QPS统计不准确

#### 排查步骤

**5.1 检查当前限流配置**
```bash
curl http://localhost/api/config | jq '.data.rate_limit'
```

**5.2 查看IP频率统计**
```bash
curl "http://localhost/api/ratelimit/stats?ip=x.x.x.x"
```

**5.3 重置频率限制**
```bash
curl -X POST http://localhost/api/ratelimit/reset \
  -H "Content-Type: application/json" \
  -d '{"ip":"x.x.x.x"}'
```

#### 调整建议

**场景1：API服务器**
```lua
rate_limit.per_ip.rate = 100  -- 提高到100 req/s
rate_limit.per_ip.burst = 200
```

**场景2：低流量网站**
```lua
rate_limit.per_ip.rate = 5  -- 降低到5 req/s
```

**场景3：突发流量**
```lua
rate_limit.per_ip.burst = 100  -- 增大突发容量
```

---

### 6. GeoIP功能异常

#### 症状
```
[GeoIP] lua-resty-maxminddb未安装，GeoIP功能将受限
```

#### 解决方案

**方案1：安装lua-resty-maxminddb**
```bash
# 在容器内
docker exec -it <container> sh
apk add --no-cache gcc musl-dev make perl
luarocks install lua-resty-maxminddb
```

**方案2：禁用GeoIP**
```lua
-- lua/config.lua
geoip.enabled = false
```

**方案3：下载GeoIP数据库**
```bash
# 需要MaxMind账号
cd data/geoip/
wget https://download.maxmind.com/...
```

---

### 7. 日志问题

#### 症状
- 日志文件不存在
- 日志没有写入
- 日志格式错误

#### 排查步骤

**7.1 检查日志目录权限**
```bash
ls -la logs/
# 确保Nginx worker进程有写权限
chmod 755 logs/
```

**7.2 检查日志配置**
```lua
-- lua/config.lua
logging = {
    enabled = true,
    access_log = "logs/access.log",  -- 确认路径正确
}
```

**7.3 手动测试日志写入**
```bash
# 进入容器
docker exec -it <container> sh
cd /usr/local/openresty/nginx/
touch logs/test.log
# 如果失败，说明权限问题
```

---

### 8. Docker环境问题

#### 问题1：目录挂载错误

**症状**：文件不存在或无法访问

**解决**：
```yaml
# docker-compose.yml
volumes:
  # 确保路径正确
  - /host/path/YuyuanWaf:/var/www/html/YuyuanWaf:ro
```

**验证**：
```bash
docker exec <container> ls -la /var/www/html/YuyuanWaf/lua/waf.lua
```

#### 问题2：用户权限错误

**症状**：
```
nginx: [emerg] getpwnam("nginx") failed
```

**解决**：
```nginx
# OpenResty Alpine镜像使用nobody用户
user nobody;  # 不是 nginx
```

#### 问题3：容器内路径不匹配

**检查**：
```bash
# 进入容器
docker exec -it <container> sh

# 检查实际路径
ls /var/www/html/YuyuanWaf/
ls /usr/local/YuyuanWaf/  # 可能在这里

# 更新waf.conf中的路径
```

---

### 9. API无法访问

#### 症状
- 404 Not Found
- API端点不响应

#### 排查步骤

**9.1 检查Nginx配置**
```nginx
# 确认有API location配置
location /api/ {
    access_by_lua_block {
        waf.run()  -- 可能需要跳过WAF检查
    }
    
    content_by_lua_block {
        local router = require "api.router"
        router.route()
    }
}
```

**9.2 测试API端点**
```bash
# 健康检查
curl http://localhost/api/health

# 获取API文档
curl http://localhost/api/

# 如果失败，检查日志
docker logs <container> 2>&1 | grep api
```

**9.3 检查认证**
```bash
# 本地访问不需要token
curl http://127.0.0.1/api/stats

# 远程访问需要token
curl -H "X-API-Token: your-token" http://server-ip/api/stats
```

---

### 10. 规则更新问题

#### 更新规则后不生效

**原因**：Nginx缓存了Lua模块

**解决**：
```bash
# 重载Nginx
nginx -s reload

# 或重启
docker restart <container>

# 清理缓存
curl -X POST http://localhost/api/cache/flush
```

---

## 调试技巧

### 1. 启用调试日志

```lua
-- lua/config.lua
logging.level = "DEBUG"
logging.log_normal_request = true
```

### 2. 添加调试输出

```lua
-- 在代码中添加
ngx.log(ngx.WARN, "[DEBUG] Variable value: ", tostring(value))
```

### 3. 使用测试payload

```bash
# 测试SQL注入规则
curl "http://localhost/?id=1' OR '1'='1"

# 测试XSS规则
curl "http://localhost/?name=<script>alert(1)</script>"

# 查看是否被拦截
```

### 4. 实时监控日志

```bash
# 实时查看攻击日志
tail -f logs/attack.log | jq '.'

# 在Docker中
docker logs -f <container> 2>&1 | grep WAF
```

### 5. 使用API监控

```bash
# 实时监控QPS
watch -n 1 'curl -s http://localhost/api/stats/qps | jq'

# 监控统计
watch -n 5 'curl -s http://localhost/api/stats | jq .data.attacks'
```

---

## 性能基准测试

### 使用ab (Apache Bench)

```bash
# 无WAF
ab -n 10000 -c 100 http://localhost/

# 有WAF
ab -n 10000 -c 100 http://localhost/
```

### 使用wrk

```bash
wrk -t 4 -c 100 -d 30s http://localhost/
```

### 预期性能

- **正常请求**: < 1ms延迟
- **攻击检测**: < 5ms延迟
- **QPS**: 10000+ (单核)

---

## 获取帮助

### 日志分析

收集以下信息：
1. Nginx错误日志
2. WAF攻击日志
3. 系统资源使用情况
4. 配置文件

### 问题报告

包含以下内容：
1. 问题描述和复现步骤
2. 错误日志（最近50行）
3. 环境信息（OS、OpenResty版本）
4. 配置文件（隐藏敏感信息）

### 联系方式

- GitHub Issues: https://github.com/your-repo/issues
- 邮件: support@example.com
- 文档: https://docs.example.com

---

## 附录：常用命令

```bash
# Nginx操作
nginx -t                    # 测试配置
nginx -s reload             # 重载配置
nginx -s stop               # 停止
nginx -V                    # 查看版本和编译选项

# Docker操作
docker ps                   # 查看容器
docker logs <container>     # 查看日志
docker exec -it <container> sh  # 进入容器
docker restart <container>  # 重启容器

# 日志查看
tail -f logs/attack.log     # 实时查看攻击日志
grep "SQL" logs/attack.log  # 搜索SQL注入日志
cat logs/access.log | jq    # 格式化JSON日志

# API测试
curl http://localhost/api/health              # 健康检查
curl http://localhost/api/stats               # 获取统计
curl http://localhost/api/blacklist/list      # 查看黑名单

# 测试
cd tests && ./run_tests.sh  # 运行所有测试
lua unit/test_sql_injection.lua  # 单个测试
```

