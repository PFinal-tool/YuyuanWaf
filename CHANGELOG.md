# 变更日志

本文档记录御渊WAF的所有重要变更。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/)，
版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

---

## [未发布]

### 计划功能
- 机器学习模型集成
- Web控制台
- 集群同步功能
- 更多第三方集成

---

## [1.0.0] - 2025-11-18

### 🎉 首个正式发布版本

这是御渊WAF的首个社区版本，提供企业级Web应用防火墙核心功能。

### ✨ 新增功能

#### 核心防护
- **SQL注入防护** - 支持80+种检测规则，覆盖Union、盲注、堆叠查询等
- **XSS防护** - 检测Script标签、事件处理器、JavaScript协议等
- **命令注入防护** - 防御Shell命令注入攻击
- **路径遍历防护** - 阻止目录遍历和敏感文件访问
- **文件包含防护** - 防止本地和远程文件包含

#### 访问控制
- **IP黑白名单** - 支持单IP和CIDR格式
- **国家/地区过滤** - 基于GeoIP的地理位置过滤
- **频率限制** - 令牌桶算法实现的速率限制
- **CC防护** - 防御CC攻击

#### 反爬虫
- **User-Agent检测** - 识别常见爬虫和安全扫描工具
- **行为分析** - 检测异常访问模式
- **验证码挑战** - 可选的人机验证

#### API和管理
- **RESTful API** - 完整的管理API
- **实时统计** - QPS、攻击统计、性能指标
- **配置热更新** - 无需重启即可更新配置

#### 日志和监控
- **详细日志** - JSON格式的结构化日志
- **攻击日志** - 专门的攻击事件记录
- **性能监控** - 请求延迟、缓存命中率等

### 📦 包含模块

```
lua/
├── waf.lua                 # WAF核心引擎
├── config.lua              # 配置管理
├── modules/                # 功能模块
│   ├── anti_crawler.lua
│   ├── geoip.lua
│   ├── ip_filter.lua
│   └── rate_limit.lua
├── rules/                  # 规则引擎
│   ├── sql_injection.lua
│   ├── xss.lua
│   ├── command_injection.lua
│   ├── path_traversal.lua
│   └── file_inclusion.lua
├── lib/                    # 工具库
│   ├── cache.lua
│   ├── string_utils.lua
│   └── ip_utils.lua
└── api/                    # API接口
    ├── router.lua
    ├── stats.lua
    └── management.lua
```

### 📚 文档

- **README.md** - 项目介绍和快速开始
- **QUICKSTART.md** - 5分钟快速部署指南
- **INSTALL.md** - 详细安装说明
- **docs/CONFIGURATION.md** - 配置指南
- **docs/API.md** - API文档
- **docs/PERFORMANCE.md** - 性能测试指南
- **docs/TROUBLESHOOTING.md** - 故障排查
- **ARCHITECTURE.md** - 架构设计文档

### 🧪 测试

- **单元测试** - SQL注入、XSS等规则测试
- **集成测试** - 完整WAF功能测试
- **性能测试** - 基准测试、压力测试工具
- **测试Payload** - 85+ SQL注入、93+ XSS、68+ 命令注入测试用例

### 🎨 拦截页面

- **默认拦截页** - 精美的HTML拦截页面
- **验证码页面** - 可选的人机验证
- **挑战页面** - JavaScript挑战

### 📊 性能指标

- **QPS**: 5000+ (单核，100并发)
- **延迟**: P95 < 25ms, P99 < 50ms
- **攻击检测**: < 5ms 额外开销
- **内存使用**: < 200MB (单worker)

### 🔧 系统要求

- **OpenResty**: >= 1.21.4.1
- **Lua**: 5.1 (LuaJIT)
- **操作系统**: Linux/macOS
- **内存**: 建议 >= 1GB
- **CPU**: 建议 >= 1核

### 🐳 Docker支持

- Docker镜像支持
- Docker Compose配置
- 一键部署

### 🌍 国际化

- 中文文档
- 英文文档(部分)
- 中文错误消息

---

## [0.9.0] - 2025-11-15

### 内部测试版本

- 核心功能开发完成
- 内部测试和优化

---

## [0.5.0] - 2025-11-01

### Alpha版本

- 基础WAF功能
- SQL注入和XSS检测
- 简单的配置系统

---

## [0.1.0] - 2025-10-01

### 项目启动

- 项目架构设计
- 技术栈选型
- 开发环境搭建

---

## 版本说明

### 语义化版本

- **主版本号(MAJOR)**: 不兼容的API变更
- **次版本号(MINOR)**: 向后兼容的功能性新增
- **修订号(PATCH)**: 向后兼容的问题修正

### 变更类型

- `Added` - 新增功能
- `Changed` - 现有功能变更
- `Deprecated` - 即将废弃的功能
- `Removed` - 已删除的功能
- `Fixed` - Bug修复
- `Security` - 安全相关

---

## 升级指南

### 从 0.x 到 1.0.0

由于这是首个正式版本，暂无升级路径。

### 未来版本

我们承诺：
- **次版本号更新**：向后兼容，可直接升级
- **主版本号更新**：可能包含破坏性变更，提供迁移指南

---

## 获取更新

### 稳定版本

```bash
# 克隆稳定分支
git clone -b main https://github.com/yourusername/YuyuanWaf.git

# 或下载发布包
wget https://github.com/yourusername/YuyuanWaf/releases/download/v1.0.0/yuyuanwaf-1.0.0.tar.gz
```

### 开发版本

```bash
# 克隆开发分支
git clone -b develop https://github.com/yourusername/YuyuanWaf.git
```

---

## 反馈和建议

如有问题或建议，欢迎：
- 提交 [Issue](https://github.com/yourusername/YuyuanWaf/issues)
- 加入 [讨论](https://github.com/yourusername/YuyuanWaf/discussions)
- 发送邮件至 feedback@yuyuanwaf.org

---

**感谢所有贡献者和用户的支持！** 🙏

[未发布]: https://github.com/yourusername/YuyuanWaf/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/yourusername/YuyuanWaf/releases/tag/v1.0.0
[0.9.0]: https://github.com/yourusername/YuyuanWaf/releases/tag/v0.9.0
[0.5.0]: https://github.com/yourusername/YuyuanWaf/releases/tag/v0.5.0
[0.1.0]: https://github.com/yourusername/YuyuanWaf/releases/tag/v0.1.0

