# 御渊WAF 性能测试指南

版本: 1.0.0  
更新时间: 2025-11-18

## 概述

本文档说明如何进行御渊WAF的性能测试、分析和优化。

---

## 快速开始

### 运行完整性能测试

```bash
cd tests/performance
./run_all_tests.sh
```

### 查看测试报告

```bash
# 查看最新报告
cat tests/performance/results/complete_report_*.md

# 或在浏览器中查看
open tests/performance/results/complete_report_*.md
```

---

## 测试工具

### 必需工具

- **curl**: HTTP客户端
- **ab** (Apache Bench) 或 **wrk**: 压力测试工具

### 安装

#### macOS
```bash
brew install wrk
# ab 随 macOS 自带
```

#### Ubuntu/Debian
```bash
sudo apt-get install apache2-utils wrk
```

#### CentOS/RHEL
```bash
sudo yum install httpd-tools
```

---

## 测试类型

### 1. 基准性能测试

测试WAF处理正常请求的性能。

**运行测试**:
```bash
cd tests/performance
./benchmark.sh
```

**测试内容**:
- 不同并发级别的QPS
- 响应时间分布（P50/P95/P99）
- 长时间稳定性
- 资源使用情况

**预期结果**:
- QPS > 5000 (单核, 100并发)
- 平均响应时间 < 10ms
- P99延迟 < 50ms

### 2. 攻击检测性能测试

测试WAF检测各类攻击的性能。

**运行测试**:
```bash
cd tests/performance
./attack_performance.sh
```

**测试内容**:
- SQL注入检测性能
- XSS攻击检测性能
- 命令注入检测性能
- 路径遍历检测性能

**预期结果**:
- 攻击检测延迟 < 5ms
- 所有攻击类型检测率 100%
- 误报率 0%

### 3. WAF性能影响对比

对比开启/关闭WAF的性能差异。

**运行测试**:
```bash
cd tests/performance
./compare_with_without_waf.sh
```

**测试内容**:
- 无WAF基准测试
- 检测模式性能
- 防护模式性能

**预期结果**:
- 性能影响 < 10%
- 延迟增加 < 5ms

---

## 性能指标

### 关键指标

| 指标 | 目标值 | 说明 |
|------|--------|------|
| **QPS** | > 5000 | 单核100并发 |
| **平均响应时间** | < 10ms | 正常请求 |
| **P95延迟** | < 20ms | 95%请求延迟 |
| **P99延迟** | < 50ms | 99%请求延迟 |
| **攻击检测延迟** | < 5ms | 额外开销 |
| **内存使用** | < 200MB | 单worker进程 |
| **CPU使用率** | < 30% | 5000 QPS时 |
| **误报率** | 0% | 正常请求误判 |
| **漏报率** | < 1% | 攻击未检测 |

### 性能等级

| 等级 | QPS范围 | 响应时间 | 说明 |
|------|---------|----------|------|
| 优秀 | > 10000 | < 5ms | 企业级性能 |
| 良好 | 5000-10000 | 5-10ms | 生产环境 |
| 合格 | 1000-5000 | 10-20ms | 中小型应用 |
| 需优化 | < 1000 | > 20ms | 需要调优 |

---

## 性能测试示例

### 使用 Apache Bench

#### 基础测试
```bash
# 10000请求，100并发
ab -n 10000 -c 100 http://localhost/

# 查看详细统计
ab -n 10000 -c 100 -g results.tsv http://localhost/
```

#### 测试SQL注入检测
```bash
ab -n 5000 -c 100 "http://localhost/?id=1' OR '1'='1"
```

#### 测试POST请求
```bash
ab -n 5000 -c 100 -p post.txt -T 'application/x-www-form-urlencoded' http://localhost/login
```

### 使用 WRK

#### 基础测试
```bash
# 4线程，100连接，持续30秒
wrk -t4 -c100 -d30s http://localhost/

# 使用Lua脚本
wrk -t4 -c100 -d30s -s post.lua http://localhost/
```

#### 高级测试脚本
```lua
-- wrk_script.lua
request = function()
    local path = "/?id=" .. math.random(1, 1000)
    return wrk.format("GET", path)
end
```

```bash
wrk -t4 -c100 -d30s -s wrk_script.lua http://localhost/
```

---

## 性能分析

### 1. 分析响应时间

```bash
# 使用ab生成详细报告
ab -n 10000 -c 100 -g results.tsv http://localhost/

# 分析结果
# - 查看延迟分布
# - 识别异常值
# - 分析趋势
```

### 2. 分析资源使用

```bash
# CPU使用率
top -p $(pgrep nginx)

# 内存使用
ps aux | grep nginx

# Docker环境
docker stats nginx-container
```

### 3. 分析瓶颈

常见瓶颈：

1. **CPU密集**
   - 症状：CPU使用率高
   - 原因：复杂规则匹配
   - 解决：优化规则、使用compiled regex

2. **内存不足**
   - 症状：频繁GC或OOM
   - 原因：缓存过大、内存泄漏
   - 解决：调整shared_dict大小

3. **I/O瓶颈**
   - 症状：等待时间长
   - 原因：日志写入慢、磁盘慢
   - 解决：使用SSD、异步日志

4. **规则效率低**
   - 症状：特定规则延迟高
   - 原因：正则表达式效率低
   - 解决：优化正则、使用字符串匹配

---

## 性能优化

### 1. Nginx配置优化

