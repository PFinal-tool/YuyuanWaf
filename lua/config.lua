-- ============================================================================
-- 御渊WAF - 配置文件
-- Version: 1.0.0
-- Description: WAF核心配置
-- ============================================================================

local _M = {
    -- ========================================================================
    -- 基础配置
    -- ========================================================================
    
    -- WAF运行模式
    -- off: 关闭WAF
    -- detection: 检测模式，仅记录日志不拦截
    -- protection: 防护模式，检测并拦截攻击
    mode = "protection",
    
    -- WAF路径 (在init时设置)
    waf_path = "/usr/local/YuyuanWaf/",
    
    -- 是否信任代理服务器的IP头
    trust_proxy = true,
    
    -- 是否检查POST数据
    check_post_data = true,
    
    -- ========================================================================
    -- 白名单配置
    -- ========================================================================
    whitelist = {
        -- IP白名单 (支持单个IP和CIDR格式)
        ips = {
            "127.0.0.1",
            "::1",
            -- "192.168.1.0/24",
        },
        
        -- URI白名单 (正则表达式)
        uris = {
            "^/health$",
            "^/api/public/",
        },
        
        -- User-Agent白名单 (合法爬虫)
        user_agents = {
            "Googlebot",
            "Bingbot",
            "Slurp",  -- Yahoo
            "DuckDuckBot",
            "Baiduspider",
        },
    },
    
    -- ========================================================================
    -- IP过滤配置
    -- ========================================================================
    ip_filter = {
        enabled = true,
        
        -- IP黑名单文件
        blacklist_file = "rules/ip_blacklist.txt",
        
        -- IP白名单文件
        whitelist_file = "rules/ip_whitelist.txt",
        
        -- 缓存时间 (秒)
        cache_ttl = 3600,
    },
    
    -- ========================================================================
    -- GeoIP地理位置过滤
    -- ========================================================================
    geoip = {
        enabled = true,
        
        -- GeoIP数据库路径
        database_path = "data/geoip/GeoLite2-Country.mmdb",
        
        -- 国家黑名单 (ISO 3166-1 alpha-2 代码)
        blacklist_countries = {
            -- "KP",  -- 朝鲜
            -- "IR",  -- 伊朗
        },
        
        -- 国家白名单 (如果设置，则只允许白名单国家)
        whitelist_countries = {
            -- "CN",  -- 中国
            -- "US",  -- 美国
        },
        
        -- 是否使用白名单模式 (true=仅允许白名单, false=仅拒绝黑名单)
        whitelist_mode = false,
        
        -- 缓存时间 (秒)
        cache_ttl = 3600,
    },
    
    -- ========================================================================
    -- 频率限制配置
    -- ========================================================================
    rate_limit = {
        enabled = true,
        
        -- 全局限制
        global = {
            enabled = true,
            rate = 1000,      -- 每秒请求数
            burst = 2000,     -- 突发请求数
        },
        
        -- 单IP限制
        per_ip = {
            enabled = true,
            rate = 10,        -- 每秒10次
            burst = 20,       -- 突发20次
            window = 1,       -- 时间窗口(秒)
        },
        
        -- 单URI限制
        per_uri = {
            enabled = false,
            rate = 100,
            burst = 200,
        },
        
        -- 限流后的动作
        action = "block",  -- block | challenge | captcha
        
        -- 存储后端
        backend = "shared_dict",  -- shared_dict | redis
    },
    
    -- ========================================================================
    -- 防爬虫配置
    -- ========================================================================
    anti_crawler = {
        enabled = true,
        
        -- User-Agent检测
        ua_check = {
            enabled = true,
            -- 爬虫UA规则文件
            crawler_ua_file = "rules/crawler_ua.json",
            -- 合法爬虫白名单文件
            good_bot_file = "rules/good_bot_ua.json",
        },
        
        -- 行为分析
        behavior_analysis = {
            enabled = true,
            -- 访问频率阈值
            request_threshold = 100,  -- 每分钟
            -- 单会话最大请求数
            session_max_requests = 1000,
            -- 会话超时时间(秒)
            session_timeout = 1800,
        },
        
        -- 指纹识别
        fingerprint = {
            enabled = true,
            -- HTTP头检测
            check_headers = true,
            -- 空UA检测
            check_empty_ua = true,
        },
        
        -- 蜜罐陷阱
        honeypot = {
            enabled = false,
            uris = {
                "/admin/",
                "/wp-admin/",
            },
        },
        
        -- JS挑战
        js_challenge = {
            enabled = true,
            -- 挑战有效期(秒)
            valid_time = 300,
            -- 挑战难度 (1-5)
            difficulty = 2,
        },
        
        -- 验证码
        captcha = {
            enabled = false,
            -- 触发阈值 (爬虫评分)
            threshold = 80,
        },
        
        -- 爬虫评分阈值
        score_threshold = 70,  -- 超过此分数视为爬虫
        
        -- 动作
        action = "challenge",  -- log | challenge | captcha | block
    },
    
    -- ========================================================================
    -- 攻击防护配置
    -- ========================================================================
    attack_defense = {
        enabled = true,
        
        -- SQL注入防护
        sql_injection = {
            enabled = true,
            check_args = true,
            check_post = true,
            check_cookie = false,
        },
        
        -- XSS防护
        xss = {
            enabled = true,
            check_args = true,
            check_post = true,
        },
        
        -- 命令注入防护
        command_injection = {
            enabled = true,
            check_args = true,
            check_post = true,
        },
        
        -- 文件包含防护
        file_inclusion = {
            enabled = true,
            check_args = true,
        },
        
        -- 路径遍历防护
        path_traversal = {
            enabled = true,
            check_uri = true,
            check_args = true,
        },
        
        -- 敏感文件访问防护
        sensitive_file = {
            enabled = true,
            extensions = {".bak", ".sql", ".zip", ".tar", ".gz"},
        },
    },
    
    -- ========================================================================
    -- CC攻击防护
    -- ========================================================================
    cc_defense = {
        enabled = true,
        
        -- QPS阈值
        threshold = 10000,
        
        -- 检测窗口(秒)
        window = 10,
        
        -- 动作
        action = "challenge",  -- challenge | captcha | block
        
        -- 自动封禁
        auto_ban = {
            enabled = true,
            duration = 3600,  -- 封禁时长(秒)
        },
    },
    
    -- ========================================================================
    -- Redis配置
    -- ========================================================================
    redis = {
        enabled = false,
        host = "127.0.0.1",
        port = 6379,
        password = "",
        database = 0,
        timeout = 1000,  -- 毫秒
        pool_size = 100,
        keepalive_timeout = 60000,  -- 毫秒
    },
    
    -- ========================================================================
    -- 日志配置
    -- ========================================================================
    logging = {
        enabled = true,
        
        -- 日志级别: DEBUG | INFO | WARN | ERROR | CRITICAL
        level = "INFO",
        
        -- 日志格式: json | text
        format = "json",
        
        -- 日志文件路径
        access_log = "logs/access.log",
        attack_log = "logs/attack.log",
        error_log = "logs/error.log",
        
        -- 是否记录正常请求
        log_normal_request = false,
    },
    
    -- ========================================================================
    -- 性能配置
    -- ========================================================================
    performance = {
        -- 共享内存字典大小
        dict_size = {
            cache = "100m",
            blacklist = "50m",
            stats = "100m",
            rate_limit = "50m",
        },
        
        -- 缓存配置
        cache = {
            -- IP查询缓存时间(秒)
            ip_ttl = 3600,
            -- 规则缓存时间(秒)
            rule_ttl = 300,
            -- GeoIP缓存时间(秒)
            geoip_ttl = 3600,
        },
    },
    
    -- ========================================================================
    -- 告警配置
    -- ========================================================================
    alert = {
        enabled = false,
        
        -- 邮件告警
        email = {
            enabled = false,
            smtp_server = "smtp.example.com",
            smtp_port = 587,
            from = "waf@example.com",
            to = {"admin@example.com"},
        },
        
        -- Webhook告警 (钉钉/企业微信)
        webhook = {
            enabled = false,
            url = "",
            token = "",
        },
        
        -- 告警阈值
        threshold = {
            -- 每分钟攻击次数
            attack_per_minute = 100,
            -- 每分钟封禁IP数
            ban_per_minute = 10,
        },
    },
}

return _M

