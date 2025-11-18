-- ============================================================================
-- 御渊WAF - 访问控制模块
-- Version: 1.0.0
-- Description: 请求检查和访问控制核心逻辑
-- ============================================================================

local _M = {
    _VERSION = '1.0.0'
}

-- ============================================================================
-- 主检查函数 - 按优先级执行各项检查
-- ============================================================================
function _M.check(request, config, modules)
    local result = {
        action = "allow",
        reason = "",
        rule_id = "",
        request_id = request.request_id,
        ip = request.real_ip,
        uri = request.uri,
        time = request.time
    }
    
    -- 1. 白名单检查 (最高优先级)
    if _M.check_whitelist(request, config) then
        result.action = "allow"
        result.reason = "白名单放行"
        return result
    end
    
    -- 2. IP黑名单检查
    if config.ip_filter and config.ip_filter.enabled then
        local ip_result = modules.ip_filter.check_blacklist(request.real_ip)
        if ip_result.blocked then
            result.action = "block"
            result.reason = "IP黑名单: " .. (ip_result.reason or "")
            result.rule_id = "IP_BLACKLIST"
            return result
        end
    end
    
    -- 3. GeoIP 地理位置检查
    if config.geoip and config.geoip.enabled then
        local geo_result = modules.geoip.check(request.real_ip, config.geoip)
        if geo_result.blocked then
            result.action = "block"
            result.reason = "地理位置限制: " .. (geo_result.country or "unknown")
            result.rule_id = "GEOIP_FILTER"
            result.country = geo_result.country
            return result
        end
    end
    
    -- 4. 频率限制检查
    if config.rate_limit and config.rate_limit.enabled then
        local rate_result = modules.rate_limit.check(request, config.rate_limit)
        if rate_result.limited then
            result.action = rate_result.action or "block"  -- block, challenge, captcha
            result.reason = "频率限制: " .. (rate_result.reason or "请求过快")
            result.rule_id = "RATE_LIMIT"
            result.rate_info = rate_result
            return result
        end
    end
    
    -- 5. 爬虫检测
    if config.anti_crawler and config.anti_crawler.enabled then
        local crawler_result = modules.anti_crawler.check(request, config.anti_crawler)
        if crawler_result.is_crawler then
            result.action = crawler_result.action or "block"
            result.reason = "爬虫检测: " .. (crawler_result.reason or "")
            result.rule_id = "ANTI_CRAWLER"
            result.crawler_score = crawler_result.score
            return result
        end
    end
    
    -- 6. 攻击规则检查
    if config.attack_defense and config.attack_defense.enabled then
        local attack_result = modules.rule_engine.check(request, config.attack_defense)
        if attack_result.is_attack then
            result.action = "block"
            result.reason = "攻击检测: " .. (attack_result.attack_type or "")
            result.rule_id = attack_result.rule_id or "ATTACK"
            result.attack_details = attack_result
            return result
        end
    end
    
    -- 7. CC攻击检查
    if config.cc_defense and config.cc_defense.enabled then
        local cc_result = modules.rate_limit.check_cc(request, config.cc_defense)
        if cc_result.is_cc then
            result.action = config.cc_defense.action or "challenge"
            result.reason = "CC攻击检测"
            result.rule_id = "CC_DEFENSE"
            return result
        end
    end
    
    -- 所有检查通过
    result.action = "allow"
    return result
end

-- ============================================================================
-- 白名单检查
-- ============================================================================
function _M.check_whitelist(request, config)
    if not config.whitelist then
        return false
    end
    
    -- IP白名单
    if config.whitelist.ips then
        local ip_utils = require "lib.ip_utils"
        for _, ip_pattern in ipairs(config.whitelist.ips) do
            if ip_utils.match(request.real_ip, ip_pattern) then
                return true
            end
        end
    end
    
    -- URI白名单
    if config.whitelist.uris then
        for _, uri_pattern in ipairs(config.whitelist.uris) do
            if ngx.re.match(request.uri, uri_pattern, "jo") then
                return true
            end
        end
    end
    
    -- User-Agent白名单 (合法爬虫)
    if config.whitelist.user_agents then
        for _, ua_pattern in ipairs(config.whitelist.user_agents) do
            if ngx.re.match(request.user_agent, ua_pattern, "jo") then
                return true
            end
        end
    end
    
    return false
end

return _M

