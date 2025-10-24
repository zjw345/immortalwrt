#!/bin/bash
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#
# Copyright (c) 2019-2024 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

# Modify default IP
#sed -i 's/192.168.1.1/192.168.50.5/g' package/base-files/files/bin/config_generate

# Modify default theme
#sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile

# Modify hostname
#sed -i 's/OpenWrt/P3TERX-Router/g' package/base-files/files/bin/config_generate






















#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#

# 修改默认IP
#sed -i 's/192.168.1.1/192.168.50.5/g' package/base-files/files/bin/config_generate

# --- 在此添加内置 sing-box 核心的逻辑 ---

# 1. 设置目标架构和 sing-box 项目地址
ARCH="arm64"
SING_BOX_REPO="SagerNet/sing-box"

# 2. 创建 OpenClash 所需的核心存放目录
# 我们在 'files' 目录下创建这个结构，'files' 目录下的所有文件和文件夹都会被原样复制到固件的根目录'/'下
mkdir -p files/etc/openclash/core

# 3. 获取最新的 sing-box release 版本号
# 通过 GitHub API 获取最新 release 的 tag_name，例如 "v1.9.0"
latest_tag=$(curl -sL "https://api.github.com/repos/${SING_BOX_REPO}/releases/latest" | jq -r ".tag_name")
if [ -z "$latest_tag" ]; then
    echo "::error::Failed to fetch latest sing-box tag. Please check network or API rate limit."
    exit 1
fi
echo "成功获取到最新的 sing-box 版本: $latest_tag"

# 4. 构建下载链接
# 从 tag_name (如 v1.9.0) 中去掉 'v'，得到版本号 (1.9.0)
version_num=${latest_tag#v}
download_url="https://github.com/${SING_BOX_REPO}/releases/download/${latest_tag}/sing-box-${version_num}-linux-${ARCH}.tar.gz"

# 5. 下载、解压并放置核心文件
echo "正在从以下链接下载 sing-box 核心:"
echo "$download_url"
wget -qO "sing-box.tar.gz" "$download_url"

# 解压下载的 tar.gz 文件
tar -xzf "sing-box.tar.gz"
# 进入解压后的文件夹
cd "sing-box-${version_num}-linux-${ARCH}"
# 将 sing-box 核心文件移动到我们创建的目标位置
mv sing-box ../files/etc/openclash/core/sing-box
# 返回上一级目录
cd ..

# 6. 赋予核心文件可执行权限并清理
chmod +x files/etc/openclash/core/sing-box
rm -rf "sing-box-${version_num}-linux-${ARCH}" "sing-box.tar.gz"

echo "sing-box 核心已成功内置到固件中!"
# --- 内置 sing-box 核心的逻辑结束 ---