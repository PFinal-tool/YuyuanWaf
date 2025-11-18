-- ============================================================================
-- 御渊WAF - 字符串工具库
-- Version: 1.0.0
-- Description: 字符串处理、编码、匹配等工具函数
-- ============================================================================

local _M = {
    _VERSION = '1.0.0'
}

-- ============================================================================
-- 字符串检测
-- ============================================================================

-- 检查字符串是否以指定后缀结尾
function _M.ends_with(str, suffix)
    if not str or not suffix then
        return false
    end
    return str:sub(-#suffix) == suffix
end

-- 检查字符串是否以指定前缀开始
function _M.starts_with(str, prefix)
    if not str or not prefix then
        return false
    end
    return str:sub(1, #prefix) == prefix
end

-- 检查字符串是否包含SQL注入特征
function _M.contains_sqli(str)
    if not str or str == "" then
        return false
    end
    
    local lower_str = str:lower()
    
    -- ========== 1. 经典 SQL 注入模式 ==========
    local basic_patterns = {
        -- Union 注入
        "union.*select",
        "union.*all.*select",
        
        -- 基础 SQL 语句
        "select.*from",
        "insert.*into",
        "delete.*from",
        "update.*set",
        "drop.*table",
        "drop.*database",
        "alter.*table",
        "create.*table",
        "truncate.*table",
        
        -- 布尔盲注
        "or.*1%s*=%s*1",
        "and.*1%s*=%s*1",
        "or.*'1'%s*=%s*'1",
        "and.*'1'%s*=%s*'1",
        "'.*or.*'.*'.*=.*'",
        "\".*or.*\".*\".*=.*\"",
        
        -- 永真条件
        "or%s+%d+%s*=%s*%d+",
        "or%s+'%w+'%s*=%s*'%w+'",
        "or%s*true",
        "or%s*1%s*<%s*2",
    }
    
    for _, pattern in ipairs(basic_patterns) do
        if lower_str:match(pattern) then
            return true, pattern
        end
    end
    
    -- ========== 2. SQL 注释符 ==========
    local comment_patterns = {
        "%-%-",           -- SQL 注释 --
        "/%*.*%*/",       -- 多行注释 /* */
        "#",              -- MySQL 注释
        ";%s*%-%-",       -- 分号+注释
        "';",             -- 单引号+分号
        "\";",            -- 双引号+分号
    }
    
    for _, pattern in ipairs(comment_patterns) do
        if lower_str:match(pattern) then
            return true, pattern
        end
    end
    
    -- ========== 3. 时间盲注 ==========
    local time_based_patterns = {
        "sleep%s*%(",
        "benchmark%s*%(",
        "pg_sleep%s*%(",
        "waitfor.*delay",
        "dbms_lock%.sleep",
    }
    
    for _, pattern in ipairs(time_based_patterns) do
        if lower_str:match(pattern) then
            return true, pattern
        end
    end
    
    -- ========== 4. 危险函数 ==========
    local dangerous_functions = {
        -- MySQL
        "load_file%s*%(",
        "into.*outfile",
        "into.*dumpfile",
        "load.*data.*infile",
        
        -- MSSQL
        "exec.*xp_",
        "execute.*sp_",
        "exec%s*%(",
        "xp_cmdshell",
        
        -- PostgreSQL
        "pg_read_file",
        "copy.*from",
        "copy.*to",
        
        -- Oracle
        "utl_file",
        "dbms_",
    }
    
    for _, pattern in ipairs(dangerous_functions) do
        if lower_str:match(pattern) then
            return true, pattern
        end
    end
    
    -- ========== 5. 信息收集 ==========
    local info_gathering = {
        "@@version",
        "@@hostname",
        "@@datadir",
        "version%s*%(",
        "database%s*%(",
        "schema%s*%(",
        "user%s*%(",
        "system_user%s*%(",
        "current_user",
        "session_user",
        "information_schema",
        "mysql%.user",
        "sysobjects",
        "syscolumns",
        "pg_database",
    }
    
    for _, pattern in ipairs(info_gathering) do
        if lower_str:match(pattern) then
            return true, pattern
        end
    end
    
    -- ========== 6. 堆叠查询 ==========
    if lower_str:match(";%s*select") or 
       lower_str:match(";%s*insert") or
       lower_str:match(";%s*update") or
       lower_str:match(";%s*delete") or
       lower_str:match(";%s*drop") then
        return true, "stacked_query"
    end
    
    -- ========== 7. 编码绕过检测 ==========
    -- 检测 char() / chr() / ascii() 等编码函数
    if lower_str:match("char%s*%(") or 
       lower_str:match("chr%s*%(") or
       lower_str:match("ascii%s*%(") or
       lower_str:match("hex%s*%(") or
       lower_str:match("unhex%s*%(") then
        return true, "encoding_bypass"
    end
    
    -- ========== 8. 逻辑运算符组合 ==========
    local logic_patterns = {
        "and%s+[%d']",
        "or%s+[%d']",
        "xor%s+",
        "not%s+",
        "||",
        "&&",
    }
    
    for _, pattern in ipairs(logic_patterns) do
        if lower_str:match(pattern) then
            return true, pattern
        end
    end
    
    -- ========== 9. 子查询和特殊语法 ==========
    if lower_str:match("%(%s*select") or
       lower_str:match("exists%s*%(") or
       lower_str:match("having%s+") or
       lower_str:match("group%s+by") or
       lower_str:match("order%s+by") or
       lower_str:match("limit%s+") or
       lower_str:match("offset%s+") then
        return true, "subquery_or_clause"
    end
    
    -- ========== 10. 特殊字符串拼接 ==========
    if lower_str:match("concat%s*%(") or
       lower_str:match("concat_ws%s*%(") or
       lower_str:match("group_concat%s*%(") or
       lower_str:match("||") then  -- SQL字符串拼接
        return true, "string_concat"
    end
    
    return false
end

-- 检查字符串是否包含XSS特征
function _M.contains_xss(str)
    if not str or str == "" then
        return false
    end
    
    -- XSS常见标签和事件
    local xss_patterns = {
        "<script[^>]*>",
        "</script>",
        "javascript:",
        "onerror%s*=",
        "onload%s*=",
        "onclick%s*=",
        "onmouseover%s*=",
        "<iframe[^>]*>",
        "<img[^>]*onerror",
        "<svg[^>]*onload",
        "alert%s*%(",
        "confirm%s*%(",
        "prompt%s*%(",
        "eval%s*%(",
        "expression%s*%(",
        "vbscript:",
        "data:text/html",
    }
    
    local lower_str = str:lower()
    for _, pattern in ipairs(xss_patterns) do
        if lower_str:match(pattern) then
            return true, pattern
        end
    end
    
    return false
end

-- 检查字符串是否包含命令注入特征
function _M.contains_command_injection(str)
    if not str or str == "" then
        return false
    end
    
    local cmd_patterns = {
        "|%s*[a-z]",  -- 管道符
        ";%s*[a-z]",  -- 分号
        "&%s*[a-z]",  -- 与符号
        "`.*`",       -- 反引号
        "%$%(.*%)",   -- 命令替换
        "&&",
        "||",
        ">/dev/",
        "</dev/",
    }
    
    for _, pattern in ipairs(cmd_patterns) do
        if str:match(pattern) then
            return true, pattern
        end
    end
    
    return false
end

-- 检查是否是路径遍历
function _M.contains_path_traversal(str)
    if not str or str == "" then
        return false
    end
    
    local path_patterns = {
        "%.%./",
        "%.%.\\",
        "/etc/passwd",
        "/etc/shadow",
        "\\windows\\",
        "\\system32\\",
        "/proc/self",
    }
    
    local lower_str = str:lower()
    for _, pattern in ipairs(path_patterns) do
        if lower_str:match(pattern) then
            return true, pattern
        end
    end
    
    return false
end

-- ============================================================================
-- User-Agent检测
-- ============================================================================

-- 检查是否是爬虫UA
function _M.is_crawler_ua(ua)
    if not ua or ua == "" then
        return true  -- 空UA视为爬虫
    end
    
    local crawler_keywords = {
        "bot", "spider", "crawler", "scraper", "curl", "wget",
        "python", "java", "perl", "ruby", "php", "go-http",
        "httpclient", "okhttp", "scrapy", "mechanize",
    }
    
    local lower_ua = ua:lower()
    for _, keyword in ipairs(crawler_keywords) do
        if lower_ua:match(keyword) then
            return true, keyword
        end
    end
    
    return false
end

-- 检查是否是合法爬虫UA
function _M.is_good_bot_ua(ua)
    if not ua or ua == "" then
        return false
    end
    
    local good_bots = {
        "Googlebot",
        "Bingbot",
        "Slurp",      -- Yahoo
        "DuckDuckBot",
        "Baiduspider",
        "YandexBot",
        "Sogou",
        "Exabot",
    }
    
    for _, bot in ipairs(good_bots) do
        if ua:match(bot) then
            return true, bot
        end
    end
    
    return false
end

-- 检查UA是否异常
function _M.is_abnormal_ua(ua)
    if not ua or ua == "" then
        return true, "empty_ua"
    end
    
    -- 检查UA长度
    if #ua > 500 then
        return true, "too_long"
    end
    
    if #ua < 10 then
        return true, "too_short"
    end
    
    -- 检查是否包含正常浏览器标识
    local browser_keywords = {
        "Mozilla", "Chrome", "Safari", "Firefox", "Edge", "Opera"
    }
    
    local has_browser = false
    for _, keyword in ipairs(browser_keywords) do
        if ua:match(keyword) then
            has_browser = true
            break
        end
    end
    
    if not has_browser then
        return true, "no_browser_signature"
    end
    
    return false
end

-- ============================================================================
-- 字符串过滤和清理
-- ============================================================================

-- 移除SQL注入特征
function _M.filter_sqli(str)
    if not str then return "" end
    
    -- 移除SQL关键字
    str = ngx.re.gsub(str, "(union|select|insert|delete|update|drop|alter|exec|execute)", "", "ijo")
    
    return str
end

-- HTML实体编码
function _M.html_encode(str)
    if not str then return "" end
    
    local replacements = {
        ["&"] = "&amp;",
        ["<"] = "&lt;",
        [">"] = "&gt;",
        ['"'] = "&quot;",
        ["'"] = "&#x27;",
        ["/"] = "&#x2F;",
    }
    
    for char, entity in pairs(replacements) do
        str = str:gsub(char, entity)
    end
    
    return str
end

-- HTML实体解码
function _M.html_decode(str)
    if not str then return "" end
    
    local replacements = {
        ["&lt;"] = "<",
        ["&gt;"] = ">",
        ["&quot;"] = '"',
        ["&#x27;"] = "'",
        ["&#x2F;"] = "/",
        ["&amp;"] = "&",  -- 这个要放最后
    }
    
    for entity, char in pairs(replacements) do
        str = str:gsub(entity, char)
    end
    
    return str
end

-- ============================================================================
-- 编码检测
-- ============================================================================

-- 检测URL编码
function _M.is_url_encoded(str)
    if not str then return false end
    return str:match("%%[0-9a-fA-F][0-9a-fA-F]") ~= nil
end

-- 检测Base64编码
function _M.is_base64(str)
    if not str then return false end
    
    -- Base64只包含A-Z, a-z, 0-9, +, /, =
    if not str:match("^[A-Za-z0-9+/=]+$") then
        return false
    end
    
    -- 长度应该是4的倍数
    if #str % 4 ~= 0 then
        return false
    end
    
    return true
end

-- 多层解码 (处理多次编码)
function _M.multi_decode(str, max_depth)
    if not str then return "" end
    max_depth = max_depth or 3
    
    local decoded = str
    local depth = 0
    
    while depth < max_depth do
        local new_decoded = decoded
        
        -- URL解码
        if _M.is_url_encoded(new_decoded) then
            new_decoded = ngx.unescape_uri(new_decoded)
        end
        
        -- Base64解码
        if _M.is_base64(new_decoded) then
            local ok, result = pcall(ngx.decode_base64, new_decoded)
            if ok and result then
                new_decoded = result
            end
        end
        
        -- 如果没有变化，停止解码
        if new_decoded == decoded then
            break
        end
        
        decoded = new_decoded
        depth = depth + 1
    end
    
    return decoded
end

-- ============================================================================
-- 模式匹配增强
-- ============================================================================

-- 安全的正则匹配
function _M.safe_match(str, pattern, options)
    if not str or not pattern then
        return nil
    end
    
    options = options or "jo"
    
    local ok, result = pcall(ngx.re.match, str, pattern, options)
    if not ok then
        ngx.log(ngx.ERR, "[StringUtils] 正则匹配错误: ", result)
        return nil
    end
    
    return result
end

-- 批量模式匹配
function _M.match_any(str, patterns)
    if not str or not patterns then
        return false
    end
    
    for _, pattern in ipairs(patterns) do
        if _M.safe_match(str, pattern) then
            return true, pattern
        end
    end
    
    return false
end

-- ============================================================================
-- 敏感信息检测
-- ============================================================================

-- 检测是否包含敏感文件扩展名
function _M.has_sensitive_extension(str)
    if not str then return false end
    
    local sensitive_exts = {
        "%.bak$", "%.sql$", "%.zip$", "%.tar$", "%.gz$",
        "%.rar$", "%.7z$", "%.log$", "%.conf$", "%.config$",
        "%.ini$", "%.env$", "%.key$", "%.pem$",
    }
    
    local lower_str = str:lower()
    for _, ext in ipairs(sensitive_exts) do
        if lower_str:match(ext) then
            return true, ext
        end
    end
    
    return false
end

-- 检测是否包含密码或密钥
function _M.contains_credentials(str)
    if not str then return false end
    
    local credential_patterns = {
        "password%s*=",
        "passwd%s*=",
        "pwd%s*=",
        "api[_-]?key%s*=",
        "secret%s*=",
        "token%s*=",
        "auth%s*=",
    }
    
    local lower_str = str:lower()
    for _, pattern in ipairs(credential_patterns) do
        if lower_str:match(pattern) then
            return true, pattern
        end
    end
    
    return false
end

return _M

