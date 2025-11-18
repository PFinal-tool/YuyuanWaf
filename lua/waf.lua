-- ============================================================================
-- 御渊WAF - 核心入口模块
-- Version: 1.0.0
-- Author: YuyuanWaf Team
-- Description: WAF核心入口，负责初始化和请求处理调度
-- ============================================================================

local _M = {
    _VERSION = '1.0.0'
}

-- 全局变量
local config = nil
local modules = {}

-- ============================================================================
-- 初始化函数
-- ============================================================================
function _M.init(waf_path)
    ngx.log(ngx.INFO, "[WAF] 开始初始化御渊WAF...")
    
    -- 设置WAF根目录
    if waf_path then
        package.path = waf_path .. "lua/?.lua;" .. 
                      waf_path .. "lua/lib/?.lua;" ..
                      waf_path .. "lua/modules/?.lua;" ..
                      waf_path .. "lua/rules/?.lua;" ..
                      package.path
    end
    
    -- 加载配置
    local ok, conf = pcall(require, "config")
    if not ok then
        ngx.log(ngx.ERR, "[WAF] 加载配置失败: ", conf)
        return false
    end
    config = conf
    
    -- 保存WAF路径到配置
    config.waf_path = waf_path or "/usr/local/YuyuanWaf/"
    
    -- 加载工具库
    local utils = require "lib.utils"
    local cache = require "lib.cache"
    
    -- 初始化缓存
    cache.init()
    
    -- 加载核心模块
    modules.ip_filter = require "modules.ip_filter"
    modules.geoip = require "modules.geoip"
    modules.anti_crawler = require "modules.anti_crawler"
    modules.rate_limit = require "modules.rate_limit"
    modules.rule_engine = require "rules.rule_engine"
    
    -- 初始化各模块
    if config.geoip and config.geoip.enabled then
        modules.geoip.init(config.waf_path .. "data/geoip/")
    end
    
    if config.anti_crawler and config.anti_crawler.enabled then
        modules.anti_crawler.init(config)
    end
    
    if config.rate_limit and config.rate_limit.enabled then
        modules.rate_limit.init(config)
    end
    
    -- 加载规则
    modules.rule_engine.init(config)
    
    ngx.log(ngx.INFO, "[WAF] 御渊WAF初始化完成")
    ngx.log(ngx.INFO, "[WAF] 版本: ", _M._VERSION)
    ngx.log(ngx.INFO, "[WAF] 模式: ", config.mode or "detection")
    
    return true
end

-- ============================================================================
-- 请求处理主函数
-- ============================================================================
function _M.run()
    -- 检查是否已初始化
    if not config then
        ngx.log(ngx.ERR, "[WAF] WAF未初始化")
        return
    end
    
    -- 检查WAF模式
    if config.mode == "off" then
        return  -- WAF关闭
    end
    
    -- 获取请求信息
    local request = _M.get_request_info()
    
    -- 执行访问控制
    local access = require "access"
    local result = access.check(request, config, modules)
    
    -- 处理检测结果
    if result.action == "allow" then
        -- 允许通过
        return
    elseif result.action == "block" then
        -- 拦截请求
        _M.block_request(result)
    elseif result.action == "challenge" then
        -- JS挑战
        _M.send_challenge(result)
    elseif result.action == "captcha" then
        -- 验证码
        _M.send_captcha(result)
    elseif result.action == "log" then
        -- 仅记录日志
        _M.log_request(result)
    end
end

-- ============================================================================
-- 获取请求信息
-- ============================================================================
function _M.get_request_info()
    local request = {
        -- 基本信息
        uri = ngx.var.uri or "",
        request_uri = ngx.var.request_uri or "",
        method = ngx.var.request_method or "",
        host = ngx.var.host or "",
        
        -- IP信息
        ip = ngx.var.remote_addr or "",
        real_ip = _M.get_real_ip(),
        
        -- 请求头
        headers = ngx.req.get_headers() or {},
        user_agent = ngx.var.http_user_agent or "",
        referer = ngx.var.http_referer or "",
        
        -- 请求参数
        args = ngx.req.get_uri_args() or {},
        
        -- 时间戳
        time = ngx.time(),
        
        -- 其他
        protocol = ngx.var.server_protocol or "",
        request_id = ngx.var.request_id or _M.generate_request_id(),
    }
    
    -- 获取POST数据 (如果需要)
    if config.check_post_data and request.method == "POST" then
        ngx.req.read_body()
        request.post_args = ngx.req.get_post_args() or {}
        request.body = ngx.req.get_body_data() or ""
    end
    
    return request
end

