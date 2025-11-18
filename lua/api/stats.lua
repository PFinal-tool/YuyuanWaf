-- ============================================================================
-- 御渊WAF - 统计API
-- Version: 1.0.0
-- Description: 获取WAF统计信息
-- ============================================================================

local cjson = require "cjson.safe"
local cache = require "lib.cache"

local _M = {
    _VERSION = '1.0.0'
}

-- ============================================================================
-- 获取所有统计信息
-- ============================================================================
function _M.get_all_stats()
    local stats = cache.get_all_stats()
    
    -- 组织统计数据
    local result = {
        -- 攻击统计
        attacks = {
            sql_injection = stats["attack_sql_injection"] or 0,
            xss = stats["attack_xss"] or 0,
            command_injection = stats["attack_command_injection"] or 0,
            path_traversal = stats["attack_path_traversal"] or 0,
            file_inclusion = stats["attack_file_inclusion"] or 0,
            total = (stats["attack_sql_injection"] or 0) +
                   (stats["attack_xss"] or 0) +
                   (stats["attack_command_injection"] or 0) +
                   (stats["attack_path_traversal"] or 0) +
                   (stats["attack_file_inclusion"] or 0)
        },
        
        -- 频率限制
        rate_limit = {
            ip_blocked = stats["ratelimit_ip_blocked"] or 0,
            uri_blocked = stats["ratelimit_uri_blocked"] or 0,
            global_blocked = stats["ratelimit_global_blocked"] or 0,
            cc_detected = stats["cc_attack_detected"] or 0
        },
        
        -- IP过滤
        ip_filter = {
            blacklist_count = stats["blacklist_count"] or 0,
            whitelist_count = stats["whitelist_count"] or 0,
            blocked = stats["ip_blacklist_blocked"] or 0
        },
        
        -- 爬虫检测
        crawler = {
            detected = stats["crawler_detected"] or 0,
            good_bot = stats["crawler_good_bot"] or 0,
            blocked = stats["crawler_blocked"] or 0
        },
        
        -- 总计
        summary = {
            total_requests = stats["total_requests"] or 0,
            total_blocked = stats["total_blocked"] or 0,
            total_challenges = stats["total_challenges"] or 0,
            uptime = ngx.now() - (ngx.shared.waf_stats:get("start_time") or ngx.now())
        }
    }
    
    return result
end

-- ============================================================================
-- 获取实时QPS
-- ============================================================================
function _M.get_qps()
    local current_time = ngx.time()
    local window = 60  -- 1分钟窗口
    
    local total_requests = 0
    for i = 0, window - 1 do
        local key = "qps:" .. (current_time - i)
        local count = cache.get(key) or 0
        total_requests = total_requests + count
    end
    
    return {
        qps = math.floor(total_requests / window),
        window = window,
        total = total_requests
    }
end

-- ============================================================================
-- 获取Top攻击IP
-- ============================================================================
function _M.get_top_attack_ips(limit)
    limit = limit or 10
    
    local blacklist_dict = ngx.shared.waf_blacklist
    if not blacklist_dict then
        return {}
    end
    
    local ips = {}
    local keys = blacklist_dict:get_keys(1000)
    
    for _, key in ipairs(keys) do
        if key:match("^bl:") then
            local ip = key:sub(4)
            local reason = blacklist_dict:get(key)
            table.insert(ips, {
                ip = ip,
                reason = reason or "unknown",
                blocked_at = ngx.time()
            })
        end
        
        if #ips >= limit then
            break
        end
    end
    
    return ips
end

-- ============================================================================
-- 获取攻击趋势
-- ============================================================================
function _M.get_attack_trend(hours)
    hours = hours or 24
    
    local trend = {}
    local current_hour = math.floor(ngx.time() / 3600)
    
    for i = 0, hours - 1 do
        local hour = current_hour - i
        local key = "trend:attack:" .. hour
        local count = cache.get(key) or 0
        
        table.insert(trend, 1, {
            timestamp = hour * 3600,
            hour = os.date("%H:00", hour * 3600),
            attacks = count
        })
    end
    
    return trend
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
    
    -- 获取所有统计
    if uri == "/api/stats" and method == "GET" then
        local stats = _M.get_all_stats()
        _M.response(true, stats, "获取统计成功")
        
    -- 获取QPS
    elseif uri == "/api/stats/qps" and method == "GET" then
        local qps = _M.get_qps()
        _M.response(true, qps, "获取QPS成功")
        
    -- 获取Top攻击IP
    elseif uri == "/api/stats/top-ips" and method == "GET" then
        local args = ngx.req.get_uri_args()
        local limit = tonumber(args.limit) or 10
        local ips = _M.get_top_attack_ips(limit)
        _M.response(true, ips, "获取Top IP成功")
        
    -- 获取攻击趋势
    elseif uri == "/api/stats/trend" and method == "GET" then
        local args = ngx.req.get_uri_args()
        local hours = tonumber(args.hours) or 24
        local trend = _M.get_attack_trend(hours)
        _M.response(true, trend, "获取趋势成功")
        
    else
        _M.response(false, nil, "未知的API端点")
    end
end

return _M

