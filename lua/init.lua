-- ============================================================================
-- 御渊WAF - 初始化模块
-- Version: 1.0.0
-- Description: 在Nginx master进程中执行的初始化
-- ============================================================================

local _M = {
    _VERSION = '1.0.0'
}

-- 在init阶段执行
function _M.init()
    ngx.log(ngx.INFO, "[WAF] Master进程初始化...")
    
    -- 预加载常用库
    require "cjson"
    
    ngx.log(ngx.INFO, "[WAF] Master进程初始化完成")
end

-- 在init_worker阶段执行
function _M.init_worker()
    ngx.log(ngx.INFO, "[WAF] Worker进程初始化...")
    
    -- 设置定时任务
    _M.setup_timers()
    
    ngx.log(ngx.INFO, "[WAF] Worker进程初始化完成")
end

-- 设置定时任务
function _M.setup_timers()
    -- 定期清理过期缓存
    local ok, err = ngx.timer.every(300, function()
        local cache = require "lib.cache"
        cache.cleanup_expired()
    end)
    
    if not ok then
        ngx.log(ngx.ERR, "[WAF] 设置清理定时器失败: ", err)
    end
    
    -- 定期刷新统计数据
    local ok, err = ngx.timer.every(60, function()
        -- 刷新统计数据到Redis
        local cache = require "lib.cache"
        cache.flush_stats()
    end)
    
    if not ok then
        ngx.log(ngx.ERR, "[WAF] 设置统计定时器失败: ", err)
    end
end

return _M

