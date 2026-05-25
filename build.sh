#!/bin/bash

# MenuReader 构建脚本

set -e

echo "正在构建 MenuReader..."

# 清理旧构建
rm -rf build

# 使用Swift Package Manager构建
swift build -c release --arch arm64

# 创建.app bundle
mkdir -p build/MenuReader.app/Contents/MacOS
mkdir -p build/MenuReader.app/Contents/Resources

# 复制可执行文件
cp .build/release/MenuReader build/MenuReader.app/Contents/MacOS/

# 复制Info.plist
cp MenuReader/Info.plist build/MenuReader.app/Contents/

echo "构建完成！"
echo "运行: open build/MenuReader.app"