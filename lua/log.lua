-- ============================================================================
-- 御渊WAF - 日志模块
-- Version: 1.0.0
-- Description: 日志记录和管理
-- ============================================================================

local cjson = require "cjson"
local _M = {
    _VERSION = '1.0.0'
}

-- 日志级别
local LOG_LEVEL = {
    DEBUG = 1,
    INFO = 2,
    WARN = 3,
    ERROR = 4,
    CRITICAL = 5
}

-- ============================================================================
-- 写攻击日志
-- ============================================================================
function _M.write_attack_log(data)
    local log_entry = {
        type = "attack",
        time = os.date("%Y-%m-%d %H:%M:%S", data.time or ngx.time()),
        timestamp = data.time or ngx.time(),
        request_id = data.request_id or "",
        
        -- 请求信息
        ip = data.ip or "",
        uri = data.uri or "",
        method = ngx.var.request_method or "",
        host = ngx.var.host or "",
        
        -- 攻击信息
        action = data.action or "block",
        reason = data.reason or "",
        rule_id = data.rule_id or "",
        
        -- 附加信息
        user_agent = ngx.var.http_user_agent or "",
        referer = ngx.var.http_referer or "",
        
        -- 可选信息
        country = data.country,
        crawler_score = data.crawler_score,
        attack_details = data.attack_details,
    }
    
    -- JSON格式输出
    local log_json = cjson.encode(log_entry)
    
    -- 写入日志文件（改为 INFO 级别，不会在 error.log 中显示）
    ngx.log(ngx.INFO, "[WAF-ATTACK] ", log_json)
    
    -- 异步写入详细日志（详细的攻击日志在这里查看）
    _M.write_to_file("attack.log", log_json)
end

-- ============================================================================
-- 写访问日志
-- ============================================================================
function _M.write_access_log(data)
    local log_entry = {
        type = "access",
        time = os.date("%Y-%m-%d %H:%M:%S"),
        timestamp = ngx.time(),
        request_id = data.request_id or "",
        
        -- 请求信息
        ip = data.ip or "",
        uri = data.uri or "",
        method = ngx.var.request_method or "",
        status = ngx.status or 200,
        
        -- 结果
        action = data.action or "allow",
        reason = data.reason or "",
    }
    
    local log_json = cjson.encode(log_entry)
    ngx.log(ngx.INFO, "[WAF-ACCESS] ", log_json)
end

-- ============================================================================
-- 写错误日志
-- ============================================================================
function _M.write_error_log(message, level)
    local log_entry = {
        type = "error",
        time = os.date("%Y-%m-%d %H:%M:%S"),
        level = level or "ERROR",
        message = message or "",
    }
    
    local log_json = cjson.encode(log_entry)
    ngx.log(ngx.ERR, "[WAF-ERROR] ", log_json)
end

-- ============================================================================
-- 异步写入文件
-- ============================================================================
function _M.write_to_file(filename, content)
    -- 使用ngx.timer异步写入，避免阻塞
    local ok, err = ngx.timer.at(0, function(premature)
        if premature then
            return
        end
        
        -- 这里可以扩展为写入独立的日志文件
        -- 或发送到日志收集系统 (ELK, Splunk等)
    end)
    
    if not ok then
        ngx.log(ngx.ERR, "[WAF] 异步日志写入失败: ", err)
    end
end

-- ============================================================================
-- 批量日志收集 (用于性能优化)
-- ============================================================================
local log_buffer = {}
local buffer_size = 0
local MAX_BUFFER_SIZE = 100

function _M.buffer_log(log_entry)
    buffer_size = buffer_size + 1
    log_buffer[buffer_size] = log_entry
    
    -- 缓冲区满时刷新
    if buffer_size >= MAX_BUFFER_SIZE then
        _M.flush_buffer()
    end
end

function _M.flush_buffer()
    if buffer_size == 0 then
        return
    end
    
    -- 批量写入日志
    for i = 1, buffer_size do
        local log_json = cjson.encode(log_buffer[i])
        ngx.log(ngx.WARN, "[WAF-BATCH] ", log_json)
    end
    
    -- 清空缓冲区
    log_buffer = {}
    buffer_size = 0
end

return _M

