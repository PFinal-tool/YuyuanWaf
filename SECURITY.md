# 安全政策

## 支持的版本

我们目前支持以下版本的安全更新：

| 版本 | 支持状态 |
| --- | --- |
| 1.0.x | :white_check_mark: 支持 |
| < 1.0 | :x: 不支持 |

---

## 报告安全漏洞

### 🚨 请勿公开披露

如果您发现了安全漏洞，**请不要**通过公开Issue报告。

### 报告渠道

请通过以下方式之一报告安全问题：

1. **邮件报告**（推荐）
   - 发送至：security@yuyuanwaf.org
   - 主题：`[SECURITY] 安全漏洞报告`

2. **GitHub Security Advisory**
   - 访问：https://github.com/yourusername/YuyuanWaf/security/advisories/new
   - 创建私密安全报告

3. **加密通信**
   - PGP公钥：[链接到公钥]
   - 用于加密敏感信息

### 报告内容

请在报告中包含以下信息：

```markdown
## 漏洞类型
- [ ] SQL注入绕过
- [ ] XSS绕过
- [ ] 规则绕过
- [ ] 拒绝服务
- [ ] 信息泄露
- [ ] 权限提升
- [ ] 其他

## 漏洞描述
详细描述发现的安全问题

## 影响范围
- 影响版本：
- 严重程度：高/中/低
- CVSS评分（如有）：

## 复现步骤
1. 第一步
2. 第二步
3. ...

## 概念验证（PoC）
```bash
# 提供复现代码或步骤
curl "http://example.com/..." 
```

## 预期行为
应该如何工作

## 实际行为  
实际发生了什么

## 环境信息
- 操作系统：
- OpenResty版本：
- WAF版本：
- 其他相关信息：

## 建议的修复方案（可选）
如果您有修复建议，请提供
```

---

## 响应流程

### 时间线

1. **确认收到** - 1个工作日内
   - 我们会确认收到您的报告

2. **初步评估** - 3个工作日内
   - 评估漏洞的严重性和影响范围
   - 与您确认细节

3. **修复开发** - 根据严重程度
   - 严重：7天内
   - 中等：14天内
   - 较低：30天内

4. **发布补丁** - 修复完成后
   - 发布安全更新
   - 发布安全公告

5. **公开披露** - 90天后或修复发布后30天
   - 在致谢名单中列出报告者（如同意）
   - 发布CVE（如适用）

### 严重性评级

我们使用CVSS v3.1评分系统：

| 评分 | 严重程度 | 响应时间 |
|------|---------|---------|
| 9.0-10.0 | 严重 | 立即处理 |
| 7.0-8.9 | 高 | 7天内 |
| 4.0-6.9 | 中等 | 14天内 |
| 0.1-3.9 | 较低 | 30天内 |

---

## 安全更新

### 订阅通知

- **GitHub Watch** - 关注仓库获取安全公告
- **邮件列表** - security-announce@yuyuanwaf.org
- **RSS订阅** - [安全公告RSS]

### 应用更新

```bash
# 检查当前版本
cat VERSION

# 备份配置
cp -r conf conf.backup

# 更新WAF
git pull origin main

# 或使用发布包
wget https://github.com/yourusername/YuyuanWaf/releases/download/v1.0.1/yuyuanwaf-1.0.1.tar.gz
tar xzf yuyuanwaf-1.0.1.tar.gz

# 重启服务
nginx -s reload
```

---

## 安全最佳实践

### 部署配置

1. **最小权限原则**
   ```nginx
   user nobody;
   ```

2. **安全的日志存储**
   ```nginx
   access_log /var/log/waf/access.log;
   error_log /var/log/waf/error.log;
   # 设置适当的文件权限
   chmod 640 /var/log/waf/*.log
   ```

3. **启用TLS**
   ```nginx
   listen 443 ssl http2;
   ssl_certificate /path/to/cert.pem;
   ssl_certificate_key /path/to/key.pem;
   ssl_protocols TLSv1.2 TLSv1.3;
   ```

