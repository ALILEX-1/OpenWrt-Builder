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
# 参考：https://github.com/217heidai/OpenWrt-Builder

function config_del(){
    yes="CONFIG_$1=y"
    no="# CONFIG_$1 is not set"

    sed -i "s/$yes/$no/" .config

    if ! grep -q "$yes" .config; then
        echo "$no" >> .config
    fi
}

function config_add(){
    yes="CONFIG_$1=y"
    no="# CONFIG_$1 is not set"

    sed -i "s/${no}/${yes}/" .config

    if ! grep -q "$yes" .config; then
        echo "$yes" >> .config
    fi
}

function config_package_del(){
    package="PACKAGE_$1"
    config_del $package
}

function config_package_add(){
    package="PACKAGE_$1"
    config_add $package
    echo "添加处理包: [$package]"
}

function drop_package(){
    if [ "$1" != "golang" ];then
        # feeds/base -> package
        find package/ -follow -name $1 -not -path "package/custom/*" | xargs -rt rm -rf
        find feeds/ -follow -name $1 -not -path "feeds/base/custom/*" | xargs -rt rm -rf
    fi
}

function clean_packages(){
    path=$1
    echo "开始清理目录: $path"

    if [ ! -d "$path" ]; then
        echo "警告: 目录 $path 不存在"
        return
    fi

    # 获取目录下的所有子目录名
    dir=$(ls -l "${path}" 2>/dev/null | awk '/^d/ {print $NF}')

    if [ -z "$dir" ]; then
        echo "目录 $path 中没有子目录"
        return
    fi

    for item in ${dir}
        do
            echo "处理包: $item"
            drop_package "${item}"
        done

    echo "完成清理目录: $path"
}


# Git稀疏克隆，只克隆指定目录到本地
function git_clone() {
  git clone --depth 1 $1 $2 || true
}

function git_sparse_clone() {
  branch="$1" rurl="$2" localdir="$3" && shift 3
  # 1. 克隆指定分支的仓库到一个临时目录，但不检出任何文件
  git clone -b $branch --depth 1 --filter=blob:none --sparse $rurl $localdir
  cd $localdir
  # 2. 初始化稀疏检出功能
  git sparse-checkout init --cone
  # 3. 设置需要检出的具体目录/文件
  git sparse-checkout set $@
  # 4. 将检出的目录/文件移动到编译环境的 package 目录下
  mv -n $@ ../package
  cd ..
  # 5. 删除临时目录，清理现场
  rm -rf $localdir
}

##########################
#设置官方默认包https://downloads.immortalwrt.org/releases/24.10.0/targets/x86/64/profiles.json
default_packages=(
    "autocore"
    "automount"
    "autosamba"
    "base-files"
    "block-mount"
    "bridge"
    "bridger"
    "ca-bundle"
    "default-settings-chn"
    "dnsmasq-full"
    "dropbear"
    "fdisk"
    "firewall4"
    "fstools"
    "grub2-bios-setup"
    "geoview"
    "i915-firmware"
    "i915-firmware-dmc"
    "kmod-8139cp"
    "kmod-8139too"
    "kmod-button-hotplug"
    "kmod-e1000e"
    "kmod-fs-f2fs"
    "kmod-i40e"
    "kmod-igb"
    "kmod-igbvf"
    "kmod-igc"
    "kmod-ixgbe"
    "kmod-ixgbevf"
    "kmod-nf-nathelper"
    "kmod-nf-nathelper-extra"
    "kmod-nft-offload"
    "kmod-pcnet32"
    "kmod-r8101"
    "kmod-r8125"
    "kmod-r8126"
    "kmod-r8168"
    "kmod-tulip"
    "kmod-usb-hid"
    "kmod-usb-net"
    "kmod-usb-net-asix"
    "kmod-usb-net-asix-ax88179"
    "kmod-usb-net-rtl8150"
    "kmod-usb-net-rtl8152-vendor"
    "kmod-vmxnet3"
    "kmod-fs-exfat"
    "kmod-fs-nfts3"
    "kmod-fs-btrfs"
    "kmod-fs-ext4"
    "kmod-sched-cake"
    "libc"
    "libgcc"
    "libustream-openssl"
    "logd"
    "luci-app-package-manager"
    "luci-app-nlbwmon"
    "luci-app-sqm"
    "luci-compat"
    "luci-lib-base"
    "luci-lib-ipkg"
    "luci-light"
    "luci-app-samba4"
    "mkf2fs"
    "mtd"
    "netifd"
    "nftables"
    "odhcp6c"
    "odhcpd-ipv6only"
    "opkg"
    "partx-utils"
    "ppp"
    "ppp-mod-pppoe"
    "procd-ujail"
    "uci"
    "uclient-fetch"
    "urandom-seed"
    "urngd"
    "boost"
)

