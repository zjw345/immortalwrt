#!/bin/bash

# =====================================================================================
# OpenWrt 半自动化编译助手脚本 (专为 Docker Compose 环境设计)
#
# 特性:
# - 全中文彩色提示，流程清晰
# - 步骤化操作，支持单独执行克隆、配置、编译等步骤
# - 智能缓存管理，自动链接 'dl' 目录，避免重复下载
# - 强大的配置管理，支持保存和加载配置
# - 支持交互式 'make menuconfig'
# - 提供编译后进入 SSH 调试会话的选项
# =====================================================================================

# --- 基本设置 ---
# 脚本出错时立即退出
set -e
# 管道中的任何命令失败，都视为整个管道失败
set -o pipefail

# --- 颜色定义 ---
CL_RED='\033[0;31m'
CL_GREEN='\033[0;32m'
CL_YELLOW='\033[0;33m'
CL_BLUE='\033[0;34m'
CL_CYAN='\033[0;36m'
CL_NC='\033[0m' # No Color

# --- 脚本路径与项目目录定义 ---
# 获取脚本所在的目录，确保路径的正确性
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

# --- 配置项 ---
REPO_URL="https://github.com/lkiuyu/immortalwrt"
REPO_BRANCH="master"

# 工作区目录结构 (相对于脚本所在位置)
WORKSPACE_DIR="${SCRIPT_DIR}/workspace"
SOURCE_DIR="${WORKSPACE_DIR}/source"
DL_DIR="${WORKSPACE_DIR}/dl"
RELEASE_DIR="${WORKSPACE_DIR}/release"
CONFIGS_DIR="${WORKSPACE_DIR}/configs"
SCRIPTS_DIR="${WORKSPACE_DIR}/scripts"

# 默认配置文件
DEFAULT_CONFIG_FILE="${CONFIGS_DIR}/jz02.config"

# --- 辅助函数 ---
step() { echo -e "${CL_BLUE}===> ${1}${CL_NC}"; }
success() { echo -e "${CL_GREEN}>>> ${1}${CL_NC}"; }
warn() { echo -e "${CL_YELLOW}!!! ${1}${CL_NC}"; }
error() { echo -e "${CL_RED}!!! ${1}${CL_NC}"; exit 1; }

# 检查是否在容器内运行
check_in_container() {
    if [ ! -f "/.dockerenv" ]; then
        error "此脚本设计为在 Docker 容器内运行。请通过 'docker-compose exec builder bash' 进入容器后执行。"
    fi
}

# --- 核心功能函数 ---

# 1. 克隆或更新源码
task_clone() {
    step "步骤 1: 克隆或更新 OpenWrt 源码"
    if [ ! -d "${SOURCE_DIR}/.git" ]; then
        warn "源码目录不存在，正在从 GitHub 克隆..."
        git clone --depth 1 "${REPO_URL}" -b "${REPO_BRANCH}" "${SOURCE_DIR}"
    else
        success "源码目录已存在，正在拉取最新更新..."
        cd "${SOURCE_DIR}"
        git pull
    fi
    success "源码准备就绪。"
}

# 2. 准备 Feeds 和自定义内容
task_feeds() {
    step "步骤 2: 更新 Feeds 并执行自定义脚本 Part 1"
    cd "${SOURCE_DIR}" || error "源码目录不存在，请先执行 './build.sh clone'"
    
    local DIY_P1_SH="${SCRIPTS_DIR}/diy-part1.sh"
    if [ -f "$DIY_P1_SH" ]; then
        warn "找到自定义脚本 diy-part1.sh, 正在执行..."
        chmod +x "$DIY_P1_SH"
        "$DIY_P1_SH"
    fi
    
    success "正在更新和安装所有 Feeds..."
    ./scripts/feeds update -a
    ./scripts/feeds install -a
    success "Feeds 处理完成。"
}

# 3. 加载配置文件
task_config() {
    step "步骤 3: 加载配置文件并执行自定义脚本 Part 2"
    cd "${SOURCE_DIR}" || error "源码目录不存在，请先执行 './build.sh clone'"
    
    if [ ! -f "$DEFAULT_CONFIG_FILE" ]; then
        error "主配置文件 ${DEFAULT_CONFIG_FILE} 未找到！"
    fi
    
    success "正在从 ${DEFAULT_CONFIG_FILE} 加载配置..."
    cp "$DEFAULT_CONFIG_FILE" ./.config

    local DIY_P2_SH="${SCRIPTS_DIR}/diy-part2.sh"
    if [ -f "$DIY_P2_SH" ]; then
        warn "找到自定义脚本 diy-part2.sh, 正在执行..."
        chmod +x "$DIY_P2_SH"
        "$DIY_P2_SH"
    fi
    
    success "正在标准化配置..."
    make defconfig
    success "配置加载并标准化完成。"
}

# 3a. 打开交互式菜单配置
task_menuconfig() {
    step "步骤 3a: 进入交互式配置菜单 (make menuconfig)"
    cd "${SOURCE_DIR}" || error "源码目录不存在，请先执行 './build.sh clone'"
    
    # 确保依赖已安装
    make prereq
    
    make menuconfig
    success "menuconfig 已退出。如果进行了修改，建议运行 './build.sh save_config' 来保存您的配置。"
}

# 3b. 保存当前配置
task_save_config() {
    step "步骤 3b: 备份当前 .config 文件"
    cd "${SOURCE_DIR}" || error "源码目录不存在。"
    
    if [ ! -f ".config" ]; then
        error "源码目录下没有找到 .config 文件。请先运行 './build.sh config' 或 './build.sh menuconfig'。"
    fi
    
    local BACKUP_FILE="${CONFIGS_DIR}/jz02.config.$(date +%Y%m%d-%H%M%S)"
    success "正在将当前配置备份到 ${BACKUP_FILE}"
    cp .config "$BACKUP_FILE"
    warn "您也可以手动将它重命名为 'jz02.config' 以作为未来的主配置文件。"
}

