# 使用官方 Python 基础镜像
FROM python:3.12-slim

# 设置工作目录
WORKDIR /app

# 复制 requirements.txt 并安装依赖
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 复制应用代码
COPY app.py .

# 设置默认环境变量（可以在 docker-compose 或 docker run 时覆盖）
ENV API_URL=http://127.0.0.1:6688
ENV REDIS_HOST=redis
ENV REDIS_PORT=6379
ENV REDIS_DB=0
ENV REDIS_PASSWORD=your_redis_password
ENV ENABLE_REDIS2=false
ENV REDIS2_HOST=redis2
ENV REDIS2_PORT=6379
ENV REDIS2_DB=0
ENV REDIS2_PASSWORD=your_redis_password
ENV TIMESCALEDB_HOST=timescaledb
ENV TIMESCALEDB_PORT=5432
ENV TIMESCALEDB_USER=postgres
ENV TIMESCALEDB_PASSWORD=your_timescaledb_password

# 添加版本标签
LABEL version="1.0.0"
LABEL maintainer="kkape"

# 启动应用
CMD ["python", "app.py"]