# 在循环前添加
echo "=== 开始处理数组 ==="
for package in "${default_packages[@]}"; do

    config_package_add "$package"
done
echo "=== 数组处理完成 ==="

################################################################

# 设置'root'密码为 'password'
sed -i 's/root:::0:99999:7:::/root:$1$V4UetPzk$CYXluq4wUazHjmCDBCqXF.::0:99999:7:::/g' package/base-files/files/etc/shadow
# 修改默认IP
sed -i 's/192.168.1.1/192.168.5.1/g' package/base-files/files/bin/config_generate

# 创建 PPPoE 配置的 uci-defaults 脚本
echo "创建安全的 PPPoE 配置脚本..."

# 从环境变量获取 PPPoE 配置（GitHub Secrets）
PPPOE_USER="${PPPOE_USERNAME:-}"
PPPOE_PASS="${PPPOE_PASSWORD:-}"

# 安全日志输出
if [ -n "$PPPOE_USER" ] && [ -n "$PPPOE_PASS" ]; then
    echo "检测到 PPPoE 配置信息"
    echo "用户名: ${PPPOE_USER:0:3}***"
    echo "密码: [已隐藏]"
    PPPOE_ENABLED="true"
else
    echo "未检测到 PPPoE 配置，固件将使用默认 DHCP 模式"
    echo "如需配置 PPPoE，请在 GitHub Secrets 中设置 PPPOE_USERNAME 和 PPPOE_PASSWORD"
    PPPOE_ENABLED="false"
fi

mkdir -p package/base-files/files/etc/uci-defaults
cat > package/base-files/files/etc/uci-defaults/99-network-setup << EOF
#!/bin/sh
# OpenWrt 网络初始化配置脚本
# 此脚本在首次启动时执行，配置完成后自动删除

# 日志记录
exec >/tmp/network-setup.log 2>&1

echo "开始网络配置..."

# PPPoE 配置
if [ "$PPPOE_ENABLED" = "true" ]; then
    echo "配置 PPPoE 拨号模式"
    echo "用户名: ${PPPOE_USER:0:3}***"

    uci set network.wan.proto='pppoe'
    uci set network.wan.username='$PPPOE_USER'
    uci set network.wan.password='$PPPOE_PASS'
    uci set network.wan.ipv6='auto'
    uci set network.wan.demand='0'
    uci set network.wan.keepalive='5 3'
    uci commit network

    echo "PPPoE 配置完成"
else
    echo "使用默认 DHCP 模式"
    echo "如需配置 PPPoE，请编辑此脚本或在 LuCI 界面中配置"
fi

echo "网络配置脚本执行完成"
EOF

# 设置脚本可执行权限
chmod +x package/base-files/files/etc/uci-defaults/99-network-setup

# 添加编译时间到版本信息
sed -i "s/DISTRIB_DESCRIPTION='.*'/DISTRIB_DESCRIPTION='${REPO_NAME} ${OpenWrt_VERSION} ${OpenWrt_ARCH} Built on $(date +%Y%m%d)'/" package/base-files/files/etc/openwrt_release
# 添加编译时间到 /etc/banner
#sed -i '$ i\\ Build Time: '"$(date +%Y%m%d)"'' package/base-files/files/etc/banner


