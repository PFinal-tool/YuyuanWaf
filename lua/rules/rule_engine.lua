-- ============================================================================
-- 御渊WAF - 规则引擎
-- Version: 1.0.0
-- Description: 规则匹配和攻击检测核心
-- ============================================================================

local string_utils = require "lib.string_utils"
local cache = require "lib.cache"

local _M = {
    _VERSION = '1.0.0'
}

local config = nil
local rules = {}

-- ============================================================================
-- 初始化
-- ============================================================================
function _M.init(waf_config)
    config = waf_config or {}
    
    -- 加载各类攻击检测规则
    if config.attack_defense then
        _M.load_attack_rules(config.attack_defense)
    end
    
    ngx.log(ngx.INFO, "[RuleEngine] 规则引擎初始化完成")
end

-- ============================================================================
-- 加载攻击规则
-- ============================================================================
function _M.load_attack_rules(attack_config)
    rules = {
        sql_injection = require "rules.sql_injection",
        xss = require "rules.xss",
        command_injection = require "rules.command_injection",
        file_inclusion = require "rules.file_inclusion",
        path_traversal = require "rules.path_traversal",
    }
    
    ngx.log(ngx.INFO, "[RuleEngine] 加载攻击规则完成")
end

-- ============================================================================
-- 检查请求
-- ============================================================================
function _M.check(request, attack_config)
    if not attack_config or not attack_config.enabled then
        return {is_attack = false}
    end
    
    -- 1. SQL注入检测
    if attack_config.sql_injection and attack_config.sql_injection.enabled then
        local sqli_result = rules.sql_injection.check(request, attack_config.sql_injection)
        if sqli_result.is_attack then
            cache.incr_stats("attack_sqli_blocked")
            return sqli_result
        end
    end
    
    -- 2. XSS检测
    if attack_config.xss and attack_config.xss.enabled then
        local xss_result = rules.xss.check(request, attack_config.xss)
        if xss_result.is_attack then
            cache.incr_stats("attack_xss_blocked")
            return xss_result
        end
    end
    
    -- 3. 命令注入检测
    if attack_config.command_injection and attack_config.command_injection.enabled then
        local cmd_result = rules.command_injection.check(request, attack_config.command_injection)
        if cmd_result.is_attack then
            cache.incr_stats("attack_cmd_blocked")
            return cmd_result
        end
    end
    
    -- 4. 文件包含检测
    if attack_config.file_inclusion and attack_config.file_inclusion.enabled then
        local fi_result = rules.file_inclusion.check(request, attack_config.file_inclusion)
        if fi_result.is_attack then
            cache.incr_stats("attack_file_blocked")
            return fi_result
        end
    end
    
    -- 5. 路径遍历检测
    if attack_config.path_traversal and attack_config.path_traversal.enabled then
        local pt_result = rules.path_traversal.check(request, attack_config.path_traversal)
        if pt_result.is_attack then
            cache.incr_stats("attack_path_blocked")
            return pt_result
        end
    end
    
    -- 6. 敏感文件访问检测
    if attack_config.sensitive_file and attack_config.sensitive_file.enabled then
        local sf_result = _M.check_sensitive_file(request, attack_config.sensitive_file)
        if sf_result.is_attack then
            cache.incr_stats("attack_sensitive_file_blocked")
            return sf_result
        end
    end
    
    return {is_attack = false}
end

-- ============================================================================
-- 敏感文件访问检测
-- ============================================================================
function _M.check_sensitive_file(request, config)
    local uri = request.uri:lower()
    
    if config.extensions then
        for _, ext in ipairs(config.extensions) do
            if string_utils.ends_with(uri, ext) then
                return {
                    is_attack = true,
                    attack_type = "敏感文件访问",
                    rule_id = "SENSITIVE_FILE",
                    matched_pattern = ext,
                    location = "URI"
                }
            end
        end
    end
    
    return {is_attack = false}
end

-- ============================================================================
-- 检查参数
-- ============================================================================
function _M.check_param(value, check_function, rule_name)
    if not value or value == "" then
        return {is_attack = false}
    end
    
    -- 如果是表，递归检查每个值
    if type(value) == "table" then
        for _, v in pairs(value) do
            local result = _M.check_param(v, check_function, rule_name)
            if result.is_attack then
                return result
            end
        end
        return {is_attack = false}
    end
    
    -- 检查值
    local is_attack, pattern = check_function(tostring(value))
    if is_attack then
        return {
            is_attack = true,
            attack_type = rule_name,
            matched_pattern = pattern,
            matched_value = tostring(value):sub(1, 100)  -- 限制长度
        }
    end
    
    return {is_attack = false}
end

-- ============================================================================
-- 获取统计信息
-- ============================================================================
function _M.get_stats()
    return {
        sqli_blocked = cache.get_stats("attack_sqli_blocked") or 0,
        xss_blocked = cache.get_stats("attack_xss_blocked") or 0,
        cmd_blocked = cache.get_stats("attack_cmd_blocked") or 0,
        file_blocked = cache.get_stats("attack_file_blocked") or 0,
        path_blocked = cache.get_stats("attack_path_blocked") or 0,
        sensitive_file_blocked = cache.get_stats("attack_sensitive_file_blocked") or 0,
    }
end

return _M

