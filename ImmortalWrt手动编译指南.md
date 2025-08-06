# ImmortalWrt 24.10 x86-64 手动编译指南

## 概述

本文档基于GitHub Actions自动编译流程，提取了手动编译ImmortalWrt 24.10固件的完整步骤。适用于在本地Linux环境中编译自定义的ImmortalWrt固件。

## 文件作用分析

### 1. `diy-part1-x86-64.sh`

- **执行时机**: 在更新feeds之前
- **主要作用**:
  - 配置编译优化选项（O2级别优化，x86-64-v3指令集）
  - 关闭Spectre & Meltdown安全补丁以提升性能
  - 可添加自定义feeds源

### 2. `diy-part2-x86-64-router.sh`

- **执行时机**: 在更新feeds之后
- **主要作用**:
  - 配置默认软件包
  - 修改系统默认设置（IP地址、密码等）
  - 添加第三方软件包
  - 配置镜像生成参数

### 3. `immortalwrt-x86-64.yml`

- **作用**: GitHub Actions工作流配置
- **包含**: 完整的编译环境准备和编译流程

## 编译环境准备

### 系统要求

- **操作系统**: Ubuntu 22.04 LTS（推荐）或其他Debian系Linux发行版
- **硬件要求**:
  - CPU: 4核心以上（推荐8核心）
  - 内存: 8GB以上（推荐16GB）
  - 存储: 至少100GB可用空间
  - 网络: 稳定的互联网连接

### 依赖安装

```bash
# 更新系统包列表
sudo apt-get update

# 使用ImmortalWrt官方脚本安装编译依赖
sudo bash -c 'bash <(curl -s https://build-scripts.immortalwrt.org/init_build_environment.sh)'

# 清理系统
sudo apt-get autoremove --purge
sudo apt-get clean

# 设置时区（可选）
sudo timedatectl set-timezone "Asia/Shanghai"
```

## 源码获取和配置

### 1. 创建工作目录

```bash
# 创建工作目录
mkdir -p ~/immortalwrt-build
cd ~/immortalwrt-build
```

### 2. 下载源码

```bash
# 下载ImmortalWrt 24.10源码
git clone -b openwrt-24.10 --single-branch --depth 1 https://github.com/immortalwrt/immortalwrt openwrt
cd openwrt
```

### 3. 应用Part1自定义配置

创建并执行diy-part1脚本：

```bash
# 创建diy-part1.sh文件
cat > diy-part1.sh << 'EOF'
#!/bin/bash

# 使用 O2 级别的优化
sed -i 's,Os,O2 -march=x86-64-v3,g' include/target.mk

# 关闭 Spectre & Meltdown 补丁
sed -i 's,noinitrd,noinitrd mitigations=off,g' target/linux/x86/image/grub-efi.cfg
sed -i 's,noinitrd,noinitrd mitigations=off,g' target/linux/x86/image/grub-iso.cfg
sed -i 's,noinitrd,noinitrd mitigations=off,g' target/linux/x86/image/grub-pc.cfg
EOF

# 执行Part1脚本
chmod +x diy-part1.sh
./diy-part1.sh
```

### 4. 更新和安装feeds

```bash
# 更新feeds
./scripts/feeds update -a

# 安装feeds
./scripts/feeds install -a

# 清理冲突的软件包（如果存在smpackage源）
rm -rf feeds/smpackage/{base-files,dnsmasq,firewall*,fullconenat,libnftnl,nftables,ppp,opkg,ucl,upx,vsftpd*,miniupnpd-iptables,wireless-regdb}
```

### 5. 生成默认配置

```bash
# 生成默认配置文件
make defconfig
```

## 自定义配置

### 1. 应用Part2自定义配置

创建并执行diy-part2脚本（这是最重要的自定义配置步骤）：

