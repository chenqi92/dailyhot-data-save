@echo off
REM 设置控制台代码页为UTF-8
chcp 65001 > nul
REM 设置控制台字体为支持中文的字体
reg add "HKEY_CURRENT_USER\Console" /v "FaceName" /t REG_SZ /d "NSimSun" /f > nul 2>&1

REM 设置变量
set DOCKER_USERNAME=kkape
set IMAGE_NAME=dailyhot-data-save
set VERSION=1.0.0

REM 构建Docker镜像
echo 构建Docker镜像: %DOCKER_USERNAME%/%IMAGE_NAME%:%VERSION%
docker build -t %DOCKER_USERNAME%/%IMAGE_NAME%:%VERSION% .

REM 登录到Docker Hub
echo 登录到Docker Hub...
docker login

REM 推送镜像到Docker Hub
echo 推送镜像到Docker Hub: %DOCKER_USERNAME%/%IMAGE_NAME%:%VERSION%
docker push %DOCKER_USERNAME%/%IMAGE_NAME%:%VERSION%

echo 完成！镜像已成功上传到Docker Hub。
pause 