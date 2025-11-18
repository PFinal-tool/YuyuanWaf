-- ============================================================================
-- 御渊WAF - API路由
-- Version: 1.0.0
-- Description: API请求路由和认证
-- ============================================================================

local _M = {
    _VERSION = '1.0.0'
}

-- ============================================================================
-- 简单的API认证 (生产环境应使用更强的认证机制)
-- ============================================================================
function _M.authenticate()
    -- 检查API Token
    local token = ngx.var.http_x_api_token or ngx.req.get_uri_args().token
    
    -- TODO: 实现真正的Token验证
    -- 这里暂时允许所有请求通过
    -- 生产环境应该：
    -- 1. 验证JWT Token
    -- 2. 检查IP白名单
    -- 3. 使用API Key
    
    if not token and ngx.var.remote_addr ~= "127.0.0.1" then
        ngx.header["Content-Type"] = "application/json; charset=utf-8"
        ngx.status = ngx.HTTP_UNAUTHORIZED
        ngx.say('{"success":false,"message":"未授权的访问，需要API Token"}')
        ngx.exit(ngx.HTTP_UNAUTHORIZED)
    end
    
    return true
end

-- ============================================================================
-- CORS处理
-- ============================================================================
function _M.handle_cors()
    -- 允许跨域访问 (开发环境)
    -- 生产环境应该限制允许的域名
    ngx.header["Access-Control-Allow-Origin"] = "*"
    ngx.header["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS"
    ngx.header["Access-Control-Allow-Headers"] = "Content-Type, X-API-Token"
    ngx.header["Access-Control-Max-Age"] = "3600"
    
    if ngx.var.request_method == "OPTIONS" then
        ngx.exit(ngx.HTTP_OK)
    end
end

-- ============================================================================
-- 路由分发
-- ============================================================================
function _M.route()
    local uri = ngx.var.uri
    
    -- 处理CORS
    _M.handle_cors()
    
    -- 认证检查
    _M.authenticate()
    
    -- 路由到不同的API模块
    if uri:match("^/api/stats") then
        local stats_api = require "api.stats"
        stats_api.handle()
        
    elseif uri:match("^/api/blacklist") or
           uri:match("^/api/ratelimit") or
           uri:match("^/api/config") or
           uri:match("^/api/cache") then
        local mgmt_api = require "api.management"
        mgmt_api.handle()
        
    elseif uri == "/api/health" then
        -- 健康检查端点
        ngx.header["Content-Type"] = "application/json; charset=utf-8"
        ngx.say('{"success":true,"status":"ok","timestamp":' .. ngx.time() .. '}')
        ngx.exit(ngx.HTTP_OK)
        
    elseif uri == "/api" or uri == "/api/" then
        -- API文档
        ngx.header["Content-Type"] = "application/json; charset=utf-8"
        local doc = {
            name = "御渊WAF API",
            version = "1.0.0",
            endpoints = {
                health = "GET /api/health - 健康检查",
                stats = {
                    all = "GET /api/stats - 获取所有统计",
                    qps = "GET /api/stats/qps - 获取QPS",
                    top_ips = "GET /api/stats/top-ips?limit=10 - 获取Top攻击IP",
                    trend = "GET /api/stats/trend?hours=24 - 获取攻击趋势"
                },
                blacklist = {
                    add = "POST /api/blacklist/add - 添加黑名单",
                    remove = "POST /api/blacklist/remove - 移除黑名单",
                    check = "GET /api/blacklist/check?ip=x.x.x.x - 检查IP",
                    list = "GET /api/blacklist/list?limit=100&offset=0 - 获取列表"
                },
                ratelimit = {
                    reset = "POST /api/ratelimit/reset - 重置频率限制",
                    stats = "GET /api/ratelimit/stats?ip=x.x.x.x - 获取统计"
                },
                config = {
                    get = "GET /api/config - 获取配置",
                    set_mode = "POST /api/config/mode - 设置运行模式"
                },
                cache = {
                    flush = "POST /api/cache/flush - 清理缓存",
                    info = "GET /api/cache/info - 获取缓存信息"
                }
            }
        }
        local cjson = require "cjson.safe"
        ngx.say(cjson.encode(doc))
        ngx.exit(ngx.HTTP_OK)
        
    else
        -- 未知端点
        ngx.header["Content-Type"] = "application/json; charset=utf-8"
        ngx.status = ngx.HTTP_NOT_FOUND
        ngx.say('{"success":false,"message":"API端点不存在"}')
        ngx.exit(ngx.HTTP_NOT_FOUND)
    end
end

return _M

