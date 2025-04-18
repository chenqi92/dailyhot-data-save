@echo off
REM 设置控制台代码页为UTF-8
chcp 65001 > nul

echo 开始拉取基础镜像...

echo 拉取 Python 基础镜像...
docker pull python:3.12-slim

echo 拉取 Redis 镜像...
docker pull redis:7

echo 拉取 TimescaleDB 镜像...
docker pull timescale/timescaledb:latest-pg15

echo 基础镜像拉取完成！
pause 