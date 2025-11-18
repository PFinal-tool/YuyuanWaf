-- ============================================================================
-- 御渊WAF - SQL注入规则单元测试
-- Version: 1.0.0
-- ============================================================================

package.path = "/Users/pfinal/www/YuyuanWaf/lua/?.lua;" .. package.path

local string_utils = require "lib.string_utils"

-- 测试框架
local tests_passed = 0
local tests_failed = 0

local function test(name, func)
    local success, err = pcall(func)
    if success then
        print("✅ PASS: " .. name)
        tests_passed = tests_passed + 1
    else
        print("❌ FAIL: " .. name)
        print("   Error: " .. tostring(err))
        tests_failed = tests_failed + 1
    end
end

local function assert_true(condition, message)
    if not condition then
        error(message or "Assertion failed")
    end
end

local function assert_false(condition, message)
    if condition then
        error(message or "Assertion failed")
    end
end

-- ============================================================================
-- 测试用例
-- ============================================================================

print("========== SQL注入检测规则测试 ==========\n")

-- 基础SQL注入
test("检测 OR 1=1", function()
    local is_attack, pattern = string_utils.contains_sqli("1' OR '1'='1")
    assert_true(is_attack, "应该检测到SQL注入")
end)

test("检测 UNION SELECT", function()
    local is_attack, pattern = string_utils.contains_sqli("1' UNION SELECT 1,2,3--")
    assert_true(is_attack, "应该检测到UNION注入")
end)

test("检测 SLEEP函数", function()
    local is_attack, pattern = string_utils.contains_sqli("1' AND SLEEP(5)--")
    assert_true(is_attack, "应该检测到时间盲注")
end)

test("检测 LOAD_FILE", function()
    local is_attack, pattern = string_utils.contains_sqli("1' UNION SELECT LOAD_FILE('/etc/passwd')--")
    assert_true(is_attack, "应该检测到文件读取")
end)

test("检测 @@version", function()
    local is_attack, pattern = string_utils.contains_sqli("1' UNION SELECT @@version--")
    assert_true(is_attack, "应该检测到信息收集")
end)

test("检测 堆叠查询", function()
    local is_attack, pattern = string_utils.contains_sqli("1'; DROP TABLE users--")
    assert_true(is_attack, "应该检测到堆叠查询")
end)

test("检测 注释符", function()
    local is_attack, pattern = string_utils.contains_sqli("admin'--")
    assert_true(is_attack, "应该检测到SQL注释")
end)

test("检测 BENCHMARK", function()
    local is_attack, pattern = string_utils.contains_sqli("1' AND BENCHMARK(1000000,MD5('a'))--")
    assert_true(is_attack, "应该检测到BENCHMARK")
end)

-- 编码绕过
test("检测 CHAR编码", function()
    local is_attack, pattern = string_utils.contains_sqli("1' AND CHAR(65)=CHAR(65)--")
    assert_true(is_attack, "应该检测到CHAR编码")
end)

test("检测 HEX编码", function()
    local is_attack, pattern = string_utils.contains_sqli("1' AND HEX('a')--")
    assert_true(is_attack, "应该检测到HEX编码")
end)

-- 子查询
test("检测 子查询", function()
    local is_attack, pattern = string_utils.contains_sqli("1' AND (SELECT COUNT(*) FROM users)>0--")
    assert_true(is_attack, "应该检测到子查询")
end)

test("检测 EXISTS", function()
    local is_attack, pattern = string_utils.contains_sqli("1' AND EXISTS(SELECT * FROM users)--")
    assert_true(is_attack, "应该检测到EXISTS")
end)

test("检测 ORDER BY", function()
    local is_attack, pattern = string_utils.contains_sqli("1' ORDER BY 10--")
    assert_true(is_attack, "应该检测到ORDER BY")
end)

-- 负面测试（不应该误报）
test("正常数字不误报", function()
    local is_attack = string_utils.contains_sqli("123")
    assert_false(is_attack, "正常数字不应误报")
end)

test("正常文本不误报", function()
    local is_attack = string_utils.contains_sqli("hello world")
    assert_false(is_attack, "正常文本不应误报")
end)

test("正常邮箱不误报", function()
    local is_attack = string_utils.contains_sqli("user@example.com")
    assert_false(is_attack, "正常邮箱不应误报")
end)

-- ============================================================================
-- 测试结果
-- ============================================================================

print("\n========== 测试结果 ==========")
print(string.format("通过: %d", tests_passed))
print(string.format("失败: %d", tests_failed))
print(string.format("总计: %d", tests_passed + tests_failed))

if tests_failed == 0 then
    print("\n✅ 所有测试通过!")
    os.exit(0)
else
    print("\n❌ 有测试失败!")
    os.exit(1)
end

