## 说明
用于将项目git@github.com:imsyy/DailyHotApi.git获取的新闻热搜数据储存至时序库中
时序库使用的时是timescaledb
同时将最新的一条热搜数据以平台为key储存至redis中

### 新特性
- 按年份自动创建数据库：数据库名格式为 `daily_hot_年份`
- 自动检测数据跨年：当数据时间戳跨年时，自动创建新的年份数据库并将数据插入其中
- 表名简化：表名格式为 `records_平台名称`，不再包含年份
- 时间自动分片：每个表按天自动分片，优化查询性能
- 自动检测数据库：启动时自动检测数据库是否存在，不存在则创建
- 第二个Redis可选：可选择是否启用第二个Redis进行数据备份

### 环境变量配置
在使用前，需要配置以下环境变量：

| 变量名 | 说明 | 默认值 |
|--------|------|--------|
| API_URL | 热搜API地址 | http://192.168.0.120:6688/all |
| REDIS_HOST | Redis主机地址 | redis |
| REDIS_PORT | Redis端口 | 6379 |
| REDIS_DB | Redis数据库索引 | 0 |
| REDIS_PASSWORD | Redis密码 | your_redis_password |
| ENABLE_REDIS2 | 是否启用第二个Redis | false |
| REDIS2_HOST | 第二个Redis主机地址 | redis2 |
| REDIS2_PORT | 第二个Redis端口 | 6379 |
| REDIS2_DB | 第二个Redis数据库索引 | 0 |
| REDIS2_PASSWORD | 第二个Redis密码 | your_redis_password |
| TIMESCALEDB_HOST | TimescaleDB主机地址 | timescaledb |
| TIMESCALEDB_PORT | TimescaleDB端口 | 5432 |
| TIMESCALEDB_USER | TimescaleDB用户名 | postgres |
| TIMESCALEDB_PASSWORD | TimescaleDB密码 | yourpassword |

### 使用方法

#### 1. 使用Docker Compose运行

1. 克隆仓库：
```bash
git clone https://github.com/yourusername/dailyhot-data-save.git
cd dailyhot-data-save
```

2. 创建环境变量文件：
```bash
cp .env.sample .env
```

3. 编辑`.env`文件，设置必要的环境变量：
```
API_URL=http://192.168.0.120:6688/all
REDIS_PASSWORD=your_redis_password
TIMESCALEDB_PASSWORD=yourpassword
# 是否启用第二个Redis
ENABLE_REDIS2=false
# 如果启用第二个Redis，需要设置以下变量
REDIS2_PASSWORD=your_redis_password
```

4. 使用Docker Compose启动服务：
```bash
# 如果不需要第二个Redis
docker-compose up --build -d

# 如果需要启用第二个Redis
docker-compose --profile redis2 up --build -d
```

5. 查看日志：
```bash
docker-compose logs -f app
```

#### 2. 使用Docker Hub镜像

1. 拉取镜像：
```bash
docker pull kkape/dailyhot-data-save:1.0.0
```

2. 创建环境变量文件：
```bash
cp .env.sample .env
```

3. 编辑`.env`文件，设置必要的环境变量

4. 使用Docker Compose启动服务：
```bash
# 如果不需要第二个Redis
docker-compose -f docker-compose.hub.yml up -d

# 如果需要启用第二个Redis
docker-compose -f docker-compose.hub.yml --profile redis2 up -d
```

### 构建并推送Docker镜像到Docker Hub

#### Linux/macOS
```bash
# 添加执行权限
chmod +x build-and-push.sh

# 执行脚本
./build-and-push.sh
```

#### Windows
```bash
# 执行批处理文件
build-and-push.bat
```

### 数据持久化
- Redis数据存储在`redis-data`卷中
- 第二个Redis数据存储在`redis2-data`卷中（如果启用）
- TimescaleDB数据存储在`timescaledb-data`卷中

### 版本信息
当前版本：1.0.0