#!/bin/bash

# 设置变量
DOCKER_USERNAME="kkape"
IMAGE_NAME="dailyhot-data-save"
VERSION="1.0.2"

echo "开始构建和推送镜像..."

# 构建并推送完整版镜像
echo "构建完整版镜像: $DOCKER_USERNAME/$IMAGE_NAME:$VERSION"
docker build -t $DOCKER_USERNAME/$IMAGE_NAME:$VERSION -t $DOCKER_USERNAME/$IMAGE_NAME:full-$VERSION -f Dockerfile . || { echo "构建完整版镜像失败"; exit 1; }

# 构建并推送精简版镜像
echo "构建精简版镜像: $DOCKER_USERNAME/$IMAGE_NAME:minimal-$VERSION"
docker build -t $DOCKER_USERNAME/$IMAGE_NAME:minimal-$VERSION -f Dockerfile.minimal . || { echo "构建精简版镜像失败"; exit 1; }

# 添加latest标签
echo "添加latest标签..."
docker tag $DOCKER_USERNAME/$IMAGE_NAME:$VERSION $DOCKER_USERNAME/$IMAGE_NAME:latest

# 登录到Docker Hub
echo "登录到Docker Hub..."
docker login || { echo "登录Docker Hub失败"; exit 1; }

# 推送镜像到Docker Hub
echo "推送完整版镜像..."
docker push $DOCKER_USERNAME/$IMAGE_NAME:$VERSION || { echo "推送版本镜像失败"; exit 1; }
docker push $DOCKER_USERNAME/$IMAGE_NAME:full-$VERSION || { echo "推送完整版镜像失败"; exit 1; }
docker push $DOCKER_USERNAME/$IMAGE_NAME:latest || { echo "推送latest镜像失败"; exit 1; }

echo "推送精简版镜像..."
docker push $DOCKER_USERNAME/$IMAGE_NAME:minimal-$VERSION || { echo "推送精简版镜像失败"; exit 1; }

echo "完成！所有镜像已成功上传到Docker Hub。" 