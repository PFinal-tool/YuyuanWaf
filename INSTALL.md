# 御渊WAF 安装部署指南

## 📋 系统要求

### 必需组件
- **OpenResty**: >= 1.19.3.1 (或 Nginx + ngx_lua 模块)
- **LuaJIT**: >= 2.1
- **操作系统**: Linux / macOS / FreeBSD

### 可选组件
- **Redis**: >= 5.0 (用于分布式部署)
- **MaxMind GeoLite2**: 地理位置数据库 (用于GeoIP功能)

## 🚀 快速安装

### 1. 安装 OpenResty

#### macOS
```bash
brew install openresty/brew/openresty
```

#### Ubuntu/Debian
```bash
wget -qO - https://openresty.org/package/pubkey.gpg | sudo apt-key add -
sudo apt-get -y install software-properties-common
sudo add-apt-repository -y "deb http://openresty.org/package/ubuntu $(lsb_release -sc) main"
sudo apt-get update
sudo apt-get install -y openresty
```

#### CentOS/RHEL
```bash
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://openresty.org/package/centos/openresty.repo
sudo yum install -y openresty
```

### 2. 安装依赖库

```bash
# 使用 LuaRocks 安装
sudo luarocks install lua-cjson
sudo luarocks install lua-resty-redis

# GeoIP支持 (可选)
sudo luarocks install lua-resty-maxminddb
```

### 3. 下载御渊WAF

```bash
cd /usr/local
git clone https://github.com/yourusername/YuyuanWaf.git
cd YuyuanWaf
```

### 4. 配置WAF

编辑配置文件：

```bash
# 1. 修改waf.conf中的路径
vi conf/waf.conf
# 将所有 /Users/pfinal/YuyuanWaf/ 替换为你的实际路径

# 2. 根据需要修改config.lua
vi lua/config.lua
```

### 5. 下载GeoIP数据库 (可选)

```bash
cd data/geoip/

# 下载GeoLite2数据库 (需要注册MaxMind账号)
# 访问: https://dev.maxmind.com/geoip/geolite2-free-geolocation-data

# 或使用wget下载 (需要license key)
wget "https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-Country&license_key=YOUR_LICENSE_KEY&suffix=tar.gz" -O GeoLite2-Country.tar.gz
tar -xzf GeoLite2-Country.tar.gz
mv GeoLite2-Country_*/GeoLite2-Country.mmdb .
```

### 6. 配置Nginx

#### 方式1：修改现有Nginx配置

```bash
vi /usr/local/openresty/nginx/conf/nginx.conf
```

在 `http` 块中添加：
```nginx
include /usr/local/YuyuanWaf/conf/waf.conf;
```

在 `server` 块中添加：
```nginx
access_by_lua_block {
    waf.run()
}
```

#### 方式2：使用示例配置

```bash
cp conf/nginx.conf.example /usr/local/openresty/nginx/conf/nginx.conf
# 编辑配置文件，修改路径和后端服务器地址
vi /usr/local/openresty/nginx/conf/nginx.conf
```

### 7. 测试配置

```bash
# 测试Nginx配置
sudo /usr/local/openresty/nginx/sbin/nginx -t

# 如果配置正确，启动Nginx
sudo /usr/local/openresty/nginx/sbin/nginx
```

### 8. 验证安装

```bash
# 查看Nginx错误日志
tail -f /usr/local/openresty/nginx/logs/error.log

# 应该看到类似以下的日志：
# [WAF] 开始初始化御渊WAF...
# [WAF] 御渊WAF初始化完成
# [WAF] 版本: 1.0.0
```

访问你的网站，WAF应该已经生效。

## 📝 配置说明

### 基础配置

编辑 `lua/config.lua`：

