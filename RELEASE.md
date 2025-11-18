# 发布指南

本文档说明如何发布御渊WAF的新版本。

## 📋 发布前检查清单

### 1. 代码质量

- [ ] 所有单元测试通过
- [ ] 所有集成测试通过
- [ ] 性能测试达标
- [ ] 代码审查完成
- [ ] 没有已知的严重bug

### 2. 文档

- [ ] README.md更新
- [ ] CHANGELOG.md更新
- [ ] API文档更新
- [ ] 配置文档更新
- [ ] 示例配置更新

### 3. 版本信息

- [ ] VERSION文件更新
- [ ] lua/init.lua版本号更新
- [ ] docker镜像标签准备

### 4. 安全

- [ ] 安全扫描通过
- [ ] 依赖漏洞检查
- [ ] 敏感信息清理

---

## 📦 发布流程

### 步骤1: 准备发布分支

```bash
# 确保在最新的main分支
git checkout main
git pull origin main

# 创建发布分支
git checkout -b release/v1.0.0
```

### 步骤2: 更新版本号

```bash
# 更新VERSION文件
echo "1.0.0" > VERSION

# 更新lua/init.lua
vim lua/init.lua
# 修改: _VERSION = "1.0.0"

# 提交版本更新
git add VERSION lua/init.lua
git commit -m "chore: bump version to 1.0.0"
```

### 步骤3: 更新CHANGELOG

```bash
# 编辑CHANGELOG.md
vim CHANGELOG.md

# 添加新版本信息
## [1.0.0] - 2025-11-18

### Added
- 新功能1
- 新功能2

### Changed
- 变更1
- 变更2

### Fixed
- 修复1
- 修复2

# 提交更新
git add CHANGELOG.md
git commit -m "docs: update changelog for v1.0.0"
```

### 步骤4: 运行完整测试

```bash
# 运行所有测试
bash tests/run_tests.sh

# 运行性能测试
bash tests/performance/run_all_tests.sh

# 检查测试结果
```

### 步骤5: 创建标签

```bash
# 创建带注释的标签
git tag -a v1.0.0 -m "Release version 1.0.0

主要变更:
- 功能1
- 功能2
- 修复3

详见 CHANGELOG.md"

# 验证标签
git tag -v v1.0.0
```

### 步骤6: 推送到仓库

```bash
# 推送分支
git push origin release/v1.0.0

# 推送标签
git push origin v1.0.0
```

### 步骤7: 创建GitHub Release

1. 访问 https://github.com/yourusername/YuyuanWaf/releases/new
2. 选择标签: v1.0.0
3. 发布标题: `御渊WAF v1.0.0`
4. 发布说明:

```markdown
## 🎉 御渊WAF v1.0.0 正式发布

这是御渊WAF的首个正式版本！

### ✨ 主要特性

- SQL注入防护
- XSS防护
- 命令注入防护
- 路径遍历防护
- IP黑白名单
- 频率限制
- 反爬虫

### 📦 安装

\`\`\`bash
# 下载
wget https://github.com/yourusername/YuyuanWaf/archive/v1.0.0.tar.gz

# 解压
tar xzf v1.0.0.tar.gz

# 安装
cd YuyuanWaf-1.0.0
# 按照 INSTALL.md 说明安装
\`\`\`

### 🐳 Docker

\`\`\`bash
docker pull yourusername/yuyuanwaf:1.0.0
\`\`\`

### 📚 文档

- [快速开始](QUICKSTART.md)
- [安装指南](INSTALL.md)
- [配置指南](docs/CONFIGURATION.md)
- [完整变更日志](CHANGELOG.md)

### 🙏 致谢

感谢所有贡献者！

完整变更请查看 [CHANGELOG.md](CHANGELOG.md)
```

5. 上传资产文件（可选）:
   - yuyuanwaf-1.0.0.tar.gz
   - yuyuanwaf-1.0.0.zip
   - checksums.txt

6. 点击"Publish release"

### 步骤8: 合并到主分支

```bash
# 创建Pull Request
# 从 release/v1.0.0 到 main

# 审查并合并PR

# 删除发布分支
git branch -d release/v1.0.0
git push origin --delete release/v1.0.0
```

### 步骤9: 构建Docker镜像

```bash
# 构建镜像
docker build -t yourusername/yuyuanwaf:1.0.0 .
docker tag yourusername/yuyuanwaf:1.0.0 yourusername/yuyuanwaf:latest

# 推送到Docker Hub
docker push yourusername/yuyuanwaf:1.0.0
docker push yourusername/yuyuanwaf:latest
```

