# 御渊WAF 性能测试

本目录包含御渊WAF的完整性能测试套件。

## 快速开始

### 1. 安装依赖

#### macOS
```bash
brew install wrk
```

#### Ubuntu/Debian
```bash
sudo apt-get install apache2-utils wrk
```

### 2. 运行测试

```bash
# 运行所有测试
./run_all_tests.sh

# 运行单个测试
./benchmark.sh                     # 基准性能测试
./attack_performance.sh            # 攻击检测测试
./compare_with_without_waf.sh      # 性能对比测试
```

### 3. 查看结果

```bash
# 查看最新报告
cat results/complete_report_*.md

# 或在浏览器中打开
open results/complete_report_*.md
```

## 测试脚本说明

| 脚本 | 说明 | 测试时间 |
|------|------|----------|
| `run_all_tests.sh` | 运行所有测试并生成综合报告 | ~10分钟 |
| `benchmark.sh` | 基准性能测试（QPS、延迟等） | ~5分钟 |
| `attack_performance.sh` | 攻击检测性能测试 | ~2分钟 |
| `compare_with_without_waf.sh` | WAF开关性能对比 | ~3分钟 |

## 配置选项

### 环境变量

```bash
# 设置测试目标URL（默认: http://localhost）
export TARGET_URL="http://your-waf-server"

# 运行测试
./run_all_tests.sh
```

### 测试参数

修改脚本中的以下参数：

```bash
# benchmark.sh
CONCURRENCY_LEVELS=(1 10 50 100 200)  # 并发级别
REQUEST_COUNT=10000                    # 请求数量
DURATION=30                            # 测试时长（秒）
```

## 测试报告

所有测试报告保存在 `results/` 目录：

```
results/
├── complete_report_20251118_120000.md      # 综合报告
├── benchmark_20251118_120000.md            # 基准测试报告
├── attack_perf_20251118_120500.md          # 攻击测试报告
└── waf_impact_20251118_121000.md           # 性能对比报告
```

## 性能指标

### 目标值

| 指标 | 目标 |
|------|------|
| QPS (100并发) | > 5000 |
| 平均响应时间 | < 10ms |
| P99延迟 | < 50ms |
| 攻击检测延迟 | < 5ms |

### 预期结果

**正常请求处理**:
- 单核可处理 5000+ QPS
- 响应时间稳定在 5-10ms

**攻击检测**:
- SQL注入检测 < 5ms
- XSS检测 < 5ms
- 命令注入检测 < 3ms

**WAF性能影响**:
- 检测模式影响 < 5%
- 防护模式影响 < 10%

## 故障排查

### 测试失败

**问题**: 目标服务不可访问

**解决**:
```bash
# 检查服务状态
curl http://localhost

# 检查Docker容器
docker ps | grep nginx

# 查看日志
docker logs nginx-container
```

### 性能不达标

**问题**: QPS低于预期

**排查步骤**:
1. 检查CPU和内存使用
2. 查看错误日志
3. 检查网络延迟
4. 验证规则配置

**优化建议**:
1. 增加worker进程
2. 调整共享内存
3. 精简规则
4. 使用SSD

## 持续集成

### 定期测试

添加到crontab：

```bash
# 每周日凌晨2点运行测试
0 2 * * 0 cd /path/to/tests/performance && ./run_all_tests.sh

# 发送报告（可选）
0 2 * * 0 cd /path/to/tests/performance && ./run_all_tests.sh && mail -s "WAF Performance Report" admin@example.com < results/complete_report_*.md
```

### CI/CD集成

#### GitHub Actions

```yaml
name: Performance Test

on:
  schedule:
    - cron: '0 2 * * 0'  # 每周日
  workflow_dispatch:

jobs:
  performance:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Install tools
        run: sudo apt-get install -y apache2-utils wrk
      - name: Start WAF
        run: docker-compose up -d
      - name: Run tests
        run: cd tests/performance && ./run_all_tests.sh
      - name: Upload results
        uses: actions/upload-artifact@v2
        with:
          name: performance-reports
          path: tests/performance/results/
```

## 高级用法

### 自定义测试场景

创建自定义测试脚本：

```bash
#!/bin/bash
# custom_test.sh

TARGET_URL="http://localhost"

# 测试特定endpoint
ab -n 5000 -c 100 "$TARGET_URL/api/users"

# 测试不同HTTP方法
ab -n 5000 -c 100 -m POST "$TARGET_URL/api/login"

# 使用自定义header
ab -n 5000 -c 100 -H "X-Custom-Header: value" "$TARGET_URL/"
```

### 压力测试

模拟真实流量：

```bash
# 使用wrk的Lua脚本
cat > mixed_traffic.lua << 'EOF'
-- 模拟混合流量
local counter = 0
request = function()
    counter = counter + 1
    
    -- 90% 正常请求
    if counter % 10 < 9 then
        return wrk.format("GET", "/")
    end
    
    -- 10% 攻击请求
    return wrk.format("GET", "/?id=1' OR '1'='1")
end
EOF

wrk -t4 -c100 -d60s -s mixed_traffic.lua http://localhost/
```

## 更多信息

详细文档请参考：
- [性能测试指南](../../docs/PERFORMANCE.md)
- [性能优化建议](../../docs/PERFORMANCE.md#性能优化)
- [故障排查](../../docs/PERFORMANCE.md#故障排查)

## 支持

如有问题，请：
1. 查看文档：`docs/PERFORMANCE.md`
2. 提交Issue：https://github.com/yourusername/YuyuanWaf/issues
3. 加入讨论：https://github.com/yourusername/YuyuanWaf/discussions

