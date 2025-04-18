@echo off
REM 设置控制台代码页为UTF-8
chcp 65001 > nul
REM 设置控制台字体为支持中文的字体
reg add "HKEY_CURRENT_USER\Console" /v "FaceName" /t REG_SZ /d "NSimSun" /f > nul 2>&1

REM 设置变量
set DOCKER_USERNAME=kkape
set IMAGE_NAME=dailyhot-data-save
set VERSION=1.0.0

echo 开始构建和推送镜像...

REM 构建并推送完整版镜像
echo 构建完整版镜像: %DOCKER_USERNAME%/%IMAGE_NAME%:%VERSION%
docker build -t %DOCKER_USERNAME%/%IMAGE_NAME%:%VERSION% -t %DOCKER_USERNAME%/%IMAGE_NAME%:full-%VERSION% -f Dockerfile . || goto :error

REM 构建并推送精简版镜像
echo 构建精简版镜像: %DOCKER_USERNAME%/%IMAGE_NAME%:minimal-%VERSION%
docker build -t %DOCKER_USERNAME%/%IMAGE_NAME%:minimal-%VERSION% -f Dockerfile.minimal . || goto :error

REM 登录到Docker Hub
echo 登录到Docker Hub...
docker login || goto :error

REM 推送镜像到Docker Hub
echo 推送完整版镜像...
docker push %DOCKER_USERNAME%/%IMAGE_NAME%:%VERSION% || goto :error
docker push %DOCKER_USERNAME%/%IMAGE_NAME%:full-%VERSION% || goto :error

echo 推送精简版镜像...
docker push %DOCKER_USERNAME%/%IMAGE_NAME%:minimal-%VERSION% || goto :error

echo 完成！所有镜像已成功上传到Docker Hub。
goto :end

:error
echo 发生错误！请检查网络连接或Docker配置。
exit /b 1

:end
pause 