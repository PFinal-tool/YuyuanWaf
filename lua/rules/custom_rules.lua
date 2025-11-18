-- ============================================================================
-- 御渊WAF - 自定义规则
-- Version: 1.0.0
-- Description: 用户可以在这里添加自定义的检测规则
-- ============================================================================

local _M = {
    _VERSION = '1.0.0'
}

-- ============================================================================
-- 自定义规则示例
-- ============================================================================

-- 示例1：检查特定的恶意User-Agent
function _M.check_malicious_ua(ua)
    local malicious_uas = {
        "MaliciousBot",
        "EvilScanner",
        "AttackTool",
    }
    
    if not ua then
        return false
    end
    
    for _, mal_ua in ipairs(malicious_uas) do
        if ua:match(mal_ua) then
            return true, mal_ua
        end
    end
    
    return false
end

-- 示例2：检查特定的恶意IP段
function _M.check_malicious_ip_range(ip)
    -- 这里可以添加已知的恶意IP段
    -- 实际使用时应该集成威胁情报
    return false
end

-- 示例3：业务逻辑规则
function _M.check_business_logic(request)
    -- 示例：限制某些API只能从特定域名访问
    if request.uri:match("^/api/internal/") then
        local referer = request.referer or ""
        if not referer:match("yourdomain%.com") then
            return {
                is_attack = true,
                attack_type = "非法API访问",
                rule_id = "BUSINESS_LOGIC",
                reason = "内部API不允许外部访问"
            }
        end
    end
    
    return {is_attack = false}
end

-- ============================================================================
-- 主检查函数
-- ============================================================================
function _M.check(request)
    -- 可以在这里调用多个自定义规则
    
    -- 检查业务逻辑
    local business_result = _M.check_business_logic(request)
    if business_result.is_attack then
        return business_result
    end
    
    -- 可以添加更多自定义检查...
    
    return {is_attack = false}
end

return _M