# 4. 下载源码包
task_download() {
    step "步骤 4: 下载所有软件包源码"
    cd "${SOURCE_DIR}" || error "源码目录不存在。"
    
    # 确保下载缓存目录存在并创建软链接
    mkdir -p "$DL_DIR"
    if [ ! -L "dl" ]; then
        ln -s "$DL_DIR" dl
    fi

    make download -j$(nproc)
    success "软件包下载完成。"
}


# 5. 开始编译
task_compile() {
    step "步骤 5: 开始编译固件 (过程漫长，请耐心等待)"
    cd "${SOURCE_DIR}" || error "源码目录不存在。"

    local CPU_CORES=$(nproc)
    warn "将使用 ${CPU_CORES} 个CPU核心进行编译..."
    
    make -j${CPU_CORES} V=s 2>&1 | tee /workspace/build.log

    if [ ${PIPESTATUS[0]} -ne 0 ]; then
        error "编译失败！详细日志已保存到 workspace/build.log 文件中。"
        warn "您可以尝试使用单线程进行调试: 'make -j1 V=s'"
        exit 1
    fi
    
    success "编译成功！"
}

# 6. 整理产物
task_release() {
    step "步骤 6: 整理编译产物"
    cd "${SOURCE_DIR}"
    
    warn "正在清理旧的产物目录..."
    rm -rf "${RELEASE_DIR:?}"/* # The :? ensures we don't delete root if var is empty

    local FIRMWARE_DIR="${SOURCE_DIR}/bin/targets/msm89xx/msm8916"
    if [ -d "$FIRMWARE_DIR" ]; then
        success "正在将固件复制到 ${RELEASE_DIR}..."
        cp -r ${FIRMWARE_DIR}/* "$RELEASE_DIR/"
        success "产物整理完成！请在您 Windows 主机的 'workspace/release' 目录下查看。"
    else
        error "编译产物目录未找到！编译可能并未生成固件。"
    fi
}

# 清理
task_clean() {
    step "清理编译环境"
    cd "${SOURCE_DIR}" || error "源码目录不存在。"
    read -p "您确定要清理编译产物吗？(make clean) [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        make clean
        success "清理完成。"
    else
        warn "操作已取消。"
    fi
}

# 深度清理
task_distclean() {
    step "深度清理编译环境"
    cd "${SOURCE_DIR}" || error "源码目录不存在。"
    read -p "警告：这将删除所有配置、工具链和产物！(make distclean) 您确定吗？ [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        make distclean
        success "深度清理完成。"
    else
        warn "操作已取消。"
    fi
}

# 启动 SSH 调试会话
task_ssh() {
    step "启动 tmate SSH 调试会话"
    warn "会话将保持运行，直到您手动关闭容器。按 Ctrl+C 无法终止。"
    tmate -S /tmp/tmate.sock new-session -d
    tmate -S /tmp/tmate.sock wait tmate-ready
    echo -e "${CL_CYAN}请使用以下命令连接到容器 (在您的主机上):${CL_NC}"
    tmate -S /tmp/tmate.sock display -p '#{tmate_ssh}'
    sleep infinity
}


# 帮助文档
task_help() {
    echo -e "${CL_CYAN}OpenWrt 半自动化编译助手${CL_NC}"
    echo "--------------------------------------------------"
    echo "用法: ./build.sh [命令]"
    echo
    echo -e "${CL_GREEN}常用命令:${CL_NC}"
    echo "  all         - 【全自动】执行从'克隆'到'打包'的完整流程"
    echo "  menuconfig  - 【交互】进入图形化配置菜单，用于修改固件内容"
    echo "  compile     - 【编译】仅执行编译步骤"
    echo
    echo -e "${CL_YELLOW}分步命令:${CL_NC}"
    echo "  clone       - 克隆或更新 OpenWrt 源码"
    echo "  feeds       - 更新并安装 Feeds 软件源"
    echo "  config      - 加载默认配置文件 'jz02.config'"
    echo "  download    - 预下载所有软件包源码"
    echo "  release     - 将编译好的固件整理到 'workspace/release' 目录"
    echo
    echo -e "${CL_BLUE}配置管理:${CL_NC}"
    echo "  save_config - 将 'make menuconfig' 后的修改备份到 'configs' 目录"
    echo
    echo -e "${CL_RED}清理命令:${CL_NC}"
    echo "  clean       - 清理编译产物 (make clean)"
    echo "  distclean   - 深度清理，删除所有配置和工具链 (make distclean)"
    echo
    echo -e "${CL_CYAN}调试命令:${CL_NC}"
    echo "  ssh         - 启动一个 tmate SSH 会话，用于远程登录容器"
    echo
}

# --- 主逻辑入口 ---
check_in_container

# 根据传入的第一个参数执行对应任务
case "$1" in
    all)
        task_clone
        task_feeds
        task_config
        task_download
        task_compile
        task_release
        ;;
    clone) task_clone ;;
    feeds) task_feeds ;;
    config) task_config ;;
    menuconfig) task_menuconfig ;;
    save_config) task_save_config ;;
    download) task_download ;;
    compile) task_compile ;;
    release) task_release ;;
    clean) task_clean ;;
    distclean) task_distclean ;;
    ssh) task_ssh ;;
    help|*) task_help ;;
esac
