-- ============================================================================
-- 御渊WAF - 路径遍历检测规则
-- Version: 1.0.0
-- ============================================================================

local string_utils = require "lib.string_utils"
local rule_engine = require "rules.rule_engine"

local _M = {
    _VERSION = '1.0.0'
}

-- ============================================================================
-- 检查路径遍历
-- ============================================================================
function _M.check(request, config)
    -- 检查URI
    if config.check_uri then
        local is_attack, pattern = string_utils.contains_path_traversal(request.uri)
        if is_attack then
            return {
                is_attack = true,
                attack_type = "路径遍历",
                rule_id = "PATH_TRAVERSAL",
                matched_pattern = pattern,
                location = "URI"
            }
        end
    end
    
    -- 检查URI参数
    if config.check_args and request.args then
        for key, value in pairs(request.args) do
            local result = rule_engine.check_param(value, string_utils.contains_path_traversal, "路径遍历")
            if result.is_attack then
                result.rule_id = "PATH_TRAVERSAL"
                result.location = "参数: " .. key
                return result
            end
        end
    end
    
    return {is_attack = false}
end

return _M

