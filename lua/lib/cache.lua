-- ============================================================================
-- 御渊WAF - 缓存管理模块
-- Version: 1.0.0
-- Description: 缓存管理，支持shared_dict和Redis
-- ============================================================================

local _M = {
    _VERSION = '1.0.0'
}

-- 缓存配置
local cache_dict = nil
local redis_enabled = false
local redis_client = nil

-- ============================================================================
-- 初始化
-- ============================================================================
function _M.init()
    -- 初始化shared_dict
    cache_dict = ngx.shared.waf_cache
    if not cache_dict then
        ngx.log(ngx.ERR, "[Cache] 未找到waf_cache共享内存字典")
    end
    
    return true
end

-- ============================================================================
-- Shared Dict 操作
-- ============================================================================

-- 获取缓存
function _M.get(key)
    if not cache_dict then
        return nil
    end
    
    local value, flags = cache_dict:get(key)
    return value
end

-- 设置缓存
function _M.set(key, value, ttl)
    if not cache_dict then
        return false
    end
    
    ttl = ttl or 0  -- 0表示永不过期
    
    local success, err, forcible = cache_dict:set(key, value, ttl)
    
    if forcible then
        ngx.log(ngx.WARN, "[Cache] 缓存空间不足，强制删除旧条目")
    end
    
    if not success then
        ngx.log(ngx.ERR, "[Cache] 设置缓存失败: ", err)
        return false
    end
    
    return true
end

-- 删除缓存
function _M.delete(key)
    if not cache_dict then
        return false
    end
    
    cache_dict:delete(key)
    return true
end

-- 增加计数器
function _M.incr(key, step, init)
    if not cache_dict then
        return nil
    end
    
    step = step or 1
    init = init or 0
    
    local newval, err = cache_dict:incr(key, step, init)
    if not newval then
        ngx.log(ngx.ERR, "[Cache] 增加计数器失败: ", err)
        return nil
    end
    
    return newval
end

-- ============================================================================
-- 缓存键生成
-- ============================================================================

-- IP缓存键
function _M.get_ip_key(ip, prefix)
    prefix = prefix or "ip"
    return prefix .. ":" .. ip
end

-- 频率限制键
function _M.get_rate_limit_key(ip, uri)
    if uri then
        return "ratelimit:" .. ip .. ":" .. ngx.md5(uri)
    else
        return "ratelimit:" .. ip
    end
end

-- GeoIP缓存键
function _M.get_geoip_key(ip)
    return "geoip:" .. ip
end

-- 规则缓存键
function _M.get_rule_key(rule_id)
    return "rule:" .. rule_id
end

-- ============================================================================
-- 滑动窗口计数器
-- ============================================================================

-- 滑动窗口限流
function _M.sliding_window(key, limit, window)
    if not cache_dict then
        return false, 0
    end
    
    local current_time = ngx.time()
    local window_key = key .. ":" .. math.floor(current_time / window)
    
    -- 增加计数
    local count = cache_dict:incr(window_key, 1, 0)
    
    if not count then
        -- 初始化
        cache_dict:set(window_key, 1, window * 2)
        count = 1
    end
    
    -- 检查是否超限
    if count > limit then
        return true, count  -- 已限流
    end
    
    return false, count  -- 未限流
end

-- ============================================================================
-- 令牌桶算法
-- ============================================================================

-- 令牌桶限流
function _M.token_bucket(key, rate, capacity)
    if not cache_dict then
        return true  -- 缓存不可用，默认允许
    end
    
    local current_time = ngx.now()
    local bucket_key = "bucket:" .. key
    
    -- 获取桶状态
    local bucket_str = cache_dict:get(bucket_key)
    local tokens, last_time
    
    if bucket_str then
        -- 解析桶状态
        tokens, last_time = bucket_str:match("([^:]+):([^:]+)")
        tokens = tonumber(tokens)
        last_time = tonumber(last_time)
    else
        -- 初始化桶
        tokens = capacity
        last_time = current_time
    end
    
    -- 计算新增令牌
    local elapsed = current_time - last_time
    local new_tokens = math.floor(elapsed * rate)
    tokens = math.min(capacity, tokens + new_tokens)
    
    -- 消耗一个令牌
    if tokens >= 1 then
        tokens = tokens - 1
        -- 更新桶状态
        local new_bucket_str = tokens .. ":" .. current_time
        cache_dict:set(bucket_key, new_bucket_str, 3600)
        return false, tokens  -- 未限流
    else
        return true, 0  -- 已限流
    end
end

-- ============================================================================
-- 统计功能
-- ============================================================================

-- 增加统计计数
function _M.incr_stats(stat_name, step)
    step = step or 1
    local stats_dict = ngx.shared.waf_stats
    if not stats_dict then
        return
    end
    
    stats_dict:incr(stat_name, step, 0)
end

-- 获取统计数据
function _M.get_stats(stat_name)
    local stats_dict = ngx.shared.waf_stats
    if not stats_dict then
        return 0
    end
    
    return stats_dict:get(stat_name) or 0
end

-- 获取所有统计数据
function _M.get_all_stats()
    local stats_dict = ngx.shared.waf_stats
    if not stats_dict then
        return {}
    end
    
    local stats = {}
    local keys = stats_dict:get_keys(1000)
    
    for _, key in ipairs(keys) do
        stats[key] = stats_dict:get(key)
    end
    
    return stats
end

-- 刷新统计数据 (定时任务)
function _M.flush_stats()
    -- 这里可以将统计数据刷新到Redis或数据库
    -- 暂时保留为空实现
end

-- ============================================================================
-- 清理过期缓存
-- ============================================================================

function _M.cleanup_expired()
    if not cache_dict then
        return
    end
    
    -- shared_dict会自动清理过期数据
    -- 这里可以添加额外的清理逻辑
    ngx.log(ngx.DEBUG, "[Cache] 执行缓存清理")
    
    cache_dict:flush_expired()
end

-- ============================================================================
-- 黑名单缓存
-- ============================================================================

-- 添加IP到黑名单
function _M.add_to_blacklist(ip, ttl, reason)
    local blacklist_dict = ngx.shared.waf_blacklist
    if not blacklist_dict then
        return false
    end
    
    ttl = ttl or 3600
    reason = reason or "unknown"
    
    local key = "bl:" .. ip
    blacklist_dict:set(key, reason, ttl)
    
    -- 增加统计
    _M.incr_stats("blacklist_count", 1)
    
    return true
end

-- 检查IP是否在黑名单
function _M.is_in_blacklist(ip)
    local blacklist_dict = ngx.shared.waf_blacklist
    if not blacklist_dict then
        return false, nil
    end
    
    local key = "bl:" .. ip
    local reason = blacklist_dict:get(key)
    
    if reason then
        return true, reason
    end
    
    return false, nil
end

-- 从黑名单移除IP
function _M.remove_from_blacklist(ip)
    local blacklist_dict = ngx.shared.waf_blacklist
    if not blacklist_dict then
        return false
    end
    
    local key = "bl:" .. ip
    blacklist_dict:delete(key)
    
    return true
end

-- ============================================================================
-- Redis支持 (可选)
-- ============================================================================

function _M.init_redis(config)
    redis_enabled = config.enabled or false
    if redis_enabled then
        redis_client = require "lib.redis_client"
        redis_client.init(config)
    end
end

function _M.get_from_redis(key)
    if not redis_enabled or not redis_client then
        return nil
    end
    
    return redis_client.get(key)
end

function _M.set_to_redis(key, value, ttl)
    if not redis_enabled or not redis_client then
        return false
    end
    
    return redis_client.set(key, value, ttl)
end

return _M

