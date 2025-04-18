# 使用官方 Python 基础镜像
FROM python:3.12-slim

# 设置工作目录
WORKDIR /app

# 复制 requirements.txt 并安装依赖
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 复制应用代码
COPY app.py .

# 设置非敏感的默认环境变量
ENV API_URL=http://127.0.0.1:6688
ENV REDIS_HOST=redis
ENV REDIS_PORT=6379
ENV REDIS_DB=0
ENV ENABLE_REDIS2=true
ENV REDIS2_HOST=redis2
ENV REDIS2_PORT=6379
ENV REDIS2_DB=0
ENV TIMESCALEDB_HOST=timescaledb
ENV TIMESCALEDB_PORT=5432
ENV TIMESCALEDB_USER=postgres
ENV TIMESCALEDB_DB=daily_hot

# 添加版本和作者信息
LABEL version="1.0.2"
LABEL maintainer="kkape <cq92104@gmail.com>"
LABEL variant="full"
LABEL org.opencontainers.image.authors="kkape"
LABEL org.opencontainers.image.version="1.0.1"
LABEL org.opencontainers.image.description="DailyHot Data Save Service - Full Version"

# 启动应用
CMD ["python", "app.py"]