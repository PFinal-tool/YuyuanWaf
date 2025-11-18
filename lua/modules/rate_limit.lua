-- ============================================================================
-- 御渊WAF - 频率限制模块
-- Version: 1.0.0
-- Description: 多维度频率限制和CC攻击防护
-- ============================================================================

local cache = require "lib.cache"

local _M = {
    _VERSION = '1.0.0'
}

local config = nil

-- ============================================================================
-- 初始化
-- ============================================================================
function _M.init(waf_config)
    config = waf_config or {}
    ngx.log(ngx.INFO, "[RateLimit] 频率限制模块初始化完成")
end

-- ============================================================================
-- 检查频率限制
-- ============================================================================
function _M.check(request, rate_config)
    if not rate_config then
        return {limited = false}
    end
    
    local ip = request.real_ip
    local uri = request.uri
    
    -- 1. 检查单IP限制
    if rate_config.per_ip and rate_config.per_ip.enabled then
        local ip_result = _M.check_per_ip(ip, rate_config.per_ip)
        if ip_result.limited then
            cache.incr_stats("ratelimit_ip_blocked")
            return ip_result
        end
    end
    
    -- 2. 检查单URI限制
    if rate_config.per_uri and rate_config.per_uri.enabled then
        local uri_result = _M.check_per_uri(uri, rate_config.per_uri)
        if uri_result.limited then
            cache.incr_stats("ratelimit_uri_blocked")
            return uri_result
        end
    end
    
    -- 3. 检查全局限制
    if rate_config.global and rate_config.global.enabled then
        local global_result = _M.check_global(rate_config.global)
        if global_result.limited then
            cache.incr_stats("ratelimit_global_blocked")
            return global_result
        end
    end
    
    return {limited = false}
end

-- ============================================================================
-- 单IP频率限制
-- ============================================================================
function _M.check_per_ip(ip, config)
    local rate = config.rate or 10
    local burst = config.burst or 20
    local window = config.window or 1
    
    -- 使用令牌桶算法
    local key = cache.get_rate_limit_key(ip)
    local limited, tokens = cache.token_bucket(key, rate, burst)
    
    if limited then
        -- 检查是否需要临时封禁
        _M.check_auto_ban(ip)
        
        return {
            limited = true,
            reason = string.format("IP频率限制: %d req/s", rate),
            action = "block",
            rate = rate,
            remaining = 0
        }
    end
    
    return {
        limited = false,
        remaining = tokens
    }
end

-- ============================================================================
-- 单URI频率限制
-- ============================================================================
function _M.check_per_uri(uri, config)
    local rate = config.rate or 100
    local burst = config.burst or 200
    
    local key = "ratelimit:uri:" .. ngx.md5(uri)
    local limited, tokens = cache.token_bucket(key, rate, burst)
    
    if limited then
        return {
            limited = true,
            reason = string.format("URI频率限制: %s", uri),
            action = "block",
            rate = rate
        }
    end
    
    return {limited = false}
end

-- ============================================================================
-- 全局频率限制
-- ============================================================================
function _M.check_global(config)
    local rate = config.rate or 1000
    local burst = config.burst or 2000
    
    local key = "ratelimit:global"
    local limited, tokens = cache.token_bucket(key, rate, burst)
    
    if limited then
        return {
            limited = true,
            reason = "全局频率限制",
            action = "block",
            rate = rate
        }
    end
    
    return {limited = false}
end

