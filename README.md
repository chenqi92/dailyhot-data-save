## 说明
用于将项目git@github.com:imsyy/DailyHotApi.git获取的新闻热搜数据储存至时序库中
时序库使用的时是timescaledb
同时将最新的一条热搜数据以平台为key储存至redis中

直接使用docker-compose即可使用docker运行
```
docker-compose up --build -d
```