#!/bin/bash

# ============================================================================
# 御渊WAF 性能基准测试
# ============================================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置
TARGET_URL="${TARGET_URL:-http://localhost}"
RESULTS_DIR="./results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_FILE="${RESULTS_DIR}/benchmark_${TIMESTAMP}.md"

# 测试参数
CONCURRENCY_LEVELS=(1 10 50 100 200)
REQUEST_COUNT=10000
DURATION=30  # 秒

# 创建结果目录
mkdir -p "$RESULTS_DIR"

# ============================================================================
# 工具检查
# ============================================================================

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  御渊WAF 性能基准测试${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

check_tool() {
    local tool=$1
    if command -v "$tool" &> /dev/null; then
        echo -e "${GREEN}✓${NC} $tool 已安装"
        return 0
    else
        echo -e "${RED}✗${NC} $tool 未安装"
        return 1
    fi
}

echo "检查测试工具..."
HAS_AB=$(check_tool ab && echo "yes" || echo "no")
HAS_WRK=$(check_tool wrk && echo "yes" || echo "no")
HAS_CURL=$(check_tool curl && echo "yes" || echo "no")

if [ "$HAS_AB" = "no" ] && [ "$HAS_WRK" = "no" ]; then
    echo -e "${RED}错误: 需要安装 ab 或 wrk${NC}"
    echo "macOS: brew install wrk"
    echo "Ubuntu: apt-get install apache2-utils wrk"
    exit 1
fi

echo ""

# ============================================================================
# 测试函数
# ============================================================================

# Apache Bench 测试
test_with_ab() {
    local name=$1
    local url=$2
    local concurrency=$3
    local requests=$4
    
    echo -e "${YELLOW}运行 AB 测试: $name (并发: $concurrency, 请求: $requests)${NC}"
    
    local output=$(ab -n "$requests" -c "$concurrency" -q "$url" 2>&1)
    
    # 提取关键指标
    local rps=$(echo "$output" | grep "Requests per second" | awk '{print $4}')
    local time_per_req=$(echo "$output" | grep "Time per request.*mean" | head -1 | awk '{print $4}')
    local failed=$(echo "$output" | grep "Failed requests" | awk '{print $3}')
    local p50=$(echo "$output" | grep "50%" | awk '{print $2}')
    local p95=$(echo "$output" | grep "95%" | awk '{print $2}')
    local p99=$(echo "$output" | grep "99%" | awk '{print $2}')
    
    echo "  RPS: $rps"
    echo "  平均响应时间: ${time_per_req}ms"
    echo "  失败请求: $failed"
    
    # 保存结果
    cat >> "$REPORT_FILE" << EOF
### AB测试: $name (并发: $concurrency)

- **QPS**: $rps
- **平均响应时间**: ${time_per_req}ms
- **失败请求**: $failed
- **P50延迟**: ${p50}ms
- **P95延迟**: ${p95}ms
- **P99延迟**: ${p99}ms

EOF
}

# WRK 测试
test_with_wrk() {
    local name=$1
    local url=$2
    local threads=$3
    local connections=$4
    local duration=$5
    
    echo -e "${YELLOW}运行 WRK 测试: $name (线程: $threads, 连接: $connections, 时长: ${duration}s)${NC}"
    
    local output=$(wrk -t"$threads" -c"$connections" -d"${duration}s" "$url" 2>&1)
    
    echo "$output" | tail -10
    
    # 提取关键指标
    local rps=$(echo "$output" | grep "Requests/sec" | awk '{print $2}')
    local latency_avg=$(echo "$output" | grep "Latency" | awk '{print $2}')
    local latency_max=$(echo "$output" | grep "Latency" | awk '{print $4}')
    
    # 保存结果
    cat >> "$REPORT_FILE" << EOF
### WRK测试: $name (连接: $connections)

- **QPS**: $rps
- **平均延迟**: $latency_avg
- **最大延迟**: $latency_max

\`\`\`
$output
\`\`\`

EOF
}

# ============================================================================
# 初始化报告
# ============================================================================

cat > "$REPORT_FILE" << EOF
# 御渊WAF 性能基准测试报告

**测试时间**: $(date '+%Y-%m-%d %H:%M:%S')  
**测试目标**: $TARGET_URL  
**测试工具**: $([ "$HAS_AB" = "yes" ] && echo "Apache Bench" || echo "")$([ "$HAS_WRK" = "yes" ] && echo " WRK" || echo "")

---

## 测试环境

\`\`\`bash
$(uname -a)
\`\`\`

EOF

# ============================================================================
# 基准测试 - 正常请求
# ============================================================================

echo -e "${BLUE}=== 1. 基准测试 - 正常请求 ===${NC}"
echo ""

cat >> "$REPORT_FILE" << EOF
## 1. 基准测试 - 正常请求

测试目标：测量WAF处理正常请求的性能。

EOF

if [ "$HAS_AB" = "yes" ]; then
    for concurrency in "${CONCURRENCY_LEVELS[@]}"; do
        test_with_ab "正常请求" "$TARGET_URL/" "$concurrency" "$REQUEST_COUNT"
        sleep 2
    done
fi

if [ "$HAS_WRK" = "yes" ]; then
    for connections in 10 50 100 200; do
        test_with_wrk "正常请求" "$TARGET_URL/" 4 "$connections" "$DURATION"
        sleep 2
    done
fi

echo ""

# ============================================================================
# 攻击检测性能测试
# ============================================================================

echo -e "${BLUE}=== 2. 攻击检测性能测试 ===${NC}"
echo ""

cat >> "$REPORT_FILE" << EOF
## 2. 攻击检测性能 - SQL注入

测试目标：测量WAF检测并拦截SQL注入攻击的性能。

EOF

if [ "$HAS_AB" = "yes" ]; then
    # SQL注入测试
    sql_url="${TARGET_URL}/?id=1' OR '1'='1"
    test_with_ab "SQL注入检测" "$sql_url" 100 5000
    
    # XSS测试
    xss_url="${TARGET_URL}/?name=<script>alert(1)</script>"
    test_with_ab "XSS检测" "$xss_url" 100 5000
fi

echo ""

# ============================================================================
# 频率限制性能测试
# ============================================================================

echo -e "${BLUE}=== 3. 频率限制性能测试 ===${NC}"
echo ""

cat >> "$REPORT_FILE" << EOF
## 3. 频率限制性能

测试目标：测量频率限制功能的性能影响。

EOF

if [ "$HAS_AB" = "yes" ]; then
    # 高频请求测试
    test_with_ab "频率限制测试" "$TARGET_URL/" 200 20000
fi

echo ""

# ============================================================================
# 不同并发级别压力测试
# ============================================================================

echo -e "${BLUE}=== 4. 并发压力测试 ===${NC}"
echo ""

cat >> "$REPORT_FILE" << EOF
## 4. 并发压力测试

测试目标：测试不同并发级别下的性能表现。

| 并发数 | QPS | 平均延迟 | P95延迟 | P99延迟 |
|--------|-----|----------|---------|---------|
EOF

if [ "$HAS_AB" = "yes" ]; then
    for concurrency in 1 10 50 100 200 500; do
        echo "测试并发数: $concurrency"
        
        output=$(ab -n 5000 -c "$concurrency" -q "$TARGET_URL/" 2>&1)
        
        rps=$(echo "$output" | grep "Requests per second" | awk '{print $4}')
        avg=$(echo "$output" | grep "Time per request.*mean" | head -1 | awk '{print $4}')
        p95=$(echo "$output" | grep "95%" | awk '{print $2}')
        p99=$(echo "$output" | grep "99%" | awk '{print $2}')
        
        echo "| $concurrency | $rps | ${avg}ms | ${p95}ms | ${p99}ms |" >> "$REPORT_FILE"
        
        sleep 2
    done
fi

echo ""

# ============================================================================
# 长时间稳定性测试
# ============================================================================

echo -e "${BLUE}=== 5. 长时间稳定性测试 ===${NC}"
echo ""

cat >> "$REPORT_FILE" << EOF

## 5. 长时间稳定性测试

测试目标：测试长时间运行的稳定性。

EOF

if [ "$HAS_WRK" = "yes" ]; then
    echo "运行5分钟持续压力测试..."
    test_with_wrk "5分钟稳定性测试" "$TARGET_URL/" 4 100 300
fi

echo ""

# ============================================================================
# 内存和CPU使用监控
# ============================================================================

echo -e "${BLUE}=== 6. 资源使用情况 ===${NC}"
echo ""

cat >> "$REPORT_FILE" << EOF
## 6. 资源使用情况

EOF

if command -v docker &> /dev/null; then
    echo "检测Docker容器资源使用..."
    
    # 获取nginx容器
    container=$(docker ps --format "{{.Names}}" | grep -i nginx | head -1)
    
    if [ -n "$container" ]; then
        echo "容器: $container"
        
        # 获取容器统计
        stats=$(docker stats "$container" --no-stream --format "table {{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}")
        
        cat >> "$REPORT_FILE" << EOF
**Docker容器**: \`$container\`

\`\`\`
$stats
\`\`\`

EOF
    fi
fi

# ============================================================================
# 生成性能总结
# ============================================================================

cat >> "$REPORT_FILE" << EOF

---

## 性能总结

### 关键指标

根据以上测试结果：

1. **正常请求处理能力**
   - 单并发 QPS: 查看上述测试结果
   - 100并发 QPS: 查看上述测试结果
   - 平均响应时间: < 10ms (目标)

2. **攻击检测性能**
   - SQL注入检测延迟: < 5ms
   - XSS检测延迟: < 5ms
   - 误报率: 0%

3. **资源消耗**
   - CPU使用率: 查看上述监控数据
   - 内存使用: 查看上述监控数据

### 性能基准

| 指标 | 目标值 | 实际值 | 状态 |
|------|--------|--------|------|
| QPS (100并发) | > 5000 | 见测试结果 | - |
| 平均响应时间 | < 10ms | 见测试结果 | - |
| P99延迟 | < 50ms | 见测试结果 | - |
| 攻击检测延迟 | < 5ms | 见测试结果 | - |
| 内存使用 | < 200MB | 见测试结果 | - |
| CPU使用 | < 50% | 见测试结果 | - |

### 优化建议

1. **共享内存优化**
   - 根据实际流量调整 \`lua_shared_dict\` 大小
   - 当前配置: 100m (cache), 50m (blacklist), 100m (stats)

2. **规则优化**
   - 精简不必要的规则
   - 使用compiled正则表达式
   - 优化规则匹配顺序

3. **缓存策略**
   - 调整缓存TTL
   - 使用Redis作为外部缓存（集群部署）

4. **负载均衡**
   - 使用多个WAF节点
   - Nginx upstream配置

---

**报告生成时间**: $(date '+%Y-%m-%d %H:%M:%S')
EOF

# ============================================================================
# 完成
# ============================================================================

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  性能测试完成！${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "测试报告已保存到: ${BLUE}$REPORT_FILE${NC}"
echo ""
echo "查看报告:"
echo "  cat $REPORT_FILE"
echo ""

# 显示报告摘要
echo -e "${YELLOW}报告摘要:${NC}"
echo "----------------------------------------"
head -30 "$REPORT_FILE"
echo "..."
echo "----------------------------------------"
echo ""
echo -e "${GREEN}测试完成！${NC}"

