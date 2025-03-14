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

### 使用方法
直接使用docker-compose即可使用docker运行
```
docker-compose up --build -d
```