4. **配置文件权限**
   ```bash
   chmod 640 conf/nginx.conf
   chmod 640 lua/config.lua
   chown root:nginx conf/
   ```

### 规则配置

1. **启用所有防护模块**
   ```lua
   config = {
       mode = "protection",  -- 生产环境使用protection
       sql_injection = { enabled = true },
       xss = { enabled = true },
       command_injection = { enabled = true },
       -- ... 其他模块
   }
   ```

2. **严格的频率限制**
   ```lua
   rate_limit = {
       per_ip = {
           rate = 100,  -- 根据实际情况调整
           burst = 200
       }
   }
   ```

3. **定期更新规则**
   ```bash
   # 定期拉取最新规则
   cd /path/to/YuyuanWaf
   git pull origin main
   nginx -s reload
   ```

### 监控和告警

1. **启用详细日志**
   ```lua
   logging = {
       level = "warn",
       attack_log = true
   }
   ```

2. **监控攻击日志**
   ```bash
   tail -f logs/attack.log
   ```

3. **设置告警**
   ```bash
   # 示例：监控攻击频率
   #!/bin/bash
   THRESHOLD=100
   COUNT=$(grep -c "WAF-ATTACK" logs/attack.log)
   if [ $COUNT -gt $THRESHOLD ]; then
       # 发送告警
       echo "High attack rate detected" | mail -s "WAF Alert" admin@example.com
   fi
   ```

---

## 已知安全考虑

### 当前限制

1. **DDoS防护**
   - WAF主要防护应用层攻击
   - 建议配合CDN或专业DDoS防护服务

2. **加密流量**
   - WAF在Nginx层工作，无法检测TLS加密流量中的攻击
   - 需要在TLS终止后应用WAF

3. **零日漏洞**
   - 基于规则的检测可能无法防御全新的攻击手法
   - 建议配合其他安全措施

### 缓解措施

1. **多层防御**
   - 使用CDN/DDoS防护
   - 应用WAF
   - 服务器加固
   - 应用程序安全

2. **定期审计**
   ```bash
   # 定期检查配置
   # 审查日志
   # 更新规则
   ```

3. **安全监控**
   - 实时监控攻击
   - 分析攻击趋势
   - 及时更新防护策略

---

## 安全审计

### 代码审计

我们欢迎安全研究人员对代码进行审计：

```bash
# 克隆仓库
git clone https://github.com/yourusername/YuyuanWaf.git
cd YuyuanWaf

# 检查敏感操作
grep -r "os.execute\|io.popen" lua/

# 检查SQL操作
grep -r "ngx.req.get_body_data" lua/

# 检查文件操作
grep -r "io.open\|io.read" lua/
```

### 依赖检查

```bash
# 检查OpenResty版本
openresty -v

# 检查Lua模块
luarocks list

# 扫描已知漏洞
# 使用工具如 snyk, OWASP Dependency-Check
```

---

## 漏洞赏金计划

### 当前状态

🚧 **规划中** - 我们正在筹备漏洞赏金计划

### 奖励范围

未来可能的奖励范围：

| 严重程度 | 奖励金额 |
|---------|---------|
| 严重 | $500 - $2000 |
| 高 | $200 - $500 |
| 中等 | $50 - $200 |
| 较低 | 致谢 |

---

## 安全联系方式

- **安全团队邮箱**: security@yuyuanwaf.org
- **PGP密钥指纹**: `待添加`
- **安全公告**: https://github.com/yourusername/YuyuanWaf/security/advisories

---

## 历史安全公告

### 2025

目前暂无安全公告（项目刚发布）

---

## 致谢

感谢以下安全研究人员的贡献：

<!-- 安全研究人员列表 -->
- 待添加

---

## 参考资源

- [OWASP WAF Best Practices](https://owasp.org/www-project-web-application-firewall/)
- [CVSS Calculator](https://www.first.org/cvss/calculator/3.1)
- [CWE Top 25](https://cwe.mitre.org/top25/)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)

---

**感谢您帮助我们保护社区安全！** 🔒

最后更新: 2025-11-18