```nginx
# 增加worker进程
worker_processes auto;

# 增加连接数
events {
    worker_connections 10240;
    use epoll;  # Linux
    # use kqueue;  # BSD/macOS
}

# 启用sendfile
http {
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
}
```

### 2. 共享内存优化

```nginx
# 根据流量调整大小
lua_shared_dict waf_cache 200m;      # 增大缓存
lua_shared_dict waf_blacklist 100m;
lua_shared_dict waf_stats 200m;
lua_shared_dict waf_rate_limit 100m;
```

### 3. WAF配置优化

```lua
-- 精简规则
attack_defense = {
    sql_injection = {
        check_cookie = false,  -- 关闭不必要的检查
    }
}

-- 调整缓存TTL
performance = {
    cache = {
        ip_ttl = 7200,  -- 增加缓存时间
        rule_ttl = 600,
    }
}

-- 关闭不需要的功能
anti_crawler.enabled = false  -- 如果不需要
```

### 4. 代码优化

```lua
-- 使用compiled正则
local regex = require "ngx.re"
local compiled = regex.compile("pattern", "jo")

-- 避免重复计算
local cache_key = "cached_value"
local value = cache.get(cache_key)
if not value then
    value = expensive_operation()
    cache.set(cache_key, value, 3600)
end

-- 提前返回
if condition then
    return result
end
-- 避免深层嵌套
```

### 5. 系统优化

```bash
# 增加文件描述符限制
ulimit -n 65535

# 调整TCP参数
sysctl -w net.ipv4.tcp_tw_reuse=1
sysctl -w net.core.somaxconn=65535
```

---

## 持续监控

### 1. 性能监控

```bash
# 实时QPS监控
watch -n 1 'curl -s http://localhost/api/stats/qps | jq'

# 资源监控
watch -n 1 'docker stats nginx-container --no-stream'
```

### 2. 日志分析

```bash
# 分析慢请求
awk '$NF > 0.1' access.log | wc -l

# 统计QPS
awk '{print $4}' access.log | uniq -c

# 分析攻击频率
grep "403" access.log | wc -l
```

### 3. 定期测试

建议每周/每月运行性能测试：

```bash
# 创建cron任务
0 2 * * 0 /path/to/tests/performance/run_all_tests.sh
```

---

## 性能基准

### 硬件配置

| 配置 | QPS | 延迟 | 说明 |
|------|-----|------|------|
| 1核2GB | 2000 | 5-10ms | 小型应用 |
| 2核4GB | 5000 | 3-8ms | 中型应用 |
| 4核8GB | 15000 | 2-5ms | 大型应用 |
| 8核16GB | 30000+ | 1-3ms | 企业级 |

*以上数据基于100并发测试

### 不同场景

| 场景 | QPS | 配置建议 |
|------|-----|----------|
| 静态网站 | 10000+ | 简化规则 |
| API服务 | 5000+ | 高频率限制 |
| 电商平台 | 8000+ | 全面防护 |
| 管理后台 | 1000+ | 严格防护 |

---

## 故障排查

### 性能下降

**症状**: QPS突然下降，响应变慢

**排查步骤**:
1. 查看错误日志：`tail -f error.log`
2. 检查资源使用：`top`, `free -h`
3. 查看WAF统计：`curl http://localhost/api/stats`
4. 检查黑名单数量：是否过多IP被封禁

**解决方案**:
1. 重载配置：`nginx -s reload`
2. 清理缓存：`curl -X POST http://localhost/api/cache/flush`
3. 重置黑名单：清空过期IP
4. 优化规则：减少不必要的检查

### 内存泄漏

**症状**: 内存持续增长

**排查步骤**:
1. 监控内存：`watch -n 5 'ps aux | grep nginx'`
2. 检查缓存：`curl http://localhost/api/cache/info`
3. 查看日志：是否有Lua错误

**解决方案**:
1. 定期重启worker：使用reload
2. 调整shared_dict大小
3. 修复代码中的内存泄漏

---

## 最佳实践

1. **测试环境与生产一致**
   - 使用相同的配置
   - 相同的硬件规格
   - 相同的数据量

2. **定期性能测试**
   - 每次更新后测试
   - 每月基准测试
   - 压力测试验证容量

3. **监控告警**
   - 设置QPS告警
   - 设置延迟告警
   - 设置资源告警

4. **渐进式优化**
   - 先测量，再优化
   - 一次优化一项
   - 记录优化结果

5. **文档记录**
   - 记录基准数据
   - 记录优化历史
   - 记录问题和解决方案

---

## 附录

### A. 测试脚本清单

```
tests/performance/
├── run_all_tests.sh              # 运行所有测试
├── benchmark.sh                  # 基准性能测试
├── attack_performance.sh         # 攻击检测测试
├── compare_with_without_waf.sh   # 性能影响对比
└── results/                      # 测试结果目录
```

### B. 参考资源

- [OpenResty性能优化](https://openresty.org/cn/optimization.html)
- [Nginx性能调优](https://nginx.org/en/docs/)
- [Lua性能优化](https://www.lua.org/gems/sample.pdf)

### C. 性能测试清单

- [ ] 安装测试工具
- [ ] 运行基准测试
- [ ] 运行攻击检测测试
- [ ] 运行性能对比测试
- [ ] 分析测试报告
- [ ] 识别性能瓶颈
- [ ] 实施优化措施
- [ ] 验证优化效果
- [ ] 更新文档
- [ ] 设置监控告警

---

**文档版本**: 1.0.0  
**最后更新**: 2025-11-18

