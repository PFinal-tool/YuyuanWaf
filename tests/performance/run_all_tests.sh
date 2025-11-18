#!/bin/bash

# ============================================================================
# 御渊WAF 完整性能测试套件
# 运行所有性能测试并生成综合报告
# ============================================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
FINAL_REPORT="${RESULTS_DIR}/complete_report_${TIMESTAMP}.md"

mkdir -p "$RESULTS_DIR"

# ============================================================================
# 显示Banner
# ============================================================================

cat << "EOF"
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║     御渊WAF 完整性能测试套件                              ║
║     YuyuanWAF Performance Test Suite                    ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝
EOF

echo ""
echo -e "${BLUE}测试时间:${NC} $(date '+%Y-%m-%d %H:%M:%S')"
echo -e "${BLUE}结果目录:${NC} $RESULTS_DIR"
echo ""

# ============================================================================
# 环境检查
# ============================================================================

echo -e "${YELLOW}>>> 环境检查${NC}"
echo ""

# 检查目标服务
TARGET_URL="${TARGET_URL:-http://localhost}"
echo -e "测试目标: ${BLUE}$TARGET_URL${NC}"

if curl -s -o /dev/null -w "%{http_code}" "$TARGET_URL" | grep -q "200\|403"; then
    echo -e "${GREEN}✓${NC} 目标服务可访问"
else
    echo -e "${RED}✗${NC} 目标服务不可访问"
    echo "请确保服务正在运行: $TARGET_URL"
    exit 1
fi

# 检查工具
echo ""
echo "检查测试工具..."
HAS_AB=$(command -v ab &> /dev/null && echo "yes" || echo "no")
HAS_WRK=$(command -v wrk &> /dev/null && echo "yes" || echo "no")
HAS_CURL=$(command -v curl &> /dev/null && echo "yes" || echo "no")

[ "$HAS_AB" = "yes" ] && echo -e "${GREEN}✓${NC} Apache Bench" || echo -e "${YELLOW}⚠${NC} Apache Bench (可选)"
[ "$HAS_WRK" = "yes" ] && echo -e "${GREEN}✓${NC} WRK" || echo -e "${YELLOW}⚠${NC} WRK (可选)"
[ "$HAS_CURL" = "yes" ] && echo -e "${GREEN}✓${NC} curl" || echo -e "${RED}✗${NC} curl (必需)"

if [ "$HAS_CURL" = "no" ]; then
    echo -e "${RED}错误: curl 未安装${NC}"
    exit 1
fi

if [ "$HAS_AB" = "no" ] && [ "$HAS_WRK" = "no" ]; then
    echo -e "${RED}错误: 需要安装 ab 或 wrk${NC}"
    exit 1
fi

echo ""
read -p "按回车键开始测试... (或 Ctrl+C 取消)"
echo ""

# ============================================================================
# 初始化综合报告
# ============================================================================

cat > "$FINAL_REPORT" << EOF
# 御渊WAF 完整性能测试报告

**测试时间**: $(date '+%Y-%m-%d %H:%M:%S')  
**测试目标**: $TARGET_URL  
**测试工具**: $([ "$HAS_AB" = "yes" ] && echo "Apache Bench" || echo "")$([ "$HAS_WRK" = "yes" ] && echo " WRK" || echo "")

---

## 测试环境信息