-- ============================================================================
-- CC攻击检测
-- ============================================================================
function _M.check_cc(request, cc_config)
    if not cc_config or not cc_config.enabled then
        return {is_cc = false}
    end
    
    local ip = request.real_ip
    local threshold = cc_config.threshold or 10000
    local window = cc_config.window or 10
    
    -- 统计IP请求数
    local key = "cc:count:" .. ip
    local count = cache.incr(key, 1, 0)
    
    if count == 1 then
        cache.set(key, 1, window)
    end
    
    -- 计算QPS
    local qps = count / window
    
    if qps > threshold then
        cache.incr_stats("cc_attack_detected")
        
        -- 自动封禁
        if cc_config.auto_ban and cc_config.auto_ban.enabled then
            local ban_duration = cc_config.auto_ban.duration or 3600
            local ip_filter = require "modules.ip_filter"
            ip_filter.add_to_blacklist(ip, ban_duration, "CC攻击")
        end
        
        return {
            is_cc = true,
            reason = string.format("CC攻击检测: QPS %.2f", qps),
            qps = qps,
            threshold = threshold
        }
    end
    
    return {is_cc = false, qps = qps}
end

-- ============================================================================
-- 自动封禁检查
-- ============================================================================
function _M.check_auto_ban(ip)
    -- 统计违规次数
    local violation_key = "ratelimit:violation:" .. ip
    local violations = cache.incr(violation_key, 1, 0)
    
    if violations == 1 then
        cache.set(violation_key, 1, 300)  -- 5分钟窗口
    end
    
    -- 如果5分钟内违规超过10次，临时封禁
    if violations >= 10 then
        local ip_filter = require "modules.ip_filter"
        ip_filter.add_to_blacklist(ip, 1800, "频繁违反频率限制")  -- 封禁30分钟
        
        -- 重置违规计数
        cache.delete(violation_key)
        
        ngx.log(ngx.WARN, "[RateLimit] 自动封禁IP: ", ip, " 原因: 频繁违规")
    end
end

-- ============================================================================
-- 滑动窗口限流
-- ============================================================================
function _M.sliding_window_limit(key, limit, window)
    return cache.sliding_window(key, limit, window)
end

-- ============================================================================
-- 令牌桶限流
-- ============================================================================
function _M.token_bucket_limit(key, rate, capacity)
    return cache.token_bucket(key, rate, capacity)
end

-- ============================================================================
-- 清除IP的频率限制记录
-- ============================================================================
function _M.reset_ip_limit(ip)
    local keys = {
        cache.get_rate_limit_key(ip),
        "ratelimit:violation:" .. ip,
        "cc:count:" .. ip,
    }
    
    for _, key in ipairs(keys) do
        cache.delete(key)
    end
    
    ngx.log(ngx.INFO, "[RateLimit] 重置IP频率限制: ", ip)
end

-- ============================================================================
-- 获取IP的当前频率统计
-- ============================================================================
function _M.get_ip_rate_stats(ip)
    local rate_key = cache.get_rate_limit_key(ip)
    local cc_key = "cc:count:" .. ip
    local violation_key = "ratelimit:violation:" .. ip
    
    return {
        tokens = cache.get(rate_key),
        cc_count = cache.get(cc_key) or 0,
        violations = cache.get(violation_key) or 0,
    }
end

-- ============================================================================
-- 获取统计信息
-- ============================================================================
function _M.get_stats()
    return {
        ip_blocked = cache.get_stats("ratelimit_ip_blocked") or 0,
        uri_blocked = cache.get_stats("ratelimit_uri_blocked") or 0,
        global_blocked = cache.get_stats("ratelimit_global_blocked") or 0,
        cc_detected = cache.get_stats("cc_attack_detected") or 0,
    }
end

-- ============================================================================
-- 动态调整限流阈值 (可扩展)
-- ============================================================================
function _M.adjust_threshold(ip, multiplier)
    -- 根据IP信誉或行为动态调整限流阈值
    -- 这是一个扩展点，可以集成机器学习模型
    multiplier = multiplier or 1.0
    
    local adjust_key = "ratelimit:adjust:" .. ip
    cache.set(adjust_key, multiplier, 3600)
    
    return true
end

function _M.get_threshold_multiplier(ip)
    local adjust_key = "ratelimit:adjust:" .. ip
    local multiplier = cache.get(adjust_key)
    return tonumber(multiplier) or 1.0
end

return _M