### 步骤10: 更新文档网站

```bash
# 如果有文档网站
# 更新版本
# 发布新文档
```

### 步骤11: 发布公告

- [ ] GitHub Discussions发布公告
- [ ] Twitter/微博发布
- [ ] 邮件列表通知
- [ ] 社区群组通知

---

## 🔢 版本号规范

遵循[语义化版本 2.0.0](https://semver.org/lang/zh-CN/)：

### 格式
```
主版本号.次版本号.修订号
```

### 规则

**主版本号(MAJOR)**：不兼容的API变更
```bash
# 示例: 1.0.0 -> 2.0.0
- 重大架构调整
- 破坏性API变更
- 移除废弃功能
```

**次版本号(MINOR)**：向后兼容的功能性新增
```bash
# 示例: 1.0.0 -> 1.1.0
- 新增功能模块
- 新增规则类型
- 新增API端点
```

**修订号(PATCH)**：向后兼容的问题修正
```bash
# 示例: 1.0.0 -> 1.0.1
- Bug修复
- 性能优化
- 文档修正
```

### 预发布版本

```bash
1.0.0-alpha.1    # Alpha版本
1.0.0-beta.1     # Beta版本
1.0.0-rc.1       # Release Candidate
```

---

## 📅 发布周期

### 稳定版本

- **主版本**: 每年1-2次
- **次版本**: 每季度1次
- **修订版**: 按需发布（bug修复）

### 预发布版本

- **Alpha**: 功能开发完成
- **Beta**: 内部测试完成
- **RC**: 公开测试完成

---

## 🔄 热修复发布

### 紧急修复流程

```bash
# 1. 从发布标签创建热修复分支
git checkout -b hotfix/v1.0.1 v1.0.0

# 2. 修复bug
# ... 修改代码 ...

# 3. 提交修复
git add .
git commit -m "fix: critical security issue"

# 4. 更新版本
echo "1.0.1" > VERSION

# 5. 更新CHANGELOG
vim CHANGELOG.md

# 6. 创建标签
git tag -a v1.0.1 -m "Hotfix release 1.0.1"

# 7. 推送
git push origin hotfix/v1.0.1
git push origin v1.0.1

# 8. 创建GitHub Release

# 9. 合并回main和develop
git checkout main
git merge hotfix/v1.0.1
git push origin main

git checkout develop
git merge hotfix/v1.0.1
git push origin develop

# 10. 删除hotfix分支
git branch -d hotfix/v1.0.1
```

---

## 📝 发布笔记模板

```markdown
## 御渊WAF vX.Y.Z 发布

**发布日期**: YYYY-MM-DD

### 🎯 本次发布重点

简要说明本次发布的主要内容

### ✨ 新功能

- 功能1: 描述
- 功能2: 描述

### 🐛 Bug修复

- #123: 修复XX问题
- #456: 修复YY问题

### ⚡️ 性能改进

- 提升XX性能 20%
- 优化YY模块

### 📚 文档更新

- 新增XX文档
- 更新YY指南

### ⚠️ 破坏性变更

如果有破坏性变更，详细说明：
- 变更内容
- 影响范围
- 迁移方法

### 📦 升级指南

从vA.B.C升级到vX.Y.Z:

\`\`\`bash
# 升级步骤
\`\`\`

### 🙏 贡献者

感谢本次发布的所有贡献者:
- @contributor1
- @contributor2

### 📊 统计信息

- XX个提交
- YY个功能
- ZZ个Bug修复
- NN位贡献者

### 🔗 相关链接

- [完整变更日志](CHANGELOG.md)
- [升级指南](docs/UPGRADE.md)
- [文档](README.md)
```

---

## ✅ 发布后检查

- [ ] GitHub Release创建成功
- [ ] Docker镜像已推送
- [ ] 文档网站已更新
- [ ] 公告已发布
- [ ] 下载链接可用
- [ ] CI/CD通过
- [ ] 社区通知完成

---

## 🚨 回滚计划

如果发布后发现严重问题：

```bash
# 1. 删除有问题的Release
# 在GitHub上删除Release

# 2. 删除标签
git tag -d vX.Y.Z
git push origin :refs/tags/vX.Y.Z

# 3. 发布公告
# 说明回滚原因和影响

# 4. 修复问题后重新发布
```

---

## 📞 联系方式

发布相关问题联系:
- 邮件: release@yuyuanwaf.org
- GitHub: @maintainer

---

**最后更新**: 2025-11-18