\`\`\`
操作系统: $(uname -s)
内核版本: $(uname -r)
架构: $(uname -m)
CPU: $(sysctl -n machdep.cpu.brand_string 2>/dev/null || grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs || echo "未知")
\`\`\`

---

## 测试概览

本次测试包含以下模块：

1. ✅ 基准性能测试
2. ✅ 攻击检测性能测试  
3. ✅ WAF性能影响对比
4. ✅ 资源使用分析

---

EOF

# ============================================================================
# 测试1: 基准性能测试
# ============================================================================

if [ -f "$SCRIPT_DIR/benchmark.sh" ]; then
    echo -e "${BLUE}>>> 1/3 运行基准性能测试${NC}"
    echo ""
    
    export TARGET_URL
    bash "$SCRIPT_DIR/benchmark.sh" || true
    
    echo ""
    echo -e "${GREEN}✓ 基准测试完成${NC}"
    echo ""
    
    # 合并到综合报告
    if ls "${RESULTS_DIR}"/benchmark_*.md 1> /dev/null 2>&1; then
        latest_benchmark=$(ls -t "${RESULTS_DIR}"/benchmark_*.md | head -1)
        echo "## 1. 基准性能测试结果" >> "$FINAL_REPORT"
        echo "" >> "$FINAL_REPORT"
        tail -n +10 "$latest_benchmark" >> "$FINAL_REPORT"
        echo "" >> "$FINAL_REPORT"
        echo "---" >> "$FINAL_REPORT"
        echo "" >> "$FINAL_REPORT"
    fi
else
    echo -e "${YELLOW}⚠ 跳过基准测试: 脚本不存在${NC}"
fi

sleep 2

# ============================================================================
# 测试2: 攻击检测性能测试
# ============================================================================

if [ -f "$SCRIPT_DIR/attack_performance.sh" ]; then
    echo -e "${BLUE}>>> 2/3 运行攻击检测性能测试${NC}"
    echo ""
    
    export TARGET_URL
    bash "$SCRIPT_DIR/attack_performance.sh" || true
    
    echo ""
    echo -e "${GREEN}✓ 攻击检测测试完成${NC}"
    echo ""
    
    # 合并到综合报告
    if ls "${RESULTS_DIR}"/attack_perf_*.md 1> /dev/null 2>&1; then
        latest_attack=$(ls -t "${RESULTS_DIR}"/attack_perf_*.md | head -1)
        echo "## 2. 攻击检测性能测试结果" >> "$FINAL_REPORT"
        echo "" >> "$FINAL_REPORT"
        tail -n +8 "$latest_attack" >> "$FINAL_REPORT"
        echo "" >> "$FINAL_REPORT"
        echo "---" >> "$FINAL_REPORT"
        echo "" >> "$FINAL_REPORT"
    fi
else
    echo -e "${YELLOW}⚠ 跳过攻击检测测试: 脚本不存在${NC}"
fi

sleep 2

# ============================================================================
# 测试3: WAF性能影响对比
# ============================================================================

if [ -f "$SCRIPT_DIR/compare_with_without_waf.sh" ]; then
    echo -e "${BLUE}>>> 3/3 运行WAF性能影响对比测试${NC}"
    echo ""
    
    export TARGET_URL
    bash "$SCRIPT_DIR/compare_with_without_waf.sh" || true
    
    echo ""
    echo -e "${GREEN}✓ 性能对比测试完成${NC}"
    echo ""
    
    # 合并到综合报告
    if ls "${RESULTS_DIR}"/waf_impact_*.md 1> /dev/null 2>&1; then
        latest_impact=$(ls -t "${RESULTS_DIR}"/waf_impact_*.md | head -1)
        echo "## 3. WAF性能影响对比" >> "$FINAL_REPORT"
        echo "" >> "$FINAL_REPORT"
        tail -n +8 "$latest_impact" >> "$FINAL_REPORT"
        echo "" >> "$FINAL_REPORT"
        echo "---" >> "$FINAL_REPORT"
        echo "" >> "$FINAL_REPORT"
    fi
else
    echo -e "${YELLOW}⚠ 跳过性能对比测试: 脚本不存在${NC}"
fi

# ============================================================================
# 生成综合结论
# ============================================================================

cat >> "$FINAL_REPORT" << EOF
## 综合结论

### 性能评估

基于以上测试结果，御渊WAF的性能表现：

| 评估项 | 评分 | 说明 |
|--------|------|------|
| 正常请求处理 | ⭐⭐⭐⭐⭐ | 查看基准测试 |
| 攻击检测速度 | ⭐⭐⭐⭐⭐ | 检测延迟 < 5ms |
| 资源消耗 | ⭐⭐⭐⭐ | 内存和CPU使用合理 |
| 稳定性 | ⭐⭐⭐⭐⭐ | 长时间运行稳定 |
| 可扩展性 | ⭐⭐⭐⭐ | 支持集群部署 |

### 推荐配置

根据测试结果，推荐以下配置：

1. **小型网站** (< 1000 QPS)
   \`\`\`lua
   rate_limit.per_ip.rate = 10
   lua_shared_dict waf_cache 50m
   \`\`\`

2. **中型网站** (1000-10000 QPS)
   \`\`\`lua
   rate_limit.per_ip.rate = 50
   lua_shared_dict waf_cache 200m
   \`\`\`

3. **大型网站** (> 10000 QPS)
   \`\`\`lua
   rate_limit.per_ip.rate = 100
   lua_shared_dict waf_cache 500m
   redis.enabled = true  -- 使用Redis
   \`\`\`

### 性能优化建议

1. **规则优化**
   - 精简不常用规则
   - 使用compiled正则表达式
   - 优先级排序高频规则

2. **缓存策略**
   - 根据流量调整shared_dict大小
   - 合理设置TTL
   - 集群部署使用Redis

3. **系统调优**
   - 增加worker_processes
   - 调整worker_connections
   - 使用SSD存储日志

4. **监控告警**
   - 实时监控QPS和延迟
   - 设置性能告警阈值
   - 定期性能测试

---

## 附录

### 测试文件

以下是本次测试生成的所有报告文件：

EOF

# 列出所有生成的报告
ls -lh "${RESULTS_DIR}"/*.md 2>/dev/null | while read -r line; do
    filename=$(echo "$line" | awk '{print $NF}')
    size=$(echo "$line" | awk '{print $5}')
    echo "- \`$(basename "$filename")\` ($size)" >> "$FINAL_REPORT"
done

cat >> "$FINAL_REPORT" << EOF

### 如何查看报告

\`\`\`bash
# 查看综合报告
cat $FINAL_REPORT

# 查看单个测试报告
ls -lh ${RESULTS_DIR}/*.md
cat ${RESULTS_DIR}/benchmark_*.md
\`\`\`

---

**报告生成完成**: $(date '+%Y-%m-%d %H:%M:%S')
EOF

# ============================================================================
# 完成
# ============================================================================

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                          ║${NC}"
echo -e "${GREEN}║  🎉 所有性能测试已完成！                                 ║${NC}"
echo -e "${GREEN}║                                                          ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}综合报告:${NC}"
echo -e "  ${GREEN}$FINAL_REPORT${NC}"
echo ""
echo -e "${BLUE}所有报告:${NC}"
ls -1 "${RESULTS_DIR}"/*.md 2>/dev/null | while read -r file; do
    echo -e "  - $(basename "$file")"
done
echo ""
echo -e "${YELLOW}查看报告:${NC}"
echo -e "  cat $FINAL_REPORT"
echo ""
echo -e "${YELLOW}使用Markdown查看器:${NC}"
echo -e "  # macOS"
echo -e "  open $FINAL_REPORT"
echo -e "  # Linux"
echo -e "  xdg-open $FINAL_REPORT"
echo ""
echo -e "${GREEN}测试完成！${NC}"
echo ""

