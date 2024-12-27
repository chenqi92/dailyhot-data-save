# 使用官方 Python 基础镜像
FROM python:3.11-slim

# 设置工作目录
WORKDIR /app

# 复制 requirements.txt 并安装依赖
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 复制应用代码
COPY app.py .

# 设置默认环境变量（可在 docker-compose 或 docker run 时覆盖）
ENV API_URL=http://192.168.0.120:6688/all
ENV REDIS_HOST=redis
ENV REDIS_PORT=6379
ENV REDIS_DB=0
ENV REDIS_PASSWORD=your_redis_password
ENV TIMESCALEDB_HOST=timescaledb
ENV TIMESCALEDB_PORT=5432
ENV TIMESCALEDB_USER=postgres
ENV TIMESCALEDB_PASSWORD=yourpassword
ENV TIMESCALEDB_DB=postgres

# 启动应用
CMD ["python", "app.py"]
