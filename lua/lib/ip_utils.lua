-- ============================================================================
-- 御渊WAF - IP处理工具库
-- Version: 1.0.0
-- Description: IP地址处理、CIDR匹配、IPv4/IPv6支持
-- ============================================================================

local bit = require "bit"  -- LuaJIT 位运算库

local _M = {
    _VERSION = '1.0.0'
}

-- ============================================================================
-- IPv4地址处理
-- ============================================================================

-- IPv4转数字
function _M.ipv4_to_number(ip)
    if not ip then return nil end
    
    local parts = {}
    for part in ip:gmatch("%d+") do
        table.insert(parts, tonumber(part))
    end
    
    if #parts ~= 4 then
        return nil
    end
    
    -- 检查每个部分是否在有效范围内
    for _, part in ipairs(parts) do
        if part < 0 or part > 255 then
            return nil
        end
    end
    
    return parts[1] * 16777216 + parts[2] * 65536 + parts[3] * 256 + parts[4]
end

-- 数字转IPv4
function _M.number_to_ipv4(num)
    if not num then return nil end
    
    local a = math.floor(num / 16777216) % 256
    local b = math.floor(num / 65536) % 256
    local c = math.floor(num / 256) % 256
    local d = num % 256
    
    return string.format("%d.%d.%d.%d", a, b, c, d)
end

-- ============================================================================
-- CIDR处理
-- ============================================================================

-- 解析CIDR
function _M.parse_cidr(cidr)
    if not cidr then return nil end
    
    -- 检查是否是CIDR格式
    if not cidr:match("/") then
        -- 单个IP地址
        return cidr, 32
    end
    
    local ip, prefix = cidr:match("([^/]+)/(%d+)")
    if not ip or not prefix then
        return nil
    end
    
    prefix = tonumber(prefix)
    if prefix < 0 or prefix > 32 then
        return nil
    end
    
    return ip, prefix
end

-- 计算CIDR的起始和结束IP
function _M.cidr_range(cidr)
    local ip, prefix = _M.parse_cidr(cidr)
    if not ip then
        return nil
    end
    
    local ip_num = _M.ipv4_to_number(ip)
    if not ip_num then
        return nil
    end
    
    -- 计算网络掩码
    local mask = bit.lshift(0xFFFFFFFF, 32 - prefix)
    mask = mask % 0x100000000  -- 处理位运算溢出
    
    -- 计算网络地址和广播地址
    local network = bit.band(ip_num, mask)
    local broadcast = bit.bor(network, bit.band(bit.bnot(mask), 0xFFFFFFFF))
    
    return network, broadcast
end

-- ============================================================================
-- IP匹配
-- ============================================================================

-- 检查IP是否在CIDR范围内
function _M.ip_in_cidr(ip, cidr)
    local ip_num = _M.ipv4_to_number(ip)
    if not ip_num then
        return false
    end
    
    local start_ip, end_ip = _M.cidr_range(cidr)
    if not start_ip then
        return false
    end
    
    return ip_num >= start_ip and ip_num <= end_ip
end

-- 通用IP匹配 (支持单IP、CIDR、通配符)
function _M.match(ip, pattern)
    if not ip or not pattern then
        return false
    end
    
    -- 完全匹配
    if ip == pattern then
        return true
    end
    
    -- CIDR匹配
    if pattern:match("/") then
        return _M.ip_in_cidr(ip, pattern)
    end
    
    -- 通配符匹配 (例如: 192.168.1.*)
    if pattern:match("%*") then
        local regex = pattern:gsub("%.", "%%."):gsub("%*", "%%d+")
        return ngx.re.match(ip, "^" .. regex .. "$", "jo") ~= nil
    end
    
    return false
end

-- 批量匹配
function _M.match_list(ip, patterns)
    if not patterns or #patterns == 0 then
        return false
    end
    
    for _, pattern in ipairs(patterns) do
        if _M.match(ip, pattern) then
            return true
        end
    end
    
    return false
end

-- ============================================================================
-- IPv6支持 (基础实现)
-- ============================================================================

-- 检查是否是IPv6地址
function _M.is_ipv6(ip)
    if not ip then return false end
    return ip:match(":") ~= nil
end

-- 检查是否是IPv4地址
function _M.is_ipv4(ip)
    if not ip then return false end
    return ip:match("^%d+%.%d+%.%d+%.%d+$") ~= nil
end

-- ============================================================================
-- IP验证
-- ============================================================================

-- 验证IPv4地址格式
function _M.validate_ipv4(ip)
    if not ip then return false end
    
    local parts = {}
    for part in ip:gmatch("%d+") do
        table.insert(parts, tonumber(part))
    end
    
    if #parts ~= 4 then
        return false
    end
    
    for _, part in ipairs(parts) do
        if part < 0 or part > 255 then
            return false
        end
    end
    
    return true
end

-- 验证IP地址 (IPv4或IPv6)
function _M.validate_ip(ip)
    if not ip then return false end
    
    if _M.is_ipv6(ip) then
        -- 简单的IPv6验证
        return ip:match("^[0-9a-fA-F:]+$") ~= nil
    else
        return _M.validate_ipv4(ip)
    end
end

-- ============================================================================
-- IP类型判断
-- ============================================================================

-- 检查是否是私有IP
function _M.is_private_ip(ip)
    if not _M.validate_ipv4(ip) then
        return false
    end
    
    local private_ranges = {
        "10.0.0.0/8",
        "172.16.0.0/12",
        "192.168.0.0/16",
        "127.0.0.0/8",  -- 回环地址
    }
    
    return _M.match_list(ip, private_ranges)
end

-- 检查是否是本地回环地址
function _M.is_loopback(ip)
    return _M.match(ip, "127.0.0.0/8") or ip == "::1"
end

-- ============================================================================
-- IP信息
-- ============================================================================

-- 获取IP所在的网段
function _M.get_network(ip, prefix)
    prefix = prefix or 24
    
    local ip_num = _M.ipv4_to_number(ip)
    if not ip_num then
        return nil
    end
    
    local mask = bit.lshift(0xFFFFFFFF, 32 - prefix)
    mask = mask % 0x100000000
    
    local network = bit.band(ip_num, mask)
    
    return _M.number_to_ipv4(network) .. "/" .. prefix
end

-- 计算子网大小
function _M.get_subnet_size(prefix)
    if not prefix or prefix < 0 or prefix > 32 then
        return 0
    end
    
    return 2 ^ (32 - prefix)
end

-- ============================================================================
-- IP列表处理
-- ============================================================================

-- 从文件加载IP列表
function _M.load_ip_list(filepath)
    local utils = require "lib.utils"
    local lines, err = utils.read_file_lines(filepath)
    
    if not lines then
        ngx.log(ngx.ERR, "[IPUtils] 加载IP列表失败: ", err)
        return {}
    end
    
    return lines
end

-- 规范化IP地址
function _M.normalize_ip(ip)
    if not ip then return nil end
    
    -- 去除空格
    ip = ip:match("^%s*(.-)%s*$")
    
    -- IPv4
    if _M.is_ipv4(ip) then
        return ip
    end
    
    -- IPv6 (简单处理)
    if _M.is_ipv6(ip) then
        return ip:lower()
    end
    
    return nil
end

-- ============================================================================
-- IP地理位置相关 (占位符，实际由geoip模块实现)
-- ============================================================================

-- 获取IP的地理位置信息
function _M.get_location(ip)
    -- 由geoip模块实现
    return nil
end

return _M

