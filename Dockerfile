# 御渊WAF Dockerfile
FROM openresty/openresty:1.21.4.1-alpine

LABEL maintainer="YuyuanWAF <support@yuyuanwaf.org>" \
      version="1.0.0" \
      description="御渊WAF - 企业级Web应用防火墙"

# 安装依赖
RUN apk add --no-cache \
    bash \
    curl \
    git \
    lua-cjson \
    && rm -rf /var/cache/apk/*

# 创建工作目录
WORKDIR /var/www/html/YuyuanWaf

# 复制项目文件
COPY lua/ ./lua/
COPY conf/ ./conf/
COPY html/ ./html/
COPY rules/ ./rules/
COPY logs/ ./logs/
COPY data/ ./data/
COPY VERSION ./

# 创建日志目录
RUN mkdir -p /var/www/html/YuyuanWaf/logs && \
    chmod 755 /var/www/html/YuyuanWaf/logs

# 配置Nginx
RUN mkdir -p /usr/local/openresty/nginx/conf/conf.d && \
    ln -sf /var/www/html/YuyuanWaf/conf/waf.conf /usr/local/openresty/nginx/conf/waf.conf

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost/api/health || exit 1

# 暴露端口
EXPOSE 80 443

# 启动命令
CMD ["/usr/local/openresty/bin/openresty", "-g", "daemon off;"]

