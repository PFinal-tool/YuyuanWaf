# 📚 御渊WAF 文档索引

## 快速导航

### 🚀 新手入门

| 文档 | 说明 | 推荐度 |
|------|------|--------|
| [README.md](README.md) | 项目介绍和特性概览 | ⭐⭐⭐⭐⭐ |
| [QUICKSTART.md](QUICKSTART.md) | 5分钟快速部署 | ⭐⭐⭐⭐⭐ |
| [INSTALL.md](INSTALL.md) | 详细安装指南 | ⭐⭐⭐⭐ |

### 📖 深入了解

| 文档 | 说明 | 推荐度 |
|------|------|--------|
| [ARCHITECTURE.md](ARCHITECTURE.md) | 系统架构设计 | ⭐⭐⭐⭐ |
| [docs/CONFIGURATION.md](docs/CONFIGURATION.md) | 配置详解 | ⭐⭐⭐⭐⭐ |
| [docs/API.md](docs/API.md) | API接口文档 | ⭐⭐⭐ |
| [docs/PERFORMANCE.md](docs/PERFORMANCE.md) | 性能测试指南 | ⭐⭐⭐ |
| [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | 故障排查 | ⭐⭐⭐⭐ |

### 🤝 参与贡献

| 文档 | 说明 | 推荐度 |
|------|------|--------|
| [CONTRIBUTING.md](CONTRIBUTING.md) | 贡献指南 | ⭐⭐⭐⭐⭐ |
| [CODE_OF_CONDUCT.md](.github/CODE_OF_CONDUCT.md) | 行为准则 | ⭐⭐⭐⭐ |
| [RELEASE.md](RELEASE.md) | 发布流程（维护者） | ⭐⭐⭐ |

### 📝 项目信息

| 文档 | 说明 |
|------|------|
| [CHANGELOG.md](CHANGELOG.md) | 完整变更历史 |
| [ROADMAP.md](ROADMAP.md) | 发展路线图 |
| [SECURITY.md](SECURITY.md) | 安全政策 |
| [LICENSE](LICENSE) | MIT许可证 |

---

## 📂 文档结构

```
YuyuanWaf/
├── README.md                    # 项目介绍 ⭐ 从这里开始
├── QUICKSTART.md                # 快速开始 ⭐ 5分钟部署
├── INSTALL.md                   # 安装指南
├── ARCHITECTURE.md              # 架构设计
├── CONTRIBUTING.md              # 贡献指南
├── CHANGELOG.md                 # 变更日志
├── SECURITY.md                  # 安全政策
├── ROADMAP.md                   # 发展路线图
├── RELEASE.md                   # 发布指南
├── LICENSE                      # 许可证
│
├── docs/                        # 详细文档
│   ├── CONFIGURATION.md         # 配置详解 ⭐ 必读
│   ├── API.md                   # API文档
│   ├── PERFORMANCE.md           # 性能测试
│   └── TROUBLESHOOTING.md       # 故障排查 ⭐ 遇到问题看这里
│
├── .github/                     # GitHub配置
│   ├── ISSUE_TEMPLATE/          # Issue模板
│   ├── PULL_REQUEST_TEMPLATE.md # PR模板
│   └── CODE_OF_CONDUCT.md       # 行为准则
│
└── tests/                       # 测试文档
    └── performance/README.md    # 性能测试说明
```

---

## 🎯 按场景查找文档

### 我想快速试用WAF
1. 阅读 [QUICKSTART.md](QUICKSTART.md)
2. 使用Docker快速部署
3. 查看 [docs/CONFIGURATION.md](docs/CONFIGURATION.md) 调整配置

### 我想深入了解WAF原理
1. 阅读 [ARCHITECTURE.md](ARCHITECTURE.md)
2. 查看源代码和注释
3. 阅读 [docs/CONFIGURATION.md](docs/CONFIGURATION.md) 了解各模块

### 我想贡献代码
1. 阅读 [CONTRIBUTING.md](CONTRIBUTING.md)
2. 查看 [ARCHITECTURE.md](ARCHITECTURE.md) 了解架构
3. 提交PR时遵循模板要求

### 我遇到了问题
1. 查看 [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)
2. 搜索现有 [Issues](https://github.com/yourusername/YuyuanWaf/issues)
3. 提交新Issue使用对应模板

### 我想做性能测试
1. 阅读 [docs/PERFORMANCE.md](docs/PERFORMANCE.md)
2. 运行 `tests/performance/run_all_tests.sh`
3. 查看测试报告

### 我想报告安全漏洞
1. 阅读 [SECURITY.md](SECURITY.md)
2. 通过邮件私密报告
3. 不要公开披露

---

## 💡 文档说明

### 核心文档（必读）

**README.md**
- 项目的门面，包含所有关键信息
- 新用户第一个应该阅读的文档

**QUICKSTART.md**
- 最快的入门方式
- 5分钟内完成部署

**INSTALL.md**
- 详细的安装步骤
- 适用于生产环境部署

**docs/CONFIGURATION.md**
- 配置参数详解
- 生产环境必读

### 参考文档

**ARCHITECTURE.md**
- 系统设计思路
- 模块架构说明
- 适合深入了解者

**docs/API.md**
- REST API接口说明
- 适合需要API集成的用户

**docs/PERFORMANCE.md**
- 性能测试方法
- 优化建议
- 适合性能调优

**docs/TROUBLESHOOTING.md**
- 常见问题解决方案
- 遇到问题必看

### 社区文档

**CONTRIBUTING.md**
- 如何贡献代码
- 代码规范
- 提交流程

**SECURITY.md**
- 安全漏洞报告流程
- 安全政策

**CHANGELOG.md**
- 完整的版本变更历史
- 升级前必看

**ROADMAP.md**
- 未来发展计划
- 了解项目方向

---

## 📞 获取帮助

- **文档问题**: 查看相应文档或提Issue
- **使用问题**: [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)
- **安全问题**: [SECURITY.md](SECURITY.md)
- **贡献问题**: [CONTRIBUTING.md](CONTRIBUTING.md)

---

**文档版本**: v1.0.0  
**最后更新**: 2025-11-18