#### 镜像生成
# 修改分区大小
sed -i "/CONFIG_TARGET_KERNEL_PARTSIZE/d" .config
echo "CONFIG_TARGET_KERNEL_PARTSIZE=96" >> .config
sed -i "/CONFIG_TARGET_ROOTFS_PARTSIZE/d" .config
echo "CONFIG_TARGET_ROOTFS_PARTSIZE=5012" >> .config
# 调整 GRUB_TIMEOUT
sed -i "s/CONFIG_GRUB_TIMEOUT=\"3\"/CONFIG_GRUB_TIMEOUT=\"1\"/" .config
## 不生成 EXT4 硬盘格式镜像
config_del TARGET_ROOTFS_EXT4FS
## 不生成非 EFI 镜像
config_del GRUB_IMAGES

#### 删除
# Sound Support
config_package_del kmod-sound-core
# Other
config_package_del luci-app-rclone_INCLUDE_rclone-webui
config_package_del luci-app-rclone_INCLUDE_rclone-ng

#### 新增
# Firmware
config_package_add intel-microcode
# sing-box内核支持
config_package_add kmod-netlink-diag
# luci
config_package_add luci
config_package_add default-settings-chn
# bbr
config_package_add kmod-tcp-bbr
# coremark cpu 跑分
config_package_add coremark
# autocore + lm-sensors-detect： cpu 频率、温度
config_package_add autocore
config_package_add lm-sensors-detect
# bash
config_package_add bash
# 更改默认 Shell 为 bash
sed -i 's|/bin/ash|/bin/bash|g' package/base-files/files/etc/passwd
# nano 替代 vim
config_package_add nano
config_package_add vim
# curl
config_package_add curl
# ddns
config_package_add luci-app-ddns-go
# frc
config_package_add luci-app-frpc

# tty 免登录
sed -i 's|/bin/login|/bin/login -f root|g' feeds/packages/utils/ttyd/files/ttyd.config

#硬件及驱动
# 虚拟机支持
config_package_add qemu-ga
# usb 2.0 3.0 支持
config_package_add kmod-usb2
config_package_add kmod-usb3
# usb 网络支持
config_package_add usbmuxd
config_package_add usbutils
config_package_add usb-modeswitch
config_package_add kmod-usb-serial
config_package_add kmod-usb-serial-option
config_package_add kmod-usb-net-rndis
config_package_add kmod-usb-net-ipheth


#-------------------Luciapp(官方源自带)---------------#
# 壁纸设置
config_package_add luci-app-argon-config
# 文件管理
config_package_add luci-app-filebrowser
# openclash
config_package_add luci-app-openclash
# docker相关
config_package_add luci-app-dockerman
# qbittorent
config_package_add luci-app-qbittorrent
# NFS共享
config_package_add luci-app-nfs
#硬盘分区显示
config_package_add luci-app-diskman
# watchcat
config_package_add luci-app-watchcat
# zerotier
config_package_add luci-app-zerotier
# upnp自动端口映射
config_package_add luci-app-upnp
# docker
config_package_add luci-lib-docker
# dashbord
config_package_add luci-mod-dashboard 
#luci-app-netdata
config_package_add luci-app-netdata
# argon 主题#
config_package_add luci-theme-argon
config_package_add luci-app-statistics

# 系统升级
config_package_add luci-app-attendedsysupgrade


#### 第三方软件包
rm -rf package/custom
mkdir -p package/custom
git clone --depth 1 https://github.com/DoTheBetter/OpenWrt-Packages.git package/custom
clean_packages package/custom

# golang
rm -rf feeds/packages/lang/golang
mv package/custom/golang feeds/packages/lang/

# argon 主题
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile

## 分区扩容。一键自动格式化分区、扩容、自动挂载插件，专为OPENWRT设计，简化OPENWRT在分区挂载上烦锁的操作
config_package_add luci-app-partexp
config_package_add luci-app-netspeedtest

## iStore 应用市场 只支持 x86_64 和 arm64 设备
git_sparse_clone main https://github.com/linkease/istore temp-istore luci
config_package_add luci-app-store

# turboacc
curl -sSL https://raw.githubusercontent.com/chenmozhijin/turboacc/luci/add_turboacc.sh -o add_turboacc.sh && bash add_turboacc.sh --no-sfe
config_package_add luci-app-turboacc

git clone https://github.com/UnblockNeteaseMusic/luci-app-unblockneteasemusic.git package/luci-app-unblockneteasemusic
config_package_add luci-app-unblockneteasemusic

config_package_del speedtestcli

