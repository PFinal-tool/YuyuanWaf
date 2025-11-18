-- ============================================================================
-- 御渊WAF - 管理API
-- Version: 1.0.0
-- Description: WAF管理接口 (IP黑白名单、规则管理等)
-- ============================================================================

local cjson = require "cjson.safe"
local cache = require "lib.cache"

local _M = {
    _VERSION = '1.0.0'
}

-- ============================================================================
-- IP黑名单管理
-- ============================================================================

-- 添加IP到黑名单
function _M.add_blacklist(ip, duration, reason)
    if not ip then
        return false, "IP地址不能为空"
    end
    
    duration = duration or 3600  -- 默认1小时
    reason = reason or "手动添加"
    
    local ip_utils = require "lib.ip_utils"
    if not ip_utils.validate_ip(ip) then
        return false, "无效的IP地址"
    end
    
    local success = cache.add_to_blacklist(ip, duration, reason)
    if success then
        ngx.log(ngx.INFO, "[API] 添加IP到黑名单: ", ip, " 原因: ", reason)
        return true, "添加成功"
    else
        return false, "添加失败"
    end
end

-- 从黑名单移除IP
function _M.remove_blacklist(ip)
    if not ip then
        return false, "IP地址不能为空"
    end
    
    local success = cache.remove_from_blacklist(ip)
    if success then
        ngx.log(ngx.INFO, "[API] 从黑名单移除IP: ", ip)
        return true, "移除成功"
    else
        return false, "移除失败"
    end
end

-- 检查IP是否在黑名单
function _M.check_blacklist(ip)
    if not ip then
        return false, "IP地址不能为空"
    end
    
    local in_blacklist, reason = cache.is_in_blacklist(ip)
    return in_blacklist, {
        ip = ip,
        in_blacklist = in_blacklist,
        reason = reason
    }
end

