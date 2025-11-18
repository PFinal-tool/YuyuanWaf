-- ============================================================================
-- 御渊WAF - 文件包含检测规则
-- Version: 1.0.0
-- ============================================================================

local string_utils = require "lib.string_utils"
local rule_engine = require "rules.rule_engine"

local _M = {
    _VERSION = '1.0.0'
}

-- 文件包含特征
local function check_file_inclusion(str)
    if not str or str == "" then
        return false
    end
    
    local patterns = {
        "%.%./",
        "%.%.\\",
        "php://",
        "file://",
        "data://",
        "expect://",
        "zip://",
        "phar://",
    }
    
    local lower_str = str:lower()
    for _, pattern in ipairs(patterns) do
        if lower_str:match(pattern) then
            return true, pattern
        end
    end
    
    return false
end

-- ============================================================================
-- 检查文件包含
-- ============================================================================
function _M.check(request, config)
    -- 检查URI参数
    if config.check_args and request.args then
        for key, value in pairs(request.args) do
            local result = rule_engine.check_param(value, check_file_inclusion, "文件包含")
            if result.is_attack then
                result.rule_id = "FILE_INCLUSION"
                result.location = "参数: " .. key
                return result
            end
        end
    end
    
    return {is_attack = false}
end

return _M

