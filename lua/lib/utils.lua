-- ============================================================================
-- 御渊WAF - 工具函数库
-- Version: 1.0.0
-- Description: 通用工具函数
-- ============================================================================

local _M = {
    _VERSION = '1.0.0'
}

-- ============================================================================
-- 表操作
-- ============================================================================

-- 检查表是否为空
function _M.table_is_empty(t)
    return t == nil or next(t) == nil
end

-- 表深拷贝
function _M.table_deep_copy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[_M.table_deep_copy(orig_key)] = _M.table_deep_copy(orig_value)
        end
        setmetatable(copy, _M.table_deep_copy(getmetatable(orig)))
    else
        copy = orig
    end
    return copy
end

-- 表合并
function _M.table_merge(t1, t2)
    for k, v in pairs(t2) do
        if type(v) == "table" then
            if type(t1[k] or false) == "table" then
                _M.table_merge(t1[k] or {}, t2[k] or {})
            else
                t1[k] = v
            end
        else
            t1[k] = v
        end
    end
    return t1
end

-- 检查值是否在表中
function _M.in_table(val, tbl)
    for _, v in ipairs(tbl) do
        if v == val then
            return true
        end
    end
    return false
end

-- ============================================================================
-- 字符串操作
-- ============================================================================

-- 分割字符串
function _M.split(str, delimiter)
    if str == nil or str == "" then
        return {}
    end
    
    if delimiter == nil then
        delimiter = "%s"
    end
    
    local result = {}
    for match in (str .. delimiter):gmatch("(.-)" .. delimiter) do
        table.insert(result, match)
    end
    return result
end

-- 去除字符串首尾空格
function _M.trim(s)
    if not s then return "" end
    return s:match("^%s*(.-)%s*$")
end

-- 字符串开始匹配
function _M.starts_with(str, prefix)
    return str:sub(1, #prefix) == prefix
end

-- 字符串结束匹配
function _M.ends_with(str, suffix)
    return suffix == "" or str:sub(-#suffix) == suffix
end

-- URL解码
function _M.url_decode(str)
    if not str then return "" end
    str = str:gsub('+', ' ')
    str = str:gsub('%%(%x%x)', function(h)
        return string.char(tonumber(h, 16))
    end)
    return str
end

-- URL编码
function _M.url_encode(str)
    if not str then return "" end
    str = str:gsub("\n", "\r\n")
    str = str:gsub("([^%w%-%.%_%~ ])", function(c)
        return string.format("%%%02X", string.byte(c))
    end)
    str = str:gsub(" ", "+")
    return str
end

-- Base64解码
function _M.base64_decode(str)
    if not str then return "" end
    local b64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    str = string.gsub(str, '[^'..b64..'=]', '')
    return (str:gsub('.', function(x)
        if x == '=' then return '' end
        local r, f = '', (b64:find(x) - 1)
        for i = 6, 1, -1 do
            r = r .. (f % 2^i - f % 2^(i-1) > 0 and '1' or '0')
        end
        return r
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if #x ~= 8 then return '' end
        local c = 0
        for i = 1, 8 do
            c = c + (x:sub(i,i) == '1' and 2^(8-i) or 0)
        end
        return string.char(c)
    end))
end

-- ============================================================================
-- 文件操作
-- ============================================================================

-- 读取文件内容
function _M.read_file(filepath)
    local file, err = io.open(filepath, "r")
    if not file then
        return nil, err
    end
    
    local content = file:read("*all")
    file:close()
    return content
end

-- 读取文件行
function _M.read_file_lines(filepath)
    local lines = {}
    local file, err = io.open(filepath, "r")
    if not file then
        return nil, err
    end
    
    for line in file:lines() do
        -- 跳过空行和注释
        line = _M.trim(line)
        if line ~= "" and not _M.starts_with(line, "#") then
            table.insert(lines, line)
        end
    end
    
    file:close()
    return lines
end

-- 检查文件是否存在
function _M.file_exists(filepath)
    local file = io.open(filepath, "r")
    if file then
        file:close()
        return true
    end
    return false
end

-- ============================================================================
-- 时间操作
-- ============================================================================

-- 获取当前时间戳(毫秒)
function _M.get_timestamp_ms()
    return ngx.now() * 1000
end

-- 获取当前时间戳(秒)
function _M.get_timestamp()
    return ngx.time()
end

-- 格式化时间
function _M.format_time(timestamp, format)
    format = format or "%Y-%m-%d %H:%M:%S"
    return os.date(format, timestamp)
end

-- ============================================================================
-- JSON操作
-- ============================================================================

-- 安全的JSON解码
function _M.json_decode(str)
    local cjson = require "cjson.safe"
    local data, err = cjson.decode(str)
    if not data then
        return nil, err
    end
    return data
end

-- 安全的JSON编码
function _M.json_encode(data)
    local cjson = require "cjson.safe"
    local str, err = cjson.encode(data)
    if not str then
        return nil, err
    end
    return str
end

-- ============================================================================
-- 随机数和Hash
-- ============================================================================

-- 生成随机字符串
function _M.random_string(length)
    length = length or 16
    local chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local result = {}
    
    for i = 1, length do
        local rand = math.random(1, #chars)
        table.insert(result, chars:sub(rand, rand))
    end
    
    return table.concat(result)
end

-- MD5哈希
function _M.md5(str)
    return ngx.md5(str)
end

-- SHA1哈希
function _M.sha1(str)
    local resty_sha1 = require "resty.sha1"
    local sha1 = resty_sha1:new()
    sha1:update(str)
    local digest = sha1:final()
    return ngx.encode_base64(digest)
end

-- ============================================================================
-- 调试和日志
-- ============================================================================

-- 打印表内容 (调试用)
function _M.print_table(tbl, indent)
    indent = indent or 0
    local formatting = string.rep("  ", indent)
    
    for k, v in pairs(tbl) do
        if type(v) == "table" then
            ngx.log(ngx.DEBUG, formatting .. tostring(k) .. ":")
            _M.print_table(v, indent + 1)
        else
            ngx.log(ngx.DEBUG, formatting .. tostring(k) .. ": " .. tostring(v))
        end
    end
end

-- ============================================================================
-- 性能相关
-- ============================================================================

-- 计时器
local timers = {}

function _M.timer_start(name)
    timers[name] = ngx.now()
end

function _M.timer_end(name)
    if not timers[name] then
        return 0
    end
    local elapsed = ngx.now() - timers[name]
    timers[name] = nil
    return elapsed
end

return _M

