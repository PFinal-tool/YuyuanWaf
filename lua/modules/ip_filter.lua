-- ============================================================================
-- 御渊WAF - IP过滤模块
-- Version: 1.0.0
-- Description: IP黑白名单管理和过滤
-- ============================================================================

local ip_utils = require "lib.ip_utils"
local cache = require "lib.cache"
local utils = require "lib.utils"

local _M = {
    _VERSION = '1.0.0'
}

-- IP黑白名单缓存
local blacklist = {}
local whitelist = {}
local config = nil

-- ============================================================================
-- 初始化
-- ============================================================================
function _M.init(waf_config)
    config = waf_config or {}
    
    -- 加载黑名单
    if config.blacklist_file then
        _M.load_blacklist(config.blacklist_file)
    end
    
    -- 加载白名单
    if config.whitelist_file then
        _M.load_whitelist(config.whitelist_file)
    end
    
    ngx.log(ngx.INFO, "[IPFilter] IP过滤模块初始化完成")
    ngx.log(ngx.INFO, "[IPFilter] 黑名单规则数: ", #blacklist)
    ngx.log(ngx.INFO, "[IPFilter] 白名单规则数: ", #whitelist)
end

-- ============================================================================
-- 加载黑名单
-- ============================================================================
function _M.load_blacklist(filepath)
    local waf_path = config and config.waf_path or "/usr/local/YuyuanWaf/"
    local full_path = waf_path .. filepath
    
    if not utils.file_exists(full_path) then
        ngx.log(ngx.WARN, "[IPFilter] 黑名单文件不存在: ", full_path)
        return false
    end
    
    local lines, err = utils.read_file_lines(full_path)
    if not lines then
        ngx.log(ngx.ERR, "[IPFilter] 加载黑名单失败: ", err)
        return false
    end
    
    blacklist = lines
    ngx.log(ngx.INFO, "[IPFilter] 加载黑名单成功，共 ", #blacklist, " 条规则")
    return true
end

-- ============================================================================
-- 加载白名单
-- ============================================================================
function _M.load_whitelist(filepath)
    local waf_path = config and config.waf_path or "/usr/local/YuyuanWaf/"
    local full_path = waf_path .. filepath
    
    if not utils.file_exists(full_path) then
        ngx.log(ngx.WARN, "[IPFilter] 白名单文件不存在: ", full_path)
        return false
    end
    
    local lines, err = utils.read_file_lines(full_path)
    if not lines then
        ngx.log(ngx.ERR, "[IPFilter] 加载白名单失败: ", err)
        return false
    end
    
    whitelist = lines
    ngx.log(ngx.INFO, "[IPFilter] 加载白名单成功，共 ", #whitelist, " 条规则")
    return true
end

-- ============================================================================
-- 检查IP是否在黑名单
-- ============================================================================
function _M.check_blacklist(ip)
    if not ip then
        return {blocked = false}
    end
    
    -- 先检查缓存
    local cache_key = cache.get_ip_key(ip, "blacklist")
    local cached = cache.get(cache_key)
    if cached then
        if cached == "blocked" then
            return {blocked = true, reason = "IP黑名单(缓存)", cached = true}
        else
            return {blocked = false, cached = true}
        end
    end
    
    -- 检查动态黑名单 (shared_dict)
    local is_banned, reason = cache.is_in_blacklist(ip)
    if is_banned then
        return {blocked = true, reason = reason or "动态封禁"}
    end
    
    -- 检查静态黑名单文件
    if #blacklist > 0 then
        if ip_utils.match_list(ip, blacklist) then
            -- 缓存结果
            cache.set(cache_key, "blocked", config.cache_ttl or 3600)
            cache.incr_stats("ip_blacklist_hit")
            return {blocked = true, reason = "IP黑名单"}
        end
    end
    
    -- 缓存未命中结果
    cache.set(cache_key, "allowed", 300)  -- 短时间缓存
    
    return {blocked = false}
end

-- ============================================================================
-- 检查IP是否在白名单
-- ============================================================================
function _M.check_whitelist(ip)
    if not ip then
        return false
    end
    
    -- 先检查缓存
    local cache_key = cache.get_ip_key(ip, "whitelist")
    local cached = cache.get(cache_key)
    if cached then
        return cached == "allowed"
    end
    
    -- 检查白名单
    if #whitelist > 0 then
        if ip_utils.match_list(ip, whitelist) then
            -- 缓存结果
            cache.set(cache_key, "allowed", config.cache_ttl or 3600)
            cache.incr_stats("ip_whitelist_hit")
            return true
        end
    end
    
    -- 缓存未命中结果
    cache.set(cache_key, "not_in_whitelist", 300)
    
    return false
end

-- ============================================================================
-- 动态添加IP到黑名单
-- ============================================================================
function _M.add_to_blacklist(ip, ttl, reason)
    if not ip then
        return false
    end
    
    ttl = ttl or 3600  -- 默认1小时
    reason = reason or "动态封禁"
    
    -- 添加到共享内存黑名单
    cache.add_to_blacklist(ip, ttl, reason)
    
    -- 清除缓存
    local cache_key = cache.get_ip_key(ip, "blacklist")
    cache.delete(cache_key)
    
    ngx.log(ngx.WARN, "[IPFilter] 添加IP到黑名单: ", ip, " 原因: ", reason, " 时长: ", ttl, "秒")
    
    return true
end

-- ============================================================================
-- 从黑名单移除IP
-- ============================================================================
function _M.remove_from_blacklist(ip)
    if not ip then
        return false
    end
    
    cache.remove_from_blacklist(ip)
    
    -- 清除缓存
    local cache_key = cache.get_ip_key(ip, "blacklist")
    cache.delete(cache_key)
    
    ngx.log(ngx.INFO, "[IPFilter] 从黑名单移除IP: ", ip)
    
    return true
end

-- ============================================================================
-- 添加IP到白名单 (临时)
-- ============================================================================
function _M.add_to_whitelist(ip, ttl)
    if not ip then
        return false
    end
    
    ttl = ttl or 3600
    
    local cache_key = cache.get_ip_key(ip, "whitelist")
    cache.set(cache_key, "allowed", ttl)
    
    ngx.log(ngx.INFO, "[IPFilter] 添加IP到临时白名单: ", ip, " 时长: ", ttl, "秒")
    
    return true
end

-- ============================================================================
-- 获取黑名单统计
-- ============================================================================
function _M.get_blacklist_stats()
    return {
        static_count = #blacklist,
        dynamic_count = cache.get_stats("blacklist_count") or 0,
        hits = cache.get_stats("ip_blacklist_hit") or 0,
    }
end

-- ============================================================================
-- 获取白名单统计
-- ============================================================================
function _M.get_whitelist_stats()
    return {
        count = #whitelist,
        hits = cache.get_stats("ip_whitelist_hit") or 0,
    }
end

-- ============================================================================
-- 重新加载规则
-- ============================================================================
function _M.reload()
    ngx.log(ngx.INFO, "[IPFilter] 重新加载IP规则...")
    
    if config.blacklist_file then
        _M.load_blacklist(config.blacklist_file)
    end
    
    if config.whitelist_file then
        _M.load_whitelist(config.whitelist_file)
    end
    
    return true
end

return _M

