# OpenWrt-Builder
基于ImmortalWrt定制编译的主路由、旁路网关，跟随 24.10 分支更新自动编译。

本仓库地址：[https://github.com/DoTheBetter/OpenWrt-Builder](https://github.com/DoTheBetter/OpenWrt-Builder)

官方仓库地址：[https://github.com/immortalwrt/immortalwrt](https://github.com/immortalwrt/immortalwrt)

官方固件下载地址：
- [ImmortalWrt Firmware Download](https://downloads.immortalwrt.org/)
- [ImmortalWrt Firmware Selector](https://firmware-selector.immortalwrt.org/)

## 主路由 X86-64
### 精简
+ 精简全部音频组件

### 添加

#### 软件：

+ 升级 golang 版本（geodata、xray 等依赖高版本 go）
+ 添加常用软件：bash、nano、curl

#### 服务：

+ 添加upnp服务
+ 添加ttyd服务
+ 添加kms服务
+ 添加nikki服务
+ 添加去中心化内网穿透easytier
+ 添加端口转发及反向代理lucky
+ 添加dns工具
    + adguardhome
    + smartdns
    + mosdns
+ 添加上网时间控制nft-timecontrol
+ 添加多功能定时任务taskplan
+ 添加设置向导netwizard
+ 添加分区扩容工具partexp
+ 添加网络速度测试netspeedtest


#### 硬件驱动：

1. 添加虚拟机支持
2. 添加usb 2.0 3.0驱动
3. 添加usb网卡驱动

### 配置
1. 默认账号 `root`，密码 `password`。
2. 默认 LAN 口 IP 为 `192.168.10.1`。
通过命令行修改，重启后生效。在路由终端上按回车键，激活命令行。以下以将路由IP修改为192.168.5.1为例。
+ 首先，修改路由LAN的IP，输入命令如下：
```
uci set network.lan.ipaddr='192.168.5.1' 
uci commit network
```
+ 修改路由DHCP公开网关地址：
```
uci delete dhcp.lan.dhcp_option
uci add_list dhcp.lan.dhcp_option='6,192.168.5.1'
uci commit dhcp
```
+ 最后，重启路由。输入重启命令后等待约10s，路由会自动重启，全部步骤完成。

```
reboot
```

## 主路由 红米redmi-ax6000
使用 https://github.com/padavanonly/immortalwrt-mt798x-24.10 仓库进行编译，使用[H大的不死u-boot](https://github.com/hanwckf/bl-mt798x)选择immortalwrt-110m分区刷入

### 添加

#### 软件：

+ 升级 golang 版本（geodata、xray 等依赖高版本 go）
+ 添加常用软件：bash、nano、curl

#### 服务：

+ 添加upnp服务
+ 添加ttyd服务
+ 添加kms服务
+ 添加nikki服务
+ 添加去中心化内网穿透easytier
+ 添加端口转发及反向代理lucky
+ 添加dns工具
    + adguardhome
    + smartdns
    + mosdns
+ 添加上网时间控制nft-timecontrol
+ 添加多功能定时任务taskplan
+ 添加网络速度测试netspeedtest

### 配置
1. 默认账号 `root`，密码 `password`，wifi密码`password`。
2. 默认 LAN 口 IP 为 `192.168.31.1`。
