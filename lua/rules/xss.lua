-- ============================================================================
-- 御渊WAF - XSS攻击检测规则
-- Version: 1.0.0
-- ============================================================================

local string_utils = require "lib.string_utils"
local rule_engine = require "rules.rule_engine"

local _M = {
    _VERSION = '1.0.0'
}

-- ============================================================================
-- 检查XSS攻击
-- ============================================================================
function _M.check(request, config)
    -- 检查URI参数
    if config.check_args and request.args then
        for key, value in pairs(request.args) do
            local result = rule_engine.check_param(value, string_utils.contains_xss, "XSS攻击")
            if result.is_attack then
                result.rule_id = "XSS"
                result.location = "参数: " .. key
                return result
            end
        end
    end
    
    -- 检查POST参数
    if config.check_post and request.post_args then
        for key, value in pairs(request.post_args) do
            local result = rule_engine.check_param(value, string_utils.contains_xss, "XSS攻击")
            if result.is_attack then
                result.rule_id = "XSS"
                result.location = "POST参数: " .. key
                return result
            end
        end
    end
    
    -- 检查Referer头
    if request.referer then
        local is_attack, pattern = string_utils.contains_xss(request.referer)
        if is_attack then
            return {
                is_attack = true,
                attack_type = "XSS攻击",
                rule_id = "XSS",
                matched_pattern = pattern,
                location = "Referer"
            }
        end
    end
    
    return {is_attack = false}
end

return _M

