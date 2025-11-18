-- ============================================================================
-- 御渊WAF - 防爬虫模块
-- Version: 1.0.0
-- Description: 多维度爬虫检测和防护
-- ============================================================================

local string_utils = require "lib.string_utils"
local cache = require "lib.cache"
local utils = require "lib.utils"

local _M = {
    _VERSION = '1.0.0'
}

local config = nil
local crawler_ua_list = {}
local good_bot_list = {}

-- ============================================================================
-- 初始化
-- ============================================================================
function _M.init(waf_config)
    config = waf_config or {}
    
    -- 加载爬虫UA库
    if config.ua_check and config.ua_check.enabled and config.ua_check.crawler_ua_file then
        _M.load_crawler_ua(config.ua_check.crawler_ua_file)
    end
    
    -- 加载合法爬虫库
    if config.ua_check and config.ua_check.good_bot_file then
        _M.load_good_bot_ua(config.ua_check.good_bot_file)
    end
    
    ngx.log(ngx.INFO, "[AntiCrawler] 防爬虫模块初始化完成")
end

-- ============================================================================
-- 加载爬虫UA库
-- ============================================================================
function _M.load_crawler_ua(filepath)
    -- 内置的爬虫UA关键字
    crawler_ua_list = {
        "bot", "spider", "crawler", "scraper", "curl", "wget",
        "python-requests", "java", "perl", "ruby", "php/",
        "go-http-client", "httpclient", "okhttp", "scrapy",
        "mechanize", "axios", "node-fetch", "got/",
        "headless", "phantom", "selenium", "puppeteer"
    }
    
    ngx.log(ngx.INFO, "[AntiCrawler] 加载爬虫UA规则: ", #crawler_ua_list, " 条")
end

-- ============================================================================
-- 加载合法爬虫库
-- ============================================================================
function _M.load_good_bot_ua(filepath)
    good_bot_list = {
        "Googlebot", "Google-InspectionTool",
        "Bingbot", "BingPreview",
        "Slurp", "Yahoo",
        "DuckDuckBot",
        "Baiduspider",
        "YandexBot",
        "Sogou",
        "facebookexternalhit",
        "LinkedInBot",
        "Twitterbot",
    }
    
    ngx.log(ngx.INFO, "[AntiCrawler] 加载合法爬虫规则: ", #good_bot_list, " 条")
end

-- ============================================================================
-- 主检查函数
-- ============================================================================
function _M.check(request, crawler_config)
    local score = 0  -- 爬虫评分，越高越可能是爬虫
    local reasons = {}
    
    -- 1. 检查是否是合法爬虫 (白名单)
    if crawler_config.ua_check and crawler_config.ua_check.enabled then
        local is_good_bot, bot_name = _M.check_good_bot(request.user_agent)
        if is_good_bot then
            cache.incr_stats("crawler_good_bot")
            return {
                is_crawler = false,
                is_good_bot = true,
                bot_name = bot_name,
                score = 0
            }
        end
    end
    
    -- 2. User-Agent检测
    if crawler_config.ua_check and crawler_config.ua_check.enabled then
        local ua_score, ua_reason = _M.check_user_agent(request.user_agent)
        score = score + ua_score
        if ua_score > 0 then
            table.insert(reasons, ua_reason)
        end
    end
    
    -- 3. 行为分析
    if crawler_config.behavior_analysis and crawler_config.behavior_analysis.enabled then
        local behavior_score, behavior_reason = _M.check_behavior(request, crawler_config.behavior_analysis)
        score = score + behavior_score
        if behavior_score > 0 then
            table.insert(reasons, behavior_reason)
        end
    end
    
    -- 4. HTTP头指纹检测
    if crawler_config.fingerprint and crawler_config.fingerprint.enabled then
        local fingerprint_score, fingerprint_reason = _M.check_fingerprint(request)
        score = score + fingerprint_score
        if fingerprint_score > 0 then
            table.insert(reasons, fingerprint_reason)
        end
    end
    
    -- 5. 蜜罐陷阱检测
    if crawler_config.honeypot and crawler_config.honeypot.enabled then
        local is_trapped = _M.check_honeypot(request, crawler_config.honeypot)
        if is_trapped then
            score = score + 50
            table.insert(reasons, "触发蜜罐陷阱")
        end
    end
    
    -- 判断是否为爬虫
    local threshold = crawler_config.score_threshold or 70
    local is_crawler = score >= threshold
    
    if is_crawler then
        cache.incr_stats("crawler_detected")
    end
    
    -- 确定动作
    local action = "allow"
    if is_crawler then
        if score >= 90 then
            action = "block"  -- 高度疑似，直接拦截
        elseif crawler_config.js_challenge and crawler_config.js_challenge.enabled then
            action = "challenge"  -- JS挑战
        elseif crawler_config.captcha and crawler_config.captcha.enabled then
            action = "captcha"  -- 验证码
        else
            action = crawler_config.action or "log"
        end
    end
    
    return {
        is_crawler = is_crawler,
        score = score,
        threshold = threshold,
        reasons = reasons,
        action = action,
        reason = table.concat(reasons, ", ")
    }
end

-- ============================================================================
-- User-Agent检测
-- ============================================================================
function _M.check_user_agent(ua)
    local score = 0
    local reason = ""
    
    -- 检查空UA
    if not ua or ua == "" or ua == "-" then
        return 30, "空User-Agent"
    end
    
    -- 检查UA长度
    if #ua < 10 then
        return 25, "User-Agent过短"
    end
    
    if #ua > 500 then
        return 20, "User-Agent过长"
    end
    
    -- 检查是否包含爬虫关键字
    local is_crawler, keyword = string_utils.is_crawler_ua(ua)
    if is_crawler then
        return 40, "爬虫User-Agent: " .. (keyword or "")
    end
    
    -- 检查是否缺少正常浏览器标识
    local is_abnormal, abnormal_reason = string_utils.is_abnormal_ua(ua)
    if is_abnormal then
        return 30, "异常User-Agent: " .. (abnormal_reason or "")
    end
    
    return 0, ""
end

-- ============================================================================
-- 检查合法爬虫
-- ============================================================================
function _M.check_good_bot(ua)
    if not ua then
        return false
    end
    
    for _, bot_name in ipairs(good_bot_list) do
        if ua:match(bot_name) then
            return true, bot_name
        end
    end
    
    return false
end

-- ============================================================================
-- 行为分析
-- ============================================================================
function _M.check_behavior(request, behavior_config)
    local score = 0
    local reason = ""
    local ip = request.real_ip
    
    -- 请求频率分析
    local freq_key = "crawler:freq:" .. ip
    local request_count = cache.incr(freq_key, 1, 0)
    
    -- 设置过期时间(60秒窗口)
    if request_count == 1 then
        cache.set(freq_key, 1, 60)
    end
    
    local threshold = behavior_config.request_threshold or 100
    if request_count > threshold then
        score = score + 30
        reason = "请求频率过高: " .. request_count .. "/分钟"
    elseif request_count > threshold * 0.7 then
        score = score + 15
        reason = "请求频率较高: " .. request_count .. "/分钟"
    end
    
    -- 会话分析
    local session_key = "crawler:session:" .. ip
    local session_requests = cache.get(session_key) or 0
    session_requests = tonumber(session_requests) + 1
    
    local session_timeout = behavior_config.session_timeout or 1800
    cache.set(session_key, session_requests, session_timeout)
    
    local max_session_requests = behavior_config.session_max_requests or 1000
    if session_requests > max_session_requests then
        score = score + 20
        if reason ~= "" then
            reason = reason .. ", "
        end
        reason = reason .. "会话请求过多: " .. session_requests
    end
    
    -- 访问路径分析
    -- 检查是否访问了robots.txt (爬虫特征)
    if request.uri == "/robots.txt" then
        local robot_key = "crawler:robot:" .. ip
        cache.incr(robot_key, 1, 0)
        cache.set(robot_key, 1, 3600)
        score = score + 5
    end
    
    return score, reason
end

-- ============================================================================
-- HTTP指纹检测
-- ============================================================================
function _M.check_fingerprint(request)
    local score = 0
    local reason = ""
    
    -- 检查Accept头
    local accept = request.headers["Accept"]
    if not accept or accept == "*/*" then
        score = score + 10
        reason = "缺少或异常的Accept头"
    end
    
    -- 检查Accept-Language头
    local accept_lang = request.headers["Accept-Language"]
    if not accept_lang then
        score = score + 10
        if reason ~= "" then reason = reason .. ", " end
        reason = reason .. "缺少Accept-Language头"
    end
    
    -- 检查Accept-Encoding头
    local accept_encoding = request.headers["Accept-Encoding"]
    if not accept_encoding then
        score = score + 5
        if reason ~= "" then reason = reason .. ", " end
        reason = reason .. "缺少Accept-Encoding头"
    end
    
    -- 检查Connection头
    local connection = request.headers["Connection"]
    if connection and connection:lower() == "close" then
        score = score + 5
        if reason ~= "" then reason = reason .. ", " end
        reason = reason .. "使用Connection: close"
    end
    
    -- 检查Referer (首次访问没有Referer是正常的)
    -- 这里只是记录，不计分
    
    return score, reason
end

-- ============================================================================
-- 蜜罐陷阱检测
-- ============================================================================
function _M.check_honeypot(request, honeypot_config)
    if not honeypot_config.uris then
        return false
    end
    
    -- 检查是否访问了蜜罐URI
    for _, trap_uri in ipairs(honeypot_config.uris) do
        if request.uri:match(trap_uri) then
            -- 标记该IP为爬虫
            local trap_key = "crawler:honeypot:" .. request.real_ip
            cache.set(trap_key, "trapped", 86400)  -- 24小时
            cache.incr_stats("crawler_honeypot_hit")
            return true
        end
    end
    
    -- 检查之前是否触发过蜜罐
    local trap_key = "crawler:honeypot:" .. request.real_ip
    local is_trapped = cache.get(trap_key)
    return is_trapped ~= nil
end

-- ============================================================================
-- JS挑战验证
-- ============================================================================
function _M.verify_challenge(challenge_token, answer)
    if not challenge_token or not answer then
        return false
    end
    
    -- 从缓存中获取挑战
    local challenge_key = "challenge:" .. challenge_token
    local expected_answer = cache.get(challenge_key)
    
    if not expected_answer then
        return false  -- 挑战已过期
    end
    
    -- 验证答案
    if tostring(answer) == tostring(expected_answer) then
        -- 验证成功，删除挑战
        cache.delete(challenge_key)
        
        -- 标记该IP已通过验证
        local verified_key = "challenge:verified:" .. ngx.var.remote_addr
        cache.set(verified_key, "1", 3600)  -- 1小时有效
        
        return true
    end
    
    return false
end

-- ============================================================================
-- 检查是否已通过JS挑战
-- ============================================================================
function _M.is_challenge_verified(ip)
    local verified_key = "challenge:verified:" .. ip
    local verified = cache.get(verified_key)
    return verified ~= nil
end

-- ============================================================================
-- 生成JS挑战
-- ============================================================================
function _M.generate_challenge()
    -- 生成简单的数学题
    local a = math.random(1, 100)
    local b = math.random(1, 100)
    local answer = a + b
    
    -- 生成挑战token
    local token = utils.random_string(32)
    
    -- 缓存答案
    local challenge_key = "challenge:" .. token
    cache.set(challenge_key, answer, 300)  -- 5分钟有效
    
    return {
        token = token,
        question = string.format("%d + %d = ?", a, b),
        answer = answer  -- 仅供调试，不返回给前端
    }
end

-- ============================================================================
-- 获取统计信息
-- ============================================================================
function _M.get_stats()
    return {
        detected = cache.get_stats("crawler_detected") or 0,
        good_bot = cache.get_stats("crawler_good_bot") or 0,
        honeypot_hit = cache.get_stats("crawler_honeypot_hit") or 0,
    }
end

return _M