```bash
# 创建diy-part2.sh文件
cat > diy-part2.sh << 'EOF'
#!/bin/bash

# 配置函数定义
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

# 设置默认软件包
default_packages=(
    "autocore" "automount" "autosamba" "base-files" "block-mount"
    "bridge" "bridger" "ca-bundle" "default-settings-chn" "dnsmasq-full"
    "dropbear" "fdisk" "firewall4" "fstools" "grub2-bios-setup"
    "geoview" "i915-firmware" "i915-firmware-dmc" "kmod-8139cp"
    "kmod-8139too" "kmod-button-hotplug" "kmod-e1000e" "kmod-fs-f2fs"
    "kmod-i40e" "kmod-igb" "kmod-igbvf" "kmod-igc" "kmod-ixgbe"
    "kmod-ixgbevf" "kmod-nf-nathelper" "kmod-nf-nathelper-extra"
    "kmod-nft-offload" "kmod-pcnet32" "kmod-r8101" "kmod-r8125"
    "kmod-r8126" "kmod-r8168" "kmod-tulip" "kmod-usb-hid"
    "kmod-usb-net" "kmod-usb-net-asix" "kmod-usb-net-asix-ax88179"
    "kmod-usb-net-rtl8150" "kmod-usb-net-rtl8152-vendor" "kmod-vmxnet3"
    "kmod-fs-exfat" "kmod-fs-nfts3" "kmod-fs-btrfs" "kmod-fs-ext4"
    "kmod-sched-cake" "libc" "libgcc" "libustream-openssl" "logd"
    "luci-app-package-manager" "luci-app-nlbwmon" "luci-app-sqm"
    "luci-compat" "luci-lib-base" "luci-lib-ipkg" "luci-light"
    "luci-app-samba4" "mkf2fs" "mtd" "netifd" "nftables"
    "odhcp6c" "odhcpd-ipv6only" "opkg" "partx-utils" "ppp"
    "ppp-mod-pppoe" "procd-ujail" "uci" "uclient-fetch"
    "urandom-seed" "urngd" "boost"
)

# 添加默认软件包
for package in "${default_packages[@]}"; do
    config_package_add "$package"
done

# 系统设置
# 设置root密码为'password'
sed -i 's/root:::0:99999:7:::/root:$1$V4UetPzk$CYXluq4wUazHjmCDBCqXF.::0:99999:7:::/g' package/base-files/files/etc/shadow

# 修改默认IP为192.168.5.1
sed -i 's/192.168.1.1/192.168.5.1/g' package/base-files/files/bin/config_generate

# 添加编译时间到版本信息
sed -i "s/DISTRIB_DESCRIPTION='.*'/DISTRIB_DESCRIPTION='immortalwrt 24.10 x86-64 Built on $(date +%Y%m%d)'/" package/base-files/files/etc/openwrt_release

# 镜像配置
# 修改分区大小
sed -i "/CONFIG_TARGET_KERNEL_PARTSIZE/d" .config
echo "CONFIG_TARGET_KERNEL_PARTSIZE=96" >> .config
sed -i "/CONFIG_TARGET_ROOTFS_PARTSIZE/d" .config
echo "CONFIG_TARGET_ROOTFS_PARTSIZE=5012" >> .config

# 调整GRUB超时时间
sed -i "s/CONFIG_GRUB_TIMEOUT=\"3\"/CONFIG_GRUB_TIMEOUT=\"1\"/" .config

# 不生成EXT4格式镜像
config_del TARGET_ROOTFS_EXT4FS

# 不生成非EFI镜像
config_del GRUB_IMAGES

# 删除不需要的包
config_package_del kmod-sound-core
config_package_del luci-app-rclone_INCLUDE_rclone-webui
config_package_del luci-app-rclone_INCLUDE_rclone-ng

# 添加必要软件包
config_package_add intel-microcode
config_package_add kmod-netlink-diag
config_package_add luci
config_package_add kmod-tcp-bbr
config_package_add coremark
config_package_add lm-sensors-detect
config_package_add bash
config_package_add nano
config_package_add vim
config_package_add curl

# 更改默认Shell为bash
sed -i 's|/bin/ash|/bin/bash|g' package/base-files/files/etc/passwd

# tty免登录
sed -i 's|/bin/login|/bin/login -f root|g' feeds/packages/utils/ttyd/files/ttyd.config

# 硬件支持
config_package_add qemu-ga
config_package_add kmod-usb2
config_package_add kmod-usb3
config_package_add usbmuxd
config_package_add usbutils
config_package_add usb-modeswitch
config_package_add kmod-usb-serial
config_package_add kmod-usb-serial-option
config_package_add kmod-usb-net-rndis
config_package_add kmod-usb-net-ipheth

# Luci应用
config_package_add luci-app-argon-config
config_package_add luci-app-filebrowser
config_package_add luci-app-openclash
config_package_add luci-app-dockerman
config_package_add luci-app-qbittorrent
config_package_add luci-app-nfs
config_package_add luci-app-diskman
config_package_add luci-app-watchcat
config_package_add luci-app-zerotier
config_package_add luci-app-upnp
config_package_add luci-lib-docker
config_package_add luci-mod-dashboard
config_package_add luci-app-netdata
config_package_add luci-theme-argon
config_package_add luci-app-statistics
EOF

# 执行Part2脚本
chmod +x diy-part2.sh
./diy-part2.sh
```

### 2. 添加第三方软件包（可选）

如果需要添加第三方软件包，可以执行以下步骤：

```bash
# 创建自定义软件包目录
rm -rf package/custom
mkdir -p package/custom

# 克隆第三方软件包仓库
git clone --depth 1 https://github.com/DoTheBetter/OpenWrt-Packages.git package/custom

# 更新golang（如果需要）
rm -rf feeds/packages/lang/golang
mv package/custom/golang feeds/packages/lang/

# 设置argon主题为默认主题
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile

# 添加iStore应用市场（仅支持x86_64和arm64）
git clone -b main --depth 1 --filter=blob:none --sparse https://github.com/linkease/istore temp-istore
cd temp-istore
git sparse-checkout init --cone
git sparse-checkout set luci
mv luci ../package/
cd ..
rm -rf temp-istore

# 添加turboacc网络加速
curl -sSL https://raw.githubusercontent.com/chenmozhijin/turboacc/luci/add_turboacc.sh -o add_turboacc.sh
bash add_turboacc.sh --no-sfe

# 添加网易云音乐解锁
git clone https://github.com/UnblockNeteaseMusic/luci-app-unblockneteasemusic.git package/luci-app-unblockneteasemusic
```

