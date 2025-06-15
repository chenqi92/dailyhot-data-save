#!/bin/bash

# 设置错误时退出
set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 设置变量
DOCKER_USERNAME="kkape"
IMAGE_NAME="dailyhot-data-save"
PLATFORMS="linux/amd64,linux/arm64"
BUILDER_NAME="multiarch-builder"

# 检查VERSION文件是否存在
if [ ! -f "VERSION" ]; then
    print_error "VERSION文件不存在！"
    exit 1
fi

# 读取版本号并验证
VERSION=$(cat VERSION | tr -d '\n\r')
if [ -z "$VERSION" ]; then
    print_error "VERSION文件为空！"
    exit 1
fi

print_info "开始构建和推送Docker镜像..."
print_info "用户名: $DOCKER_USERNAME"
print_info "镜像名: $IMAGE_NAME"
print_info "版本号: $VERSION"
print_info "支持平台: $PLATFORMS"

# 检查Docker是否运行
if ! docker info >/dev/null 2>&1; then
    print_error "Docker未运行或无法访问！请启动Docker后重试。"
    exit 1
fi

# 检查是否已登录Docker Hub
print_info "检查Docker Hub登录状态..."
if ! docker info | grep -q "Username: $DOCKER_USERNAME" 2>/dev/null; then
    print_warning "未检测到Docker Hub登录状态，请确保已登录到Docker Hub"
    print_info "如需登录，请运行: docker login"
    read -p "是否继续构建？(y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "构建已取消"
        exit 0
    fi
fi

# 检查并创建buildx构建器
print_info "设置Docker BuildX多平台构建器..."
if docker buildx inspect $BUILDER_NAME >/dev/null 2>&1; then
    print_info "构建器 $BUILDER_NAME 已存在，使用现有构建器"
    docker buildx use $BUILDER_NAME
else
    print_info "创建新的构建器 $BUILDER_NAME"
    docker buildx create --use --name $BUILDER_NAME --driver docker-container
fi

# 启动构建器
print_info "启动构建器..."
docker buildx inspect --bootstrap

# 检查Dockerfile是否存在
if [ ! -f "Dockerfile" ]; then
    print_error "Dockerfile不存在！"
    exit 1
fi

# 构建并推送完整版镜像（多平台）
print_info "构建并推送完整版镜像..."
print_info "标签: $DOCKER_USERNAME/$IMAGE_NAME:$VERSION, $DOCKER_USERNAME/$IMAGE_NAME:latest"
docker buildx build --platform $PLATFORMS \
    -t $DOCKER_USERNAME/$IMAGE_NAME:$VERSION \
    -t $DOCKER_USERNAME/$IMAGE_NAME:latest \
    -f Dockerfile --push .

print_success "完整版镜像构建并推送成功！"

# 检查是否存在精简版Dockerfile
if [ -f "Dockerfile.minimal" ]; then
    print_info "构建并推送精简版镜像..."
    print_info "标签: $DOCKER_USERNAME/$IMAGE_NAME:minimal-$VERSION, $DOCKER_USERNAME/$IMAGE_NAME:minimal-latest"
    docker buildx build --platform $PLATFORMS \
        -t $DOCKER_USERNAME/$IMAGE_NAME:minimal-$VERSION \
        -t $DOCKER_USERNAME/$IMAGE_NAME:minimal-latest \
        -f Dockerfile.minimal --push .
    
    print_success "精简版镜像构建并推送成功！"
    print_success "所有镜像已成功推送到Docker Hub！"
    echo
    print_info "推送的镜像标签:"
    echo "  完整版: $DOCKER_USERNAME/$IMAGE_NAME:$VERSION, $DOCKER_USERNAME/$IMAGE_NAME:latest"
    echo "  精简版: $DOCKER_USERNAME/$IMAGE_NAME:minimal-$VERSION, $DOCKER_USERNAME/$IMAGE_NAME:minimal-latest"
else
    print_warning "未找到Dockerfile.minimal，跳过精简版镜像构建"
    print_success "完整版镜像已成功推送到Docker Hub！"
    echo
    print_info "推送的镜像标签:"
    echo "  完整版: $DOCKER_USERNAME/$IMAGE_NAME:$VERSION, $DOCKER_USERNAME/$IMAGE_NAME:latest"
fi

echo
print_success "构建和推送完成！"
print_info "可以使用以下命令拉取镜像:"
echo "  docker pull $DOCKER_USERNAME/$IMAGE_NAME:$VERSION"
echo "  docker pull $DOCKER_USERNAME/$IMAGE_NAME:latest"