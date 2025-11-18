#!/bin/bash

# ============================================================================
# 御渊WAF 性能影响对比测试
# 对比开启/关闭WAF的性能差异
# ============================================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

TARGET_URL="${TARGET_URL:-http://localhost}"
RESULTS_DIR="./results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_FILE="${RESULTS_DIR}/waf_impact_${TIMESTAMP}.md"

mkdir -p "$RESULTS_DIR"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  WAF性能影响对比测试${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# ============================================================================
# 检查工具
# ============================================================================

if ! command -v ab &> /dev/null; then
    echo -e "${RED}错误: 需要安装 Apache Bench (ab)${NC}"
    exit 1
fi

if ! command -v curl &> /dev/null; then
    echo -e "${RED}错误: 需要安装 curl${NC}"
    exit 1
fi

# ============================================================================
# 初始化报告
# ============================================================================

cat > "$REPORT_FILE" << EOF
# WAF性能影响对比测试报告

**测试时间**: $(date '+%Y-%m-%d %H:%M:%S')  
**测试目标**: $TARGET_URL

---

## 测试场景

1. **无WAF**: WAF模式设置为 \`off\`
2. **仅检测**: WAF模式设置为 \`detection\`（检测但不拦截）
3. **完整防护**: WAF模式设置为 \`protection\`（检测并拦截）

每个场景运行相同的压力测试，对比性能差异。

---

EOF

# ============================================================================
# 测试函数
# ============================================================================

run_benchmark() {
    local mode=$1
    local name=$2
    
    echo -e "${YELLOW}测试模式: $name${NC}"
    
    # 切换WAF模式（如果有API）
    if curl -s "${TARGET_URL}/api/health" > /dev/null 2>&1; then
        echo "  切换WAF模式到: $mode"
        curl -s -X POST "${TARGET_URL}/api/config/mode" \
            -H "Content-Type: application/json" \
            -d "{\"mode\":\"$mode\"}" > /dev/null 2>&1 || true
        sleep 2
    else
        echo -e "${YELLOW}  警告: 无法通过API切换模式，请手动切换${NC}"
        echo "  请修改 lua/config.lua 中的 mode = \"$mode\""
        read -p "  修改完成后按回车继续..."
    fi
    
    # 运行测试
    echo "  运行测试..."
    local output=$(ab -n 10000 -c 100 -q "$TARGET_URL/" 2>&1)
    
    # 提取数据
    local rps=$(echo "$output" | grep "Requests per second" | awk '{print $4}')
    local time_per_req=$(echo "$output" | grep "Time per request.*mean" | head -1 | awk '{print $4}')
    local failed=$(echo "$output" | grep "Failed requests" | awk '{print $3}')
    local p50=$(echo "$output" | grep "50%" | awk '{print $2}')
    local p90=$(echo "$output" | grep "90%" | awk '{print $2}')
    local p95=$(echo "$output" | grep "95%" | awk '{print $2}')
    local p99=$(echo "$output" | grep "99%" | awk '{print $2}')
    
    echo "  QPS: $rps"
    echo "  平均响应时间: ${time_per_req}ms"
    echo ""
    
    # 保存结果
    cat >> "$REPORT_FILE" << EOF
### $name

\`\`\`
QPS: $rps
平均响应时间: ${time_per_req}ms
失败请求: $failed

延迟分布:
  P50: ${p50}ms
  P90: ${p90}ms
  P95: ${p95}ms
  P99: ${p99}ms
\`\`\`

EOF
    
    # 保存数据用于对比
    eval "${mode}_rps=\"$rps\""
    eval "${mode}_time=\"$time_per_req\""
    eval "${mode}_p95=\"$p95\""
}

# ============================================================================
# 运行测试
# ============================================================================

echo -e "${BLUE}开始性能对比测试...${NC}"
echo ""

cat >> "$REPORT_FILE" << EOF
## 测试结果

EOF

# 测试1: 无WAF
run_benchmark "off" "场景1: 无WAF (基准)"

# 测试2: 仅检测模式
run_benchmark "detection" "场景2: 检测模式"

# 测试3: 完整防护模式
run_benchmark "protection" "场景3: 防护模式"

# ============================================================================
# 性能对比分析
# ============================================================================

cat >> "$REPORT_FILE" << EOF

---

## 性能对比表

| 指标 | 无WAF | 检测模式 | 防护模式 |
|------|-------|----------|----------|
| QPS | ${off_rps} | ${detection_rps} | ${protection_rps} |
| 平均响应时间 | ${off_time}ms | ${detection_time}ms | ${protection_time}ms |
| P95延迟 | ${off_p95}ms | ${detection_p95}ms | ${protection_p95}ms |

EOF

# 计算性能影响百分比（如果数据可用）
if [ -n "$off_rps" ] && [ -n "$detection_rps" ] && [ -n "$protection_rps" ]; then
    detection_impact=$(echo "scale=2; (1 - $detection_rps / $off_rps) * 100" | bc 2>/dev/null || echo "N/A")
    protection_impact=$(echo "scale=2; (1 - $protection_rps / $off_rps) * 100" | bc 2>/dev/null || echo "N/A")
    
    cat >> "$REPORT_FILE" << EOF

## 性能影响分析

- **检测模式性能影响**: ${detection_impact}% (QPS下降)
- **防护模式性能影响**: ${protection_impact}% (QPS下降)

### 结论

1. **开销分析**
   - 检测模式增加约 ${detection_impact}% 延迟
   - 防护模式增加约 ${protection_impact}% 延迟

2. **可接受性**
   - 如果影响 < 5%: 优秀
   - 如果影响 5-10%: 良好
   - 如果影响 10-20%: 可接受
   - 如果影响 > 20%: 需要优化

3. **优化建议**
   - 优化高频规则
   - 使用compiled正则
   - 调整缓存策略
   - 使用Redis（集群部署）

EOF
fi

# ============================================================================
# 可视化对比
# ============================================================================

cat >> "$REPORT_FILE" << EOF

## 性能对比图示

\`\`\`
QPS对比:
  无WAF:    $off_rps ████████████████████████████ (100%)
  检测模式: $detection_rps ███████████████████████ (相对比例)
  防护模式: $protection_rps ███████████████████ (相对比例)

响应时间对比:
  无WAF:    ${off_time}ms ████
  检测模式: ${detection_time}ms ████▓
  防护模式: ${protection_time}ms █████
\`\`\`

---

**报告生成时间**: $(date '+%Y-%m-%d %H:%M:%S')
EOF

# ============================================================================
# 完成
# ============================================================================

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  性能对比测试完成！${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "报告保存到: ${BLUE}$REPORT_FILE${NC}"
echo ""
echo "查看报告:"
echo "  cat $REPORT_FILE"
echo ""

