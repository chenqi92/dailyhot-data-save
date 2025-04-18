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
- 支持外部数据库：可以使用已有的Redis和TimescaleDB
- 混合模式支持：可以同时使用内部和外部数据库服务

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

#### 方式一：使用Docker内置数据库（推荐新用户使用）

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
docker-compose --profile redis2 up -d
```

5. 查看日志：
```bash
docker-compose logs -f app
```

#### 方式二：使用外部数据库（适用于已有数据库的用户）

1. 克隆仓库：
```bash
git clone https://github.com/yourusername/dailyhot-data-save.git
cd dailyhot-data-save
```

2. 创建环境变量文件：
```bash
cp .env.external.sample .env
```

3. 编辑`.env`文件，配置外部数据库连接信息：
```
# 主Redis配置
REDIS_HOST=192.168.0.100
REDIS_PORT=6379
REDIS_PASSWORD=your_redis_password

# TimescaleDB配置
TIMESCALEDB_HOST=192.168.0.102
TIMESCALEDB_PORT=5432
TIMESCALEDB_PASSWORD=yourpassword

# 可选：第二个Redis配置
ENABLE_REDIS2=true
REDIS2_HOST=192.168.0.101
REDIS2_PORT=6379
REDIS2_PASSWORD=your_redis2_password
```

4. 使用外部数据库配置启动服务：
```bash
docker-compose -f docker-compose.external.yml up -d
```

#### 方式三：使用Docker Hub镜像（支持混合模式）

1. 创建环境变量文件：
```bash
cp .env.hub.sample .env
```

2. 编辑`.env`文件，根据需要配置服务：

使用全部内部服务：
```
# 启用内部服务
USE_INTERNAL_REDIS=redis
USE_INTERNAL_TIMESCALEDB=timescaledb

# Redis配置
REDIS_HOST=redis
REDIS_PASSWORD=your_redis_password

# TimescaleDB配置
TIMESCALEDB_HOST=timescaledb
TIMESCALEDB_PASSWORD=yourpassword
```

使用全部外部服务：
```
# 注释掉内部服务
#USE_INTERNAL_REDIS=redis
#USE_INTERNAL_TIMESCALEDB=timescaledb

# Redis配置
REDIS_HOST=192.168.0.100
REDIS_PASSWORD=your_redis_password

# TimescaleDB配置
TIMESCALEDB_HOST=192.168.0.102
TIMESCALEDB_PASSWORD=yourpassword
```

混合模式示例（使用内部Redis和外部TimescaleDB）：
```
# 只启用内部Redis
USE_INTERNAL_REDIS=redis
#USE_INTERNAL_TIMESCALEDB=timescaledb

# Redis配置
REDIS_HOST=redis
REDIS_PASSWORD=your_redis_password

# 外部TimescaleDB配置
TIMESCALEDB_HOST=192.168.0.102
TIMESCALEDB_PASSWORD=yourpassword
```

3. 启动服务：
```bash
# 启动所有配置的服务
docker-compose -f docker-compose.hub.yml up -d

# 如果需要第二个Redis（确保ENABLE_REDIS2=true）
docker-compose -f docker-compose.hub.yml --profile internal-redis2 up -d
```

### 数据库要求

#### TimescaleDB
- 版本要求：PostgreSQL 12及以上
- 需要安装TimescaleDB扩展
- 数据库用户需要具有创建数据库的权限

#### Redis
- 版本要求：Redis 6及以上
- 需要启用密码认证
- 建议启用持久化

### 数据持久化
- 使用Docker内置数据库时：
  - Redis数据存储在`redis-data`卷中
  - 第二个Redis数据存储在`redis2-data`卷中（如果启用）
  - TimescaleDB数据存储在`timescaledb-data`卷中
- 使用外部数据库时：
  - 数据持久化由外部数据库管理

### 版本信息
当前版本：1.0.0