-- ============================================================================
-- 御渊WAF - GeoIP地理位置过滤模块
-- Version: 1.0.0
-- Description: 基于IP地理位置的访问控制
-- ============================================================================

local cache = require "lib.cache"

local _M = {
    _VERSION = '1.0.0'
}

-- GeoIP数据库
local geoip_db = nil
local config = nil

-- ============================================================================
-- 初始化
-- ============================================================================
function _M.init(data_path)
    config = {}
    
    -- 尝试加载MaxMind GeoIP库
    local ok, geoip = pcall(require, "resty.maxminddb")
    if not ok then
        ngx.log(ngx.INFO, "[GeoIP] lua-resty-maxminddb未安装，GeoIP功能将受限")
        ngx.log(ngx.DEBUG, "[GeoIP] 安装方法: luarocks install lua-resty-maxminddb")
        return false
    end
    
    -- 加载数据库文件
    local db_file = data_path .. "GeoLite2-Country.mmdb"
    
    if not _M.file_exists(db_file) then
        ngx.log(ngx.WARN, "[GeoIP] GeoIP数据库文件不存在: ", db_file)
        ngx.log(ngx.WARN, "[GeoIP] 请下载 GeoLite2-Country.mmdb")
        return false
    end
    
    geoip_db = geoip.inew(db_file)
    if not geoip_db then
        ngx.log(ngx.ERR, "[GeoIP] 加载GeoIP数据库失败")
        return false
    end
    
    ngx.log(ngx.INFO, "[GeoIP] GeoIP模块初始化成功")
    return true
end

-- ============================================================================
-- 查询IP地理位置
-- ============================================================================
function _M.lookup(ip)
    if not ip then
        return nil
    end
    
    -- 检查缓存
    local cache_key = cache.get_geoip_key(ip)
    local cached = cache.get(cache_key)
    if cached then
        local cjson = require "cjson.safe"
        local data = cjson.decode(cached)
        if data then
            return data
        end
    end
    
    -- 如果GeoIP数据库未加载，返回默认值
    if not geoip_db then
        return {
            country_code = "XX",
            country_name = "Unknown",
        }
    end
    
    -- 查询数据库
    local res, err = geoip_db:lookup(ip)
    if not res then
        ngx.log(ngx.DEBUG, "[GeoIP] 查询失败: ", ip, " 错误: ", err or "unknown")
        return {
            country_code = "XX",
            country_name = "Unknown",
        }
    end
    
    -- 提取国家信息
    local result = {
        country_code = "XX",
        country_name = "Unknown",
    }
    
    if res.country then
        result.country_code = res.country.iso_code or "XX"
        result.country_name = res.country.names and res.country.names.en or "Unknown"
    end
    
    if res.registered_country then
        result.registered_country_code = res.registered_country.iso_code
    end
    
    if res.continent then
        result.continent_code = res.continent.code
        result.continent_name = res.continent.names and res.continent.names.en
    end
    
    -- 缓存结果
    local cjson = require "cjson.safe"
    local json_str = cjson.encode(result)
    if json_str then
        cache.set(cache_key, json_str, 3600)  -- 缓存1小时
    end
    
    return result
end

-- ============================================================================
-- 检查IP是否被地理位置过滤
-- ============================================================================
function _M.check(ip, geoip_config)
    if not ip or not geoip_config then
        return {blocked = false}
    end
    
    -- 查询地理位置
    local location = _M.lookup(ip)
    if not location then
        return {blocked = false}
    end
    
    local country_code = location.country_code
    
    -- 白名单模式
    if geoip_config.whitelist_mode and geoip_config.whitelist_countries then
        if #geoip_config.whitelist_countries > 0 then
            -- 只允许白名单国家
            for _, allowed_country in ipairs(geoip_config.whitelist_countries) do
                if country_code == allowed_country then
                    cache.incr_stats("geoip_whitelist_pass")
                    return {blocked = false, country = country_code}
                end
            end
            
            -- 不在白名单中，拒绝
            cache.incr_stats("geoip_whitelist_blocked")
            return {
                blocked = true,
                country = country_code,
                country_name = location.country_name,
                reason = "国家不在白名单中"
            }
        end
    end
    
    -- 黑名单模式 (默认)
    if geoip_config.blacklist_countries then
        for _, blocked_country in ipairs(geoip_config.blacklist_countries) do
            if country_code == blocked_country then
                cache.incr_stats("geoip_blacklist_blocked")
                return {
                    blocked = true,
                    country = country_code,
                    country_name = location.country_name,
                    reason = "国家在黑名单中"
                }
            end
        end
    end
    
    -- 允许通过
    return {blocked = false, country = country_code}
end

-- ============================================================================
-- 获取统计信息
-- ============================================================================
function _M.get_stats()
    return {
        whitelist_pass = cache.get_stats("geoip_whitelist_pass") or 0,
        whitelist_blocked = cache.get_stats("geoip_whitelist_blocked") or 0,
        blacklist_blocked = cache.get_stats("geoip_blacklist_blocked") or 0,
    }
end

-- ============================================================================
-- 工具函数：检查文件是否存在
-- ============================================================================
function _M.file_exists(filepath)
    local file = io.open(filepath, "r")
    if file then
        file:close()
        return true
    end
    return false
end

-- ============================================================================
-- 批量查询 (用于统计分析)
-- ============================================================================
function _M.batch_lookup(ip_list)
    local results = {}
    
    for _, ip in ipairs(ip_list) do
        local location = _M.lookup(ip)
        if location then
            results[ip] = location
        end
    end
    
    return results
end

return _M

