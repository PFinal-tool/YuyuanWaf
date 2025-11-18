# 性能测试使用说明

## 运行测试

由于权限设置问题,请使用以下方式运行测试脚本:

### 方式1: 使用bash运行(推荐)

```bash
cd /Users/pfinal/www/YuyuanWaf/tests/performance

# 运行完整测试套件
bash run_all_tests.sh

# 或运行单个测试
bash benchmark.sh
bash attack_performance.sh
bash compare_with_without_waf.sh
```

### 方式2: 设置执行权限后运行

```bash
cd /Users/pfinal/www/YuyuanWaf/tests/performance

# 设置执行权限
chmod +x run_all_tests.sh benchmark.sh attack_performance.sh compare_with_without_waf.sh

# 直接运行
./run_all_tests.sh
```

## 配置测试目标

```bash
# 设置目标URL
export TARGET_URL="http://your-server-address"

# 运行测试
bash run_all_tests.sh
```

## 测试前准备

1. **确保WAF服务正在运行**
   ```bash
   curl http://localhost
   ```

2. **安装测试工具**
   ```bash
   # macOS
   brew install wrk
   
   # Ubuntu/Debian
   sudo apt-get install apache2-utils wrk
   ```

3. **检查环境**
   ```bash
   # 检查工具是否安装
   which ab
   which wrk
   which curl
   ```

## 查看测试结果

```bash
# 查看最新综合报告
cat results/complete_report_*.md

# 查看所有报告
ls -lh results/

# 在浏览器中查看(macOS)
open results/complete_report_*.md
```

## 测试预计时间

- **完整测试套件**: ~10分钟
- **基准测试**: ~5分钟  
- **攻击检测测试**: ~2分钟
- **性能对比测试**: ~3分钟

## 常见问题

### Q: 提示"目标服务不可访问"

**A**: 确保WAF服务正在运行:
```bash
docker ps | grep nginx
curl http://localhost
```

### Q: 提示"ab命令未找到"

**A**: 安装Apache Bench:
```bash
# macOS (通常已自带)
which ab

# Ubuntu/Debian
sudo apt-get install apache2-utils
```

### Q: 测试结果QPS很低

**A**: 可能的原因:
1. 服务器配置不足
2. 规则配置过于严格
3. 网络延迟高
4. 并发连接数受限

参考 `docs/PERFORMANCE.md` 进行优化。

## 更多信息

详细文档: [docs/PERFORMANCE.md](../../docs/PERFORMANCE.md)

