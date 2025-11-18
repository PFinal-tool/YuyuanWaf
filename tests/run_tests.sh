#!/bin/bash

# ============================================================================
# 御渊WAF - 测试运行脚本
# ============================================================================

set -e

echo "=========================================="
echo "  御渊WAF 单元测试"
echo "=========================================="
echo ""

# 设置路径
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LUA_PATH="$PROJECT_ROOT/lua/?.lua;;"

export LUA_PATH

# 颜色
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 统计
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# 运行单个测试
run_test() {
    local test_file=$1
    local test_name=$(basename "$test_file" .lua)
    
    echo "运行测试: $test_name"
    echo "----------------------------------------"
    
    if lua "$test_file"; then
        echo -e "${GREEN}✅ $test_name 通过${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}❌ $test_name 失败${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo ""
}

# 运行所有单元测试
echo ">>> 单元测试"
echo ""

for test_file in "$SCRIPT_DIR/unit"/test_*.lua; do
    if [ -f "$test_file" ]; then
        run_test "$test_file"
    fi
done

# 总结
echo "=========================================="
echo "  测试结果总结"
echo "=========================================="
echo "总测试数: $TOTAL_TESTS"
echo -e "通过: ${GREEN}$PASSED_TESTS${NC}"
echo -e "失败: ${RED}$FAILED_TESTS${NC}"
echo ""

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}✅ 所有测试通过!${NC}"
    exit 0
else
    echo -e "${RED}❌ 有 $FAILED_TESTS 个测试失败!${NC}"
    exit 1
fi

