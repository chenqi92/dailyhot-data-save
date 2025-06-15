@echo off
REM 设置控制台代码页为UTF-8
chcp 65001 > nul
REM 设置控制台字体为支持中文的字体
reg add "HKEY_CURRENT_USER\Console" /v "FaceName" /t REG_SZ /d "NSimSun" /f > nul 2>&1

REM 设置变量
set DOCKER_USERNAME=kkape
set IMAGE_NAME=dailyhot-data-save
set PLATFORMS=linux/amd64,linux/arm64

REM 检查VERSION文件是否存在
if not exist "VERSION" (
    echo 错误：VERSION文件不存在！
    exit /b 1
)

set /p VERSION=<VERSION

REM 验证版本号不为空
if "%VERSION%"=="" (
    echo 错误：VERSION文件为空！
    exit /b 1
)

echo 开始构建和推送镜像...
echo 用户名: %DOCKER_USERNAME%
echo 镜像名: %IMAGE_NAME%
echo 版本号: %VERSION%

REM 构建完整版镜像
echo 构建完整版镜像: %DOCKER_USERNAME%/%IMAGE_NAME%:%VERSION%
docker build -t %DOCKER_USERNAME%/%IMAGE_NAME%:%VERSION% -t %DOCKER_USERNAME%/%IMAGE_NAME%:full-%VERSION% -t %DOCKER_USERNAME%/%IMAGE_NAME%:latest -f Dockerfile . || goto :error

REM 构建精简版镜像
echo 构建精简版镜像: %DOCKER_USERNAME%/%IMAGE_NAME%:minimal-%VERSION%
docker build -t %DOCKER_USERNAME%/%IMAGE_NAME%:minimal-%VERSION% -t %DOCKER_USERNAME%/%IMAGE_NAME%:minimal-latest -f Dockerfile.minimal . || goto :error

REM 检查Docker是否运行
echo 检查Docker状态...
docker info >nul 2>&1 || (
    echo 错误：Docker未运行或无法访问！请启动Docker后重试。
    goto :error
)

REM 登录到Docker Hub
echo 登录到Docker Hub...
docker login || goto :error

REM 推送完整版镜像
echo 推送完整版镜像...
docker push %DOCKER_USERNAME%/%IMAGE_NAME%:%VERSION% || goto :error
docker push %DOCKER_USERNAME%/%IMAGE_NAME%:full-%VERSION% || goto :error
docker push %DOCKER_USERNAME%/%IMAGE_NAME%:latest || goto :error

REM 推送精简版镜像
echo 推送精简版镜像...
docker push %DOCKER_USERNAME%/%IMAGE_NAME%:minimal-%VERSION% || goto :error
docker push %DOCKER_USERNAME%/%IMAGE_NAME%:minimal-latest || goto :error

echo 完成！所有镜像已成功上传到Docker Hub。
echo 完整版镜像标签: %VERSION%, full-%VERSION%, latest
echo 精简版镜像标签: minimal-%VERSION%, minimal-latest
goto :end

:error
echo 发生错误！请检查网络连接或Docker配置。
exit /b 1

:end
pause 