### 3. 手动配置（可选）

如果需要进一步自定义配置，可以使用menuconfig：

```bash
# 进入配置界面
make menuconfig
```

在menuconfig中可以：

- 选择目标设备和架构
- 添加/删除软件包
- 配置内核选项
- 设置文件系统选项

## 编译过程

### 1. 下载软件包

```bash
# 重新生成配置
make defconfig

# 下载所需的软件包源码
make download -j4

# 检查下载失败的文件并清理
find dl -size -1024c -exec ls -l {} \;
find dl -size -1024c -exec rm -f {} \;
```

### 2. 开始编译

```bash
# 获取CPU核心数
CORES=$(nproc)
echo "使用 $((CORES + 1)) 线程编译"

# 开始编译（多线程）
make -j$((CORES + 1))

# 如果编译失败，尝试单线程编译
# make -j1

# 如果还是失败，使用详细输出模式
# make -j1 V=s
```

### 3. 编译时间估算

- **首次编译**: 2-6小时（取决于硬件配置和网络速度）
- **增量编译**: 10-30分钟
- **清理后重编译**: 1-3小时

## 编译结果

### 1. 固件位置

编译完成后，固件文件位于：

```
openwrt/bin/targets/x86/64/
```

### 2. 主要文件说明

- `immortalwrt-x86-64-generic-squashfs-combined-efi.img.gz`: EFI启动的压缩镜像文件
- `immortalwrt-x86-64-generic-rootfs.tar.gz`: 根文件系统压缩包
- `config`: 编译时使用的配置文件
- `*.manifest`: 软件包清单文件

### 3. 固件信息

- **管理地址**: 192.168.5.1
- **用户名**: root
- **密码**: password
- **子网掩码**: 255.255.255.0

## 常见问题和解决方案

### 1. 编译环境问题

**问题**: 依赖包安装失败

```bash
# 解决方案：更新软件源并重试
sudo apt-get update
sudo apt-get upgrade
sudo apt-get install build-essential
```

**问题**: 磁盘空间不足

```bash
# 解决方案：清理系统和编译缓存
sudo apt-get clean
sudo apt-get autoremove
make clean
```

### 2. 下载问题

**问题**: 软件包下载失败

```bash
# 解决方案：重新下载
make download -j1
# 或者清理后重新下载
rm -rf dl
make download -j4
```

**问题**: Git克隆失败

```bash
# 解决方案：使用代理或更换源
git config --global http.proxy http://proxy:port
# 或使用GitHub镜像
git clone https://github.com.cnpmjs.org/immortalwrt/immortalwrt
```

### 3. 编译错误

**问题**: 内存不足导致编译失败

```bash
# 解决方案：减少并行编译线程
make -j1
# 或增加交换空间
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

**问题**: 软件包冲突

```bash
# 解决方案：清理feeds并重新安装
./scripts/feeds clean
./scripts/feeds update -a
./scripts/feeds install -a
```

### 4. 自定义配置问题

**问题**: 配置不生效

```bash
# 解决方案：确保在正确的时机执行脚本
# diy-part1.sh 应在 feeds update 之前执行
# diy-part2.sh 应在 feeds install 之后执行
```

**问题**: 软件包添加失败

```bash
# 解决方案：检查软件包名称和依赖
./scripts/feeds search 软件包名
make menuconfig  # 手动检查是否存在
```

## 优化建议

### 1. 编译性能优化

- 使用SSD存储
- 增加内存和CPU核心数
- 使用本地软件源镜像
- 启用ccache缓存

### 2. 网络优化

```bash
# 设置Git代理
git config --global http.proxy http://proxy:port

# 使用国内镜像源
export OPENWRT_DIST_URL=https://mirrors.tuna.tsinghua.edu.cn/openwrt
```

### 3. 存储优化

```bash
# 定期清理编译缓存
make clean
make dirclean  # 深度清理

# 使用软链接节省空间
ln -sf /path/to/large/storage ./dl
```

## 进阶使用

### 1. 创建自定义feeds

```bash
# 在feeds.conf.default中添加
echo 'src-git custom https://github.com/your/custom-packages' >> feeds.conf.default
```

### 2. 制作SDK

```bash
# 在menuconfig中启用
# Global build settings -> Compile the OpenWrt SDK
make -j$(nproc)
```

### 3. 交叉编译单个软件包

```bash
# 编译特定软件包
make package/软件包名/compile V=s
```

## 总结

本指南提供了完整的ImmortalWrt 24.10手动编译流程，包括：

- 环境准备和依赖安装
- 源码获取和配置
- 自定义配置应用
- 编译过程执行
- 问题排查和优化

通过遵循本指南，您可以成功编译出自定义的ImmortalWrt固件，满足特定的使用需求。建议在首次编译前仔细阅读所有步骤，并根据实际情况调整配置。

```
