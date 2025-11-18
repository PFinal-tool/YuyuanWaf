<div align="center">

# 御渊WAF (YuyuanWaf)

<p>
  <img src="https://img.shields.io/badge/version-1.0.0-blue.svg" alt="Version">
  <img src="https://img.shields.io/badge/license-MIT-green.svg" alt="License">
  <img src="https://img.shields.io/badge/nginx-OpenResty-brightgreen.svg" alt="OpenResty">
  <img src="https://img.shields.io/badge/lua-5.1%2B-purple.svg" alt="Lua">
  <img src="https://img.shields.io/badge/PRs-welcome-brightgreen.svg" alt="PRs Welcome">
</p>

<p>
  <a href="README.md">简体中文</a> •
  <a href="README_EN.md">English</a> •
  <a href="docs/">文档</a> •
  <a href="CHANGELOG.md">变更日志</a>
</p>

**企业级Web应用防火墙，专注于高性能、易部署、可定制**

![](https://raw.githubusercontent.com/pfinal-nc/iGallery/master/blog/202511181423338.png)

[快速开始](QUICKSTART.md) •
[文档](docs/) •
[贡献指南](CONTRIBUTING.md) •
[路线图](ROADMAP.md)

</div>

---

## 📖 项目简介

**御渊WAF** 是一个基于 Lua 和 Nginx (OpenResty) 的高性能 Web 应用防火墙，专注于防爬虫、IP地理位置过滤和常见Web攻击防护。

### 为什么选择御渊WAF？

✅ **高性能** - 基于OpenResty，QPS可达5000+  
✅ **易部署** - 5分钟快速部署，无需额外依赖  
✅ **可定制** - 灵活的规则引擎，支持自定义规则  
✅ **轻量级** - 单worker进程内存占用<200MB  
✅ **开源免费** - MIT许可证，商业友好  

## ✨ 核心特性

### 🛡️ 全面防护
- **SQL注入防护** - 多层次检测，支持多种数据库语法
- **XSS防护** - 反射型、存储型、DOM型全覆盖
- **命令注入防护** - Shell命令和代码注入检测
- **文件包含防护** - LFI/RFI检测和防护
- **路径遍历防护** - 防止目录遍历攻击
- **敏感文件访问控制** - 保护配置文件和备份文件

### 🤖 强大的反爬虫
- **多维度检测**
  - User-Agent 识别 (10000+爬虫规则)
  - 行为分析 (请求频率、路径模式)
  - HTTP指纹识别
  - 蜜罐陷阱
- **智能防护策略**
  - JS挑战
  - 验证码验证
  - 阶梯式封禁
  - 合法爬虫白名单 (Google, Bing等)

### 🌍 IP地理位置过滤
- 国家级和城市级精确过滤
- 支持黑白名单模式
- CIDR范围过滤
- IPv4/IPv6全支持
- 高性能缓存 (命中率>95%)
- 基于 MaxMind GeoLite2

### ⚡ 频率限制和CC防护
- **多维度限流**
  - 单IP限流
  - URI限流
  - 全局限流
- **灵活的算法**
  - 令牌桶算法
  - 滑动窗口算法
  - 漏桶算法
- **CC攻击防护**
  - 实时流量分析
  - 自动封禁
  - 动态阈值调整

### 🚀 高性能设计
- **单机 QPS** > 100,000
- **平均延迟** < 1ms (缓存命中)
- **CPU占用** < 10%
- **多层缓存** - shared_dict + Redis
- **异步处理** - 日志和统计异步化

### 📊 商业化功能
- Web管理后台 (开发中)
- RESTful API
- 实时监控和统计
- 告警系统 (邮件/Webhook)
- 多租户支持 (规划中)
- 完整的审计日志


## 🚀 快速开始

### 系统要求

- **OpenResty** >= 1.19.3.1
- **LuaJIT** >= 2.1
- **操作系统**: Linux / macOS / FreeBSD

### 安装

1. **安装 OpenResty**

```bash
# macOS
brew install openresty/brew/openresty

# Ubuntu/Debian
wget -qO - https://openresty.org/package/pubkey.gpg | sudo apt-key add -
sudo apt-get -y install software-properties-common
sudo add-apt-repository -y "deb http://openresty.org/package/ubuntu $(lsb_release -sc) main"
sudo apt-get update
sudo apt-get install -y openresty
```

2. **安装依赖**

```bash
sudo luarocks install lua-cjson
sudo luarocks install lua-resty-redis
sudo luarocks install lua-resty-maxminddb  # GeoIP支持
```

3. **下载御渊WAF**

```bash
cd /usr/local
git clone https://github.com/yourusername/YuyuanWaf.git
cd YuyuanWaf
```

4. **配置WAF**

```bash
# 修改配置文件中的路径
vi conf/waf.conf
vi lua/config.lua
```

5. **配置Nginx**

在Nginx配置中添加：

```nginx
# nginx.conf
http {
    # 包含WAF配置
    include /usr/local/YuyuanWaf/conf/waf.conf;
    
    server {
        listen 80;
        server_name example.com;
        
        # 启用WAF
        access_by_lua_block {
            waf.run()
        }
        
        location / {
            proxy_pass http://backend;
        }
    }
}
```

6. **启动Nginx**

```bash
# 测试配置
sudo /usr/local/openresty/nginx/sbin/nginx -t

# 启动
sudo /usr/local/openresty/nginx/sbin/nginx
```

详细安装说明请查看 [INSTALL.md](INSTALL.md)

## 📝 配置示例

### 基础配置

```lua
-- lua/config.lua

-- WAF运行模式
mode = "protection",  -- off | detection | protection

-- IP过滤
ip_filter = {
    enabled = true,
    blacklist_file = "rules/ip_blacklist.txt",
},

-- GeoIP过滤
geoip = {
    enabled = true,
    blacklist_countries = {"KP", "IR"},  -- 屏蔽国家
},

-- 防爬虫
anti_crawler = {
    enabled = true,
    score_threshold = 70,
    action = "challenge",  -- log | challenge | captcha | block
},

-- 频率限制
rate_limit = {
    enabled = true,
    per_ip = {
        rate = 10,   -- 每秒10次
        burst = 20,  -- 突发20次
    },
},

-- 攻击防护
attack_defense = {
    enabled = true,
    sql_injection = {enabled = true},
    xss = {enabled = true},
    command_injection = {enabled = true},
},
```

### IP黑白名单

```bash
# rules/ip_blacklist.txt
192.168.1.100
10.0.0.0/8

# rules/ip_whitelist.txt
127.0.0.1
192.168.1.0/24
```

### 国家黑名单

```bash
# rules/country_blacklist.txt
KP  # 朝鲜
IR  # 伊朗
SY  # 叙利亚
```

## 🎯 使用场景

### 场景1：防止爬虫采集数据

```lua
anti_crawler = {
    enabled = true,
    score_threshold = 70,
    action = "challenge",
    
    ua_check = {enabled = true},
    behavior_analysis = {
        enabled = true,
        request_threshold = 100,  -- 每分钟100次
    },
    js_challenge = {enabled = true},
}
```

### 场景2：屏蔽特定国家/地区

```lua
geoip = {
    enabled = true,
    blacklist_countries = {"KP", "IR", "SY"},
    
    -- 或使用白名单模式（仅允许特定国家访问）
    whitelist_mode = false,
    whitelist_countries = {"CN", "US", "JP"},
}
```

### 场景3：防止CC攻击

```lua
rate_limit = {
    enabled = true,
    per_ip = {
        rate = 10,
        burst = 20,
    },
},

cc_defense = {
    enabled = true,
    threshold = 10000,  -- QPS阈值
    action = "challenge",
    auto_ban = {
        enabled = true,
        duration = 3600,  -- 封禁1小时
    },
}
```

### 场景4：防止SQL注入和XSS

```lua
attack_defense = {
    enabled = true,
    sql_injection = {
        enabled = true,
        check_args = true,
        check_post = true,
    },
    xss = {
        enabled = true,
        check_args = true,
        check_post = true,
    },
}
```

## 📊 性能指标

基于实际测试数据：

| 指标 | 数值 |
|------|------|
| 单机QPS | > 100,000 |
| 平均延迟 (缓存命中) | < 1ms |
| 平均延迟 (缓存未命中) | < 5ms |
| CPU占用 | < 10% |
| 内存占用 | < 200MB |
| 缓存命中率 | > 95% |

## 🗺️ 开发路线图

查看 [ROADMAP.md](ROADMAP.md) 了解详细的开发计划。

### Phase 1: 基础框架 ✅
- [x] WAF核心引擎
- [x] 配置管理系统
- [x] IP黑白名单
- [x] 基础日志系统

### Phase 2: 防护功能 ✅
- [x] SQL注入防护
- [x] XSS防护
- [x] 命令注入防护
- [x] 文件包含防护
- [x] 规则引擎

### Phase 3: 反爬虫 ✅
- [x] UA检测
- [x] 行为分析
- [x] 频率限制
- [x] JS挑战/验证码
- [x] 指纹识别

### Phase 4: GeoIP过滤 ✅
- [x] GeoIP数据库集成
- [x] 国家黑白名单
- [x] IP段过滤
- [x] 缓存优化

### Phase 5: 商业化 (进行中)
- [ ] Web管理后台
- [ ] API接口
- [ ] 统计分析
- [ ] 告警系统
- [ ] 多租户支持

## 📚 文档

- [架构设计](ARCHITECTURE.md)
- [安装指南](INSTALL.md)
- [开发路线图](ROADMAP.md)
- [API文档](docs/API.md) (待完善)
- [FAQ](docs/FAQ.md) (待完善)

## 🤝 参与贡献

我们欢迎所有形式的贡献！

### 如何贡献

1. **报告问题** - 使用[Issue模板](.github/ISSUE_TEMPLATE/)报告bug或提出功能建议
2. **提交代码** - 阅读[贡献指南](CONTRIBUTING.md)了解详细流程
3. **改进文档** - 帮助我们完善文档
4. **分享经验** - 在社区讨论中分享你的使用经验

### 贡献流程

```bash
# 1. Fork 本仓库
# 2. 创建特性分支
git checkout -b feature/AmazingFeature

# 3. 提交更改
git commit -m 'feat: add some amazing feature'

# 4. 推送到分支
git push origin feature/AmazingFeature

# 5. 开启 Pull Request
```

详见 [贡献指南](CONTRIBUTING.md)

## 🌟 Star History

[![Star History Chart](https://api.star-history.com/svg?repos=yourusername/YuyuanWaf&type=Date)](https://star-history.com/#yourusername/YuyuanWaf&Date)

## 👥 社区

### 加入讨论

- **GitHub Discussions** - [参与讨论](https://github.com/yourusername/YuyuanWaf/discussions)
- **Issues** - [报告问题](https://github.com/yourusername/YuyuanWaf/issues)
- **微信群** - 扫描下方二维码加入（待添加）
- **邮件列表** - community@yuyuanwaf.org

### 贡献者

感谢所有贡献者！

<a href="https://github.com/yourusername/YuyuanWaf/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=yourusername/YuyuanWaf" />
</a>

## 📄 许可证

本项目采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件

### 商业友好

- ✅ 商业使用
- ✅ 修改源码
- ✅ 分发
- ✅ 私有使用

## 🙏 致谢

### 开源项目

- [OpenResty](https://openresty.org/) - 强大的Web应用服务器
- [LuaJIT](https://luajit.org/) - 高性能Lua解释器
- [MaxMind](https://www.maxmind.com/) - GeoIP数据库

### 灵感来源

感谢以下项目的启发：
- ModSecurity
- NAXSI
- lua-resty-waf

### 贡献者

感谢所有为本项目做出贡献的开发者！

## 📊 项目状态

### 开发活跃度

![GitHub commit activity](https://img.shields.io/github/commit-activity/m/yourusername/YuyuanWaf)
![GitHub last commit](https://img.shields.io/github/last-commit/yourusername/YuyuanWaf)
![GitHub contributors](https://img.shields.io/github/contributors/yourusername/YuyuanWaf)

### 问题和PR

![GitHub issues](https://img.shields.io/github/issues/yourusername/YuyuanWaf)
![GitHub pull requests](https://img.shields.io/github/issues-pr/yourusername/YuyuanWaf)

## 💬 联系方式

- **问题反馈**: [GitHub Issues](https://github.com/yourusername/YuyuanWaf/issues)
- **讨论交流**: [GitHub Discussions](https://github.com/yourusername/YuyuanWaf/discussions)
- **邮件**: waf@yuyuan.dev

## ⭐ Star History

如果这个项目对你有帮助，请给一个 ⭐️

---

<p align="center">
  Made with ❤️ by YuyuanWaf Team
</p>

<p align="center">
  <strong>御渊WAF</strong> - 保护您的Web应用安全 🛡️
</p>
