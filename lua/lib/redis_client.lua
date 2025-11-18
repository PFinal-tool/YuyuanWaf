-- ============================================================================
-- 御渊WAF - Redis客户端 (可选)
-- Version: 1.0.0
-- Description: Redis连接池和操作封装
-- ============================================================================

local _M = {
    _VERSION = '1.0.0'
}

local redis_config = nil

-- ============================================================================
-- 初始化
-- ============================================================================
function _M.init(config)
    redis_config = config
end

-- ============================================================================
-- 获取Redis连接
-- ============================================================================
function _M.get_connection()
    if not redis_config then
        return nil, "Redis未配置"
    end
    
    local redis = require "resty.redis"
    local red = redis:new()
    
    red:set_timeout(redis_config.timeout or 1000)
    
    local ok, err = red:connect(redis_config.host, redis_config.port)
    if not ok then
        return nil, "连接Redis失败: " .. err
    end
    
    -- 认证
    if redis_config.password and redis_config.password ~= "" then
        local ok, err = red:auth(redis_config.password)
        if not ok then
            return nil, "Redis认证失败: " .. err
        end
    end
    
    -- 选择数据库
    if redis_config.database then
        local ok, err = red:select(redis_config.database)
        if not ok then
            return nil, "选择数据库失败: " .. err
        end
    end
    
    return red
end

-- ============================================================================
-- 关闭连接 (放回连接池)
-- ============================================================================
function _M.close(red)
    if not red then
        return
    end
    
    local ok, err = red:set_keepalive(
        redis_config.keepalive_timeout or 60000,
        redis_config.pool_size or 100
    )
    
    if not ok then
        ngx.log(ngx.ERR, "[Redis] 放回连接池失败: ", err)
    end
end

-- ============================================================================
-- 基础操作
-- ============================================================================

-- GET
function _M.get(key)
    local red, err = _M.get_connection()
    if not red then
        return nil, err
    end
    
    local value, err = red:get(key)
    _M.close(red)
    
    if not value or value == ngx.null then
        return nil
    end
    
    return value
end

-- SET
function _M.set(key, value, ttl)
    local red, err = _M.get_connection()
    if not red then
        return false, err
    end
    
    local ok, err
    if ttl then
        ok, err = red:setex(key, ttl, value)
    else
        ok, err = red:set(key, value)
    end
    
    _M.close(red)
    
    return ok ~= nil, err
end

-- DEL
function _M.del(key)
    local red, err = _M.get_connection()
    if not red then
        return false, err
    end
    
    local ok, err = red:del(key)
    _M.close(red)
    
    return ok ~= nil, err
end

-- INCR
function _M.incr(key, step)
    local red, err = _M.get_connection()
    if not red then
        return nil, err
    end
    
    local value, err
    if step and step ~= 1 then
        value, err = red:incrby(key, step)
    else
        value, err = red:incr(key)
    end
    
    _M.close(red)
    
    return value, err
end

-- EXPIRE
function _M.expire(key, ttl)
    local red, err = _M.get_connection()
    if not red then
        return false, err
    end
    
    local ok, err = red:expire(key, ttl)
    _M.close(red)
    
    return ok ~= nil, err
end

return _M