-- 获取黑名单列表
function _M.list_blacklist(limit, offset)
    limit = limit or 100
    offset = offset or 0
    
    local blacklist_dict = ngx.shared.waf_blacklist
    if not blacklist_dict then
        return {}
    end
    
    local list = {}
    local keys = blacklist_dict:get_keys(1000)
    
    for i = offset + 1, math.min(offset + limit, #keys) do
        local key = keys[i]
        if key and key:match("^bl:") then
            local ip = key:sub(4)
            local reason = blacklist_dict:get(key)
            table.insert(list, {
                ip = ip,
                reason = reason or "unknown"
            })
        end
    end
    
    return list
end

-- ============================================================================
-- 频率限制管理
-- ============================================================================

-- 重置IP的频率限制
function _M.reset_rate_limit(ip)
    if not ip then
        return false, "IP地址不能为空"
    end
    
    local rate_limit = require "modules.rate_limit"
    rate_limit.reset_ip_limit(ip)
    
    ngx.log(ngx.INFO, "[API] 重置IP频率限制: ", ip)
    return true, "重置成功"
end

-- 获取IP的频率统计
function _M.get_rate_stats(ip)
    if not ip then
        return false, "IP地址不能为空"
    end
    
    local rate_limit = require "modules.rate_limit"
    local stats = rate_limit.get_ip_rate_stats(ip)
    
    return true, {
        ip = ip,
        stats = stats
    }
end

-- ============================================================================
-- 配置管理
-- ============================================================================

-- 获取当前配置
function _M.get_config()
    local config = require "config"
    
    -- 返回配置的只读副本
    return true, {
        mode = config.mode,
        ip_filter = config.ip_filter,
        rate_limit = config.rate_limit,
        anti_crawler = config.anti_crawler,
        attack_defense = config.attack_defense
    }
end

-- 更新运行模式
function _M.set_mode(mode)
    local valid_modes = {off = true, detection = true, protection = true}
    
    if not valid_modes[mode] then
        return false, "无效的模式，有效值: off, detection, protection"
    end
    
    local config = require "config"
    config.mode = mode
    
    ngx.log(ngx.WARN, "[API] WAF模式已更改为: ", mode)
    return true, "模式已更新为: " .. mode
end

-- ============================================================================
-- 日志查询
-- ============================================================================

-- 查询攻击日志
function _M.query_attack_logs(limit, offset)
    limit = limit or 100
    offset = offset or 0
    
    -- 这里需要实现日志读取逻辑
    -- 暂时返回空数组
    return true, {
        logs = {},
        total = 0,
        limit = limit,
        offset = offset
    }
end

-- ============================================================================
-- 缓存管理
-- ============================================================================

-- 清理缓存
function _M.flush_cache()
    cache.cleanup_expired()
    ngx.log(ngx.INFO, "[API] 缓存清理完成")
    return true, "缓存已清理"
end

-- 获取缓存信息
function _M.get_cache_info()
    local cache_dict = ngx.shared.waf_cache
    local blacklist_dict = ngx.shared.waf_blacklist
    local stats_dict = ngx.shared.waf_stats
    
    return true, {
        cache = {
            capacity = cache_dict:capacity() or 0,
            free_space = cache_dict:free_space() or 0
        },
        blacklist = {
            capacity = blacklist_dict:capacity() or 0,
            free_space = blacklist_dict:free_space() or 0
        },
        stats = {
            capacity = stats_dict:capacity() or 0,
            free_space = stats_dict:free_space() or 0
        }
    }
end

-- ============================================================================
-- HTTP响应封装
-- ============================================================================
function _M.response(success, data, message)
    local result = {
        success = success,
        data = data or {},
        message = message or "",
        timestamp = ngx.time()
    }
    
    ngx.header["Content-Type"] = "application/json; charset=utf-8"
    ngx.say(cjson.encode(result))
    ngx.exit(ngx.HTTP_OK)
end

-- ============================================================================
-- 处理API请求
-- ============================================================================
function _M.handle()
    local uri = ngx.var.uri
    local method = ngx.var.request_method
    
    -- 获取请求参数
    local args = ngx.req.get_uri_args()
    
    -- 黑名单管理
    if uri == "/api/blacklist/add" and method == "POST" then
        ngx.req.read_body()
        local body_data = ngx.req.get_body_data()
        local body = cjson.decode(body_data or "{}")
        
        local success, msg = _M.add_blacklist(body.ip, body.duration, body.reason)
        _M.response(success, nil, msg)
        
    elseif uri == "/api/blacklist/remove" and method == "POST" then
        ngx.req.read_body()
        local body_data = ngx.req.get_body_data()
        local body = cjson.decode(body_data or "{}")
        
        local success, msg = _M.remove_blacklist(body.ip)
        _M.response(success, nil, msg)
        
    elseif uri == "/api/blacklist/check" and method == "GET" then
        local ip = args.ip
        local in_list, data = _M.check_blacklist(ip)
        _M.response(true, data, "查询成功")
        
    elseif uri == "/api/blacklist/list" and method == "GET" then
        local limit = tonumber(args.limit) or 100
        local offset = tonumber(args.offset) or 0
        local list = _M.list_blacklist(limit, offset)
        _M.response(true, {items = list, total = #list}, "获取列表成功")
        
    -- 频率限制管理
    elseif uri == "/api/ratelimit/reset" and method == "POST" then
        ngx.req.read_body()
        local body_data = ngx.req.get_body_data()
        local body = cjson.decode(body_data or "{}")
        
        local success, msg = _M.reset_rate_limit(body.ip)
        _M.response(success, nil, msg)
        
    elseif uri == "/api/ratelimit/stats" and method == "GET" then
        local ip = args.ip
        local success, data = _M.get_rate_stats(ip)
        _M.response(success, data, "获取统计成功")
        
    -- 配置管理
    elseif uri == "/api/config" and method == "GET" then
        local success, data = _M.get_config()
        _M.response(success, data, "获取配置成功")
        
    elseif uri == "/api/config/mode" and method == "POST" then
        ngx.req.read_body()
        local body_data = ngx.req.get_body_data()
        local body = cjson.decode(body_data or "{}")
        
        local success, msg = _M.set_mode(body.mode)
        _M.response(success, nil, msg)
        
    -- 缓存管理
    elseif uri == "/api/cache/flush" and method == "POST" then
        local success, msg = _M.flush_cache()
        _M.response(success, nil, msg)
        
    elseif uri == "/api/cache/info" and method == "GET" then
        local success, data = _M.get_cache_info()
        _M.response(success, data, "获取缓存信息成功")
        
    else
        _M.response(false, nil, "未知的API端点")
    end
end

return _M

