-- ============================================================================
-- 御渊WAF - XSS攻击规则单元测试
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

print("========== XSS攻击检测规则测试 ==========\n")

-- 基础XSS
test("检测 <script>alert", function()
    local is_attack = string_utils.contains_xss("<script>alert(1)</script>")
    assert_true(is_attack, "应该检测到script标签")
end)

test("检测 onerror事件", function()
    local is_attack = string_utils.contains_xss("<img src=x onerror=alert(1)>")
    assert_true(is_attack, "应该检测到onerror事件")
end)

test("检测 onload事件", function()
    local is_attack = string_utils.contains_xss("<body onload=alert(1)>")
    assert_true(is_attack, "应该检测到onload事件")
end)

test("检测 javascript:协议", function()
    local is_attack = string_utils.contains_xss('<a href="javascript:alert(1)">click</a>')
    assert_true(is_attack, "应该检测到javascript:协议")
end)

test("检测 iframe标签", function()
    local is_attack = string_utils.contains_xss("<iframe src='evil.com'>")
    assert_true(is_attack, "应该检测到iframe标签")
end)

test("检测 svg onload", function()
    local is_attack = string_utils.contains_xss("<svg onload=alert(1)>")
    assert_true(is_attack, "应该检测到svg onload")
end)

test("检测 onclick事件", function()
    local is_attack = string_utils.contains_xss("<div onclick=alert(1)>")
    assert_true(is_attack, "应该检测到onclick事件")
end)

test("检测 onmouseover事件", function()
    local is_attack = string_utils.contains_xss("<div onmouseover=alert(1)>")
    assert_true(is_attack, "应该检测到onmouseover事件")
end)

-- 函数调用
test("检测 alert函数", function()
    local is_attack = string_utils.contains_xss("<script>alert('xss')</script>")
    assert_true(is_attack, "应该检测到alert函数")
end)

test("检测 confirm函数", function()
    local is_attack = string_utils.contains_xss("<script>confirm(1)</script>")
    assert_true(is_attack, "应该检测到confirm函数")
end)

test("检测 prompt函数", function()
    local is_attack = string_utils.contains_xss("<script>prompt(1)</script>")
    assert_true(is_attack, "应该检测到prompt函数")
end)

test("检测 eval函数", function()
    local is_attack = string_utils.contains_xss("<script>eval('alert(1)')</script>")
    assert_true(is_attack, "应该检测到eval函数")
end)

-- 其他协议
test("检测 vbscript:协议", function()
    local is_attack = string_utils.contains_xss('<a href="vbscript:alert(1)">click</a>')
    assert_true(is_attack, "应该检测到vbscript:协议")
end)

test("检测 data:协议", function()
    local is_attack = string_utils.contains_xss('<iframe src="data:text/html,<script>alert(1)</script>">')
    assert_true(is_attack, "应该检测到data:协议")
end)

-- 负面测试
test("正常HTML不误报", function()
    local is_attack = string_utils.contains_xss("<div>Hello World</div>")
    assert_false(is_attack, "正常HTML不应误报")
end)

test("正常文本不误报", function()
    local is_attack = string_utils.contains_xss("This is normal text")
    assert_false(is_attack, "正常文本不应误报")
end)

test("正常URL不误报", function()
    local is_attack = string_utils.contains_xss("https://example.com")
    assert_false(is_attack, "正常URL不应误报")
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