-- ============================================================================
-- 获取真实IP
-- ============================================================================
function _M.get_real_ip()
    local ip = ngx.var.remote_addr
    
    -- 尝试从代理头获取真实IP
    if config and config.trust_proxy then
        local headers_to_check = {
            "X-Real-IP",
            "X-Forwarded-For",
            "CF-Connecting-IP",  -- Cloudflare
            "True-Client-IP",    -- Akamai
        }
        
        for _, header in ipairs(headers_to_check) do
            local value = ngx.var["http_" .. header:lower():gsub("-", "_")]
            if value and value ~= "" then
                -- X-Forwarded-For可能包含多个IP，取第一个
                local first_ip = value:match("([^,]+)")
                if first_ip then
                    ip = first_ip:match("^%s*(.-)%s*$")  -- 去除空格
                    break
                end
            end
        end
    end
    
    return ip
end

-- ============================================================================
-- 生成请求ID
-- ============================================================================
function _M.generate_request_id()
    return ngx.md5(ngx.now() .. ngx.var.remote_addr .. math.random())
end

-- ============================================================================
-- 拦截请求
-- ============================================================================
function _M.block_request(result)
    -- 记录日志
    local log_module = require "log"
    log_module.write_attack_log(result)
    
    -- 设置响应头
    ngx.header["Content-Type"] = "text/html; charset=utf-8"
    ngx.header["X-WAF-Status"] = "blocked"
    ngx.header["X-WAF-Rule"] = result.rule_id or "unknown"
    
    -- 返回拦截页面
    if config.mode == "protection" then
        ngx.status = ngx.HTTP_FORBIDDEN
        
        -- 读取自定义拦截页面
        local block_html = _M.read_html_template("block.html", result)
        
        ngx.say(block_html)
        ngx.exit(ngx.HTTP_FORBIDDEN)
    else
        -- detection模式，仅记录日志
        ngx.log(ngx.WARN, "[WAF] [DETECTION] 检测到攻击: ", result.reason or "unknown")
    end
end

-- ============================================================================
-- 发送JS挑战
-- ============================================================================
function _M.send_challenge(result)
    ngx.header.content_type = "text/html; charset=utf-8"
    
    local challenge_html = _M.read_html_template("challenge.html", result)
    
    ngx.say(challenge_html)
    ngx.exit(ngx.HTTP_OK)
end

-- ============================================================================
-- 发送验证码
-- ============================================================================
function _M.send_captcha(result)
    ngx.header.content_type = "text/html; charset=utf-8"
    
    local captcha_html = _M.read_html_template("captcha.html", result)
    
    ngx.say(captcha_html)
    ngx.exit(ngx.HTTP_OK)
end

-- ============================================================================
-- 记录日志
-- ============================================================================
function _M.log_request(result)
    local log_module = require "log"
    log_module.write_access_log(result)
end

-- ============================================================================
-- 读取HTML模板
-- ============================================================================
function _M.read_html_template(filename, data)
    local filepath = (config.waf_path or "/usr/local/YuyuanWaf/") .. "html/" .. filename
    
    local file = io.open(filepath, "r")
    if not file then
        -- 返回默认页面
        return _M.get_default_block_page(data)
    end
    
    local content = file:read("*all")
    file:close()
    
    -- 简单的模板替换
    if data then
        content = content:gsub("{{reason}}", data.reason or "安全防护")
        content = content:gsub("{{rule_id}}", data.rule_id or "unknown")
        content = content:gsub("{{request_id}}", data.request_id or "unknown")
        content = content:gsub("{{time}}", os.date("%Y-%m-%d %H:%M:%S"))
    end
    
    return content
end

-- ============================================================================
-- 获取默认拦截页面
-- ============================================================================
function _M.get_default_block_page(data)
    return [[
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>访问被拦截 - 御渊WAF</title>
    <style>
        body { 
            font-family: Arial, sans-serif; 
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            margin: 0;
        }
        .container {
            background: white;
            padding: 40px;
            border-radius: 10px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.2);
            text-align: center;
            max-width: 500px;
        }
        h1 { color: #e74c3c; margin-bottom: 20px; }
        p { color: #555; line-height: 1.6; }
        .request-id { 
            font-family: monospace; 
            background: #f5f5f5; 
            padding: 10px; 
            margin-top: 20px;
            border-radius: 5px;
            font-size: 12px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🛡️ 访问被拦截</h1>
        <p>您的请求已被 <strong>御渊WAF</strong> 安全防护系统拦截。</p>
        <p><strong>原因：</strong>]] .. (data and data.reason or "安全策略") .. [[</p>
        <div class="request-id">
            <strong>请求ID：</strong>]] .. (data and data.request_id or "unknown") .. [[<br>
            <strong>时间：</strong>]] .. os.date("%Y-%m-%d %H:%M:%S") .. [[
        </div>
        <p style="margin-top: 20px; font-size: 12px; color: #999;">
            如有疑问，请联系网站管理员并提供上述请求ID
        </p>
    </div>
</body>
</html>
    ]]
end

return _M

