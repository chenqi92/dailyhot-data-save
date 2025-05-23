#!/bin/bash

# 设置变量
DOCKER_USERNAME="kkape"
IMAGE_NAME="dailyhot-data-save"
VERSION=$(cat VERSION)
PLATFORMS="linux/amd64,linux/arm64"

echo "开始构建和推送镜像..."

# 启用 buildx
echo "启用 Docker BuildX..."
docker buildx create --use --name multiarch-builder || { echo "创建buildx构建器失败"; exit 1; }

# 构建并推送完整版镜像（多平台）
echo "构建并推送完整版镜像: $DOCKER_USERNAME/$IMAGE_NAME:$VERSION"
docker buildx build --platform $PLATFORMS \
    -t $DOCKER_USERNAME/$IMAGE_NAME:$VERSION \
    -t $DOCKER_USERNAME/$IMAGE_NAME:full-$VERSION \
    -t $DOCKER_USERNAME/$IMAGE_NAME:latest \
    -f Dockerfile --push . || { echo "构建完整版镜像失败"; exit 1; }

# 构建并推送精简版镜像（多平台）
echo "构建并推送精简版镜像: $DOCKER_USERNAME/$IMAGE_NAME:minimal-$VERSION"
docker buildx build --platform $PLATFORMS \
    -t $DOCKER_USERNAME/$IMAGE_NAME:minimal-$VERSION \
    -t $DOCKER_USERNAME/$IMAGE_NAME:minimal-latest \
    -f Dockerfile.minimal --push . || { echo "构建精简版镜像失败"; exit 1; }

echo "完成！所有镜像已成功上传到Docker Hub。"
echo "完整版镜像标签: $VERSION, full-$VERSION, latest"
echo "精简版镜像标签: minimal-$VERSION, minimal-latest" 