```lua
-- WAF运行模式
mode = "protection",  -- off | detection | protection

-- 白名单
whitelist = {
    ips = {"127.0.0.1"},
    uris = {"^/health$"},
},

-- IP黑白名单文件
ip_filter = {
    enabled = true,
    blacklist_file = "rules/ip_blacklist.txt",
},

-- GeoIP过滤
geoip = {
    enabled = true,
    blacklist_countries = {"KP", "IR"},  -- 黑名单国家
},

-- 防爬虫
anti_crawler = {
    enabled = true,
    score_threshold = 70,
    action = "challenge",
},

-- 频率限制
rate_limit = {
    enabled = true,
    per_ip = {
        rate = 10,  -- 每秒10次
        burst = 20,
    },
},
```

### IP黑白名单

编辑规则文件：

```bash
# IP黑名单
vi rules/ip_blacklist.txt
# 添加IP或CIDR，每行一个
# 192.168.1.100
# 10.0.0.0/8

# IP白名单
vi rules/ip_whitelist.txt
```

### 国家黑名单

```bash
vi rules/country_blacklist.txt
# 添加ISO国家代码，每行一个
# KP  # 朝鲜
# IR  # 伊朗
```

## 🔄 管理命令

### 启动/停止/重启

```bash
# 启动
sudo /usr/local/openresty/nginx/sbin/nginx

# 停止
sudo /usr/local/openresty/nginx/sbin/nginx -s stop

# 优雅停止
sudo /usr/local/openresty/nginx/sbin/nginx -s quit

# 重新加载配置
sudo /usr/local/openresty/nginx/sbin/nginx -s reload

# 重新打开日志文件
sudo /usr/local/openresty/nginx/sbin/nginx -s reopen
```

### 查看日志

```bash
# 错误日志
tail -f /usr/local/openresty/nginx/logs/error.log

# 访问日志
tail -f /usr/local/openresty/nginx/logs/access.log

# WAF攻击日志
tail -f /usr/local/YuyuanWaf/logs/attack.log
```

## 🐳 Docker部署 (可选)

```bash
# 待开发
```

## 🔧 性能优化

### 1. 调整Worker进程数

```nginx
worker_processes auto;  # 自动根据CPU核心数设置
```

### 2. 调整共享内存大小

```nginx
lua_shared_dict waf_cache 200m;        # 增加缓存
lua_shared_dict waf_blacklist 100m;
```

### 3. 启用缓存

确保在 `config.lua` 中启用缓存：

```lua
performance = {
    cache = {
        ip_ttl = 3600,
        rule_ttl = 300,
        geoip_ttl = 3600,
    },
}
```

## 📊 监控

### 查看WAF统计

通过Nginx日志查看WAF运行状态：

```bash
grep "\[WAF\]" /usr/local/openresty/nginx/logs/error.log
```

### 集成Prometheus (可选)

待开发...

## 🆘 故障排查

### 问题1：Nginx启动失败

**解决方案：**
1. 检查配置文件路径是否正确
2. 检查Lua包路径是否正确
3. 查看错误日志获取详细信息

### 问题2：WAF未生效

**解决方案：**
1. 确认在server块中添加了 `access_by_lua_block`
2. 检查WAF模式是否为 `off`
3. 检查是否在白名单中

### 问题3：GeoIP功能不工作

**解决方案：**
1. 确认已安装 `lua-resty-maxminddb`
2. 检查GeoIP数据库文件是否存在
3. 查看错误日志中的GeoIP相关信息

### 问题4：性能问题

**解决方案：**
1. 增加共享内存大小
2. 调整缓存TTL
3. 考虑使用Redis作为缓存后端
4. 禁用不需要的检测模块

## 📚 进阶配置

### 集成Redis

编辑 `lua/config.lua`：

```lua
redis = {
    enabled = true,
    host = "127.0.0.1",
    port = 6379,
    password = "",
    database = 0,
}
```

### 自定义规则

编辑 `lua/rules/custom_rules.lua` 添加自定义检测规则。

### API管理 (待开发)

待开发...

## 📖 更多文档

- [架构设计](ARCHITECTURE.md)
- [开发路线图](ROADMAP.md)
- [README](README.md)

## 💬 技术支持

- GitHub Issues: https://github.com/yourusername/YuyuanWaf/issues
- 文档: https://waf.yuyuan.dev

---

**御渊WAF** - 保护您的Web应用安全 🛡️

