# 贡献指南

感谢您对御渊WAF项目的关注！我们欢迎所有形式的贡献。

## 📋 目录

- [行为准则](#行为准则)
- [如何贡献](#如何贡献)
- [开发流程](#开发流程)
- [代码规范](#代码规范)
- [提交规范](#提交规范)
- [测试要求](#测试要求)

---

## 行为准则

### 我们的承诺

为了营造一个开放和友好的环境，我们作为贡献者和维护者承诺：无论年龄、体型、残疾、民族、性别认同和表达、经验水平、国籍、个人形象、种族、宗教或性取向如何，参与我们的项目和社区的每个人都不会受到骚扰。

### 我们的标准

积极行为包括：
- 使用友好和包容的语言
- 尊重不同的观点和经验
- 优雅地接受建设性批评
- 关注对社区最有利的事情
- 对其他社区成员表示同情

不可接受的行为包括：
- 使用性化的语言或图像
- 挑衅、侮辱或贬损性评论，以及人身攻击
- 公开或私下骚扰
- 未经明确许可发布他人的私人信息
- 其他在专业环境中可能被认为不适当的行为

---

## 如何贡献

### 报告问题

如果您发现了bug或有功能建议：

1. **搜索现有Issue** - 确保问题未被报告
2. **创建新Issue** - 使用提供的模板
3. **提供详细信息** - 包括：
   - 问题描述
   - 复现步骤
   - 预期行为
   - 实际行为
   - 环境信息（OS、版本等）
   - 日志和截图

### 提交代码

1. **Fork项目**
   ```bash
   # 点击GitHub页面的Fork按钮
   ```

2. **克隆仓库**
   ```bash
   git clone https://github.com/your-username/YuyuanWaf.git
   cd YuyuanWaf
   ```

3. **创建分支**
   ```bash
   git checkout -b feature/your-feature-name
   # 或
   git checkout -b fix/your-bug-fix
   ```

4. **开发和测试**
   ```bash
   # 进行开发
   # 运行测试
   bash tests/run_tests.sh
   ```

5. **提交更改**
   ```bash
   git add .
   git commit -m "feat: add new feature"
   ```

6. **推送到GitHub**
   ```bash
   git push origin feature/your-feature-name
   ```

7. **创建Pull Request**
   - 访问GitHub仓库
   - 点击"New Pull Request"
   - 填写PR模板
   - 等待审查

---

## 开发流程

### 环境搭建

1. **安装依赖**
   ```bash
   # OpenResty
   brew install openresty  # macOS
   # 或
   apt-get install openresty  # Ubuntu
   ```

2. **配置开发环境**
   ```bash
   # 复制配置文件
   cp conf/nginx.conf.example conf/nginx.conf
   
   # 修改为开发配置
   vim conf/nginx.conf
   ```

3. **启动服务**
   ```bash
   # 使用Docker（推荐）
   docker-compose up -d
   
   # 或直接启动
   openresty -p /path/to/YuyuanWaf
   ```

### 开发工作流

1. **同步主仓库**
   ```bash
   git remote add upstream https://github.com/original/YuyuanWaf.git
   git fetch upstream
   git merge upstream/main
   ```

2. **创建功能分支**
   ```bash
   git checkout -b feature/new-rule
   ```

3. **编写代码**
   - 遵循代码规范
   - 添加注释
   - 编写测试

4. **运行测试**
   ```bash
   # 单元测试
   bash tests/run_tests.sh
   
   # 性能测试
   bash tests/performance/run_all_tests.sh
   ```

5. **提交代码**
   ```bash
   git add .
   git commit -m "feat(rules): add new SQL injection rule"
   ```

---

## 代码规范

### Lua代码规范

```lua
-- 1. 使用2空格缩进
local function example()
  local value = "test"
  return value
end

-- 2. 函数命名：使用下划线分隔
local function check_sql_injection(str)
  -- ...
end

-- 3. 变量命名：使用下划线分隔
local user_input = ngx.var.arg_id
local is_valid = true

-- 4. 常量：使用大写
local MAX_RETRY = 3
local DEFAULT_TIMEOUT = 30

-- 5. 模块结构
local _M = {}

-- 私有函数
local function private_helper()
  -- ...
end

-- 公共函数
function _M.public_method()
  -- ...
end

return _M
```

### 注释规范

```lua
-- ============================================================================
-- 模块说明
-- ============================================================================

--- 检查SQL注入
-- @param str string 待检查的字符串
-- @return boolean 是否包含SQL注入
-- @return string|nil 匹配的规则
function _M.check_sqli(str)
  -- 实现逻辑
  return false
end
```

### Nginx配置规范

```nginx
# 使用4空格缩进
http {
    # 配置项按字母排序
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;
    
    # 相关配置分组
    lua_package_path "...";
    lua_shared_dict waf_cache 100m;
    
    # 添加注释说明
    server {
        listen 80;
        server_name example.com;
        
        # WAF检查
        access_by_lua_block {
            -- ...
        }
    }
}
```

---

## 提交规范

使用 [Conventional Commits](https://www.conventionalcommits.org/) 规范：

### 提交类型

- `feat`: 新功能
- `fix`: Bug修复
- `docs`: 文档更新
- `style`: 代码格式调整
- `refactor`: 重构
- `perf`: 性能优化
- `test`: 测试相关
- `chore`: 构建/工具相关

### 提交格式

```
<type>(<scope>): <subject>

<body>

<footer>
```

### 示例

```bash
# 新功能
git commit -m "feat(rules): add XSS detection for SVG tags"

# Bug修复
git commit -m "fix(rate-limit): correct token bucket calculation"

# 文档更新
git commit -m "docs(readme): update installation guide"

# 性能优化
git commit -m "perf(cache): improve cache hit rate by 20%"

# 破坏性变更
git commit -m "feat(api): change config API endpoint

BREAKING CHANGE: /api/config moved to /api/v1/config"
```

---

## 测试要求

### 单元测试

所有新功能必须包含单元测试：

```lua
-- tests/unit/test_new_feature.lua
local new_feature = require "new_feature"

describe("新功能测试", function()
    it("应该正确检测攻击", function()
        local result = new_feature.check("attack payload")
        assert.is_true(result)
    end)
    
    it("不应误报正常请求", function()
        local result = new_feature.check("normal input")
        assert.is_false(result)
    end)
end)
```

### 运行测试

```bash
# 运行所有测试
bash tests/run_tests.sh

# 运行特定测试
busted tests/unit/test_new_feature.lua

# 运行性能测试
bash tests/performance/benchmark.sh
```

### 测试覆盖率

- 核心功能：>80%
- 规则引擎：>90%
- 工具函数：>70%

---

## Pull Request流程

### PR检查清单

提交PR前请确保：

- [ ] 代码遵循项目规范
- [ ] 添加了必要的测试
- [ ] 所有测试通过
- [ ] 更新了相关文档
- [ ] 提交信息符合规范
- [ ] 无冲突
- [ ] PR描述清晰

### PR模板

```markdown
## 变更类型
- [ ] 新功能
- [ ] Bug修复
- [ ] 文档更新
- [ ] 性能优化
- [ ] 重构

## 变更说明
简要描述此PR的目的和实现方式

## 相关Issue
Closes #123

## 测试
说明如何测试此变更

## 截图（如适用）
添加截图展示效果

## 检查清单
- [ ] 代码遵循规范
- [ ] 添加了测试
- [ ] 测试通过
- [ ] 更新了文档
```

### 审查流程

1. **自动检查** - CI/CD运行测试
2. **代码审查** - 维护者审查代码
3. **讨论反馈** - 根据反馈修改
4. **合并** - 审查通过后合并

---

## 文档贡献

### 文档类型

- **README.md** - 项目介绍
- **docs/** - 详细文档
- **代码注释** - 内联文档
- **示例** - 使用示例

### 文档规范

```markdown
# 标题使用ATX风格

## 章节清晰

使用简洁的语言。

### 代码示例

\`\`\`lua
-- 提供完整可运行的示例
local example = "test"
\`\`\`

### 注意事项

> 使用引用块突出重要信息

### 列表

- 项目1
- 项目2
  - 子项目2.1
  - 子项目2.2
```

---

## 社区支持

### 获取帮助

- **文档**: 查看 [docs/](docs/) 目录
- **Issue**: 搜索或创建Issue
- **讨论**: 使用GitHub Discussions
- **邮件**: support@yuyuanwaf.org（如有）

### 保持联系

- **GitHub**: [@YuyuanWaf](https://github.com/YuyuanWaf)
- **微信群**: 扫码加入（添加二维码）
- **Twitter**: [@YuyuanWaf](https://twitter.com/YuyuanWaf)

---

## 致谢

感谢所有贡献者！

<!-- ALL-CONTRIBUTORS-LIST:START -->
<!-- 自动生成的贡献者列表 -->
<!-- ALL-CONTRIBUTORS-LIST:END -->

---

## 许可证

通过向此项目贡献，您同意您的贡献将在与项目相同的许可证下授权。

---

**再次感谢您的贡献！** 🎉

如有任何问题，请随时联系维护者。

