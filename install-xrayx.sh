#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)
# 脚本仓库地址（用于远程下载 XrayX.service / XrayX.sh / config 等文件）
repo_raw="https://raw.githubusercontent.com/xshhhlol/wyx2685-XrayR-scripts/master"

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}错误：${plain} 必须使用root用户运行此脚本！\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    echo -e "${red}未检测到系统版本，请联系脚本作者！${plain}\n" && exit 1
fi

arch=$(arch)

if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
    arch="64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
    arch="arm64-v8a"
elif [[ $arch == "s390x" ]]; then
    arch="s390x"
else
    arch="64"
    echo -e "${red}检测架构失败，使用默认架构: ${arch}${plain}"
fi

echo "架构: ${arch}"

if [ "$(getconf WORD_BIT)" != '32' ] && [ "$(getconf LONG_BIT)" != '64' ] ; then
    echo "本软件不支持 32 位系统(x86)，请使用 64 位系统(x86_64)，如果检测有误，请联系作者"
    exit 2
fi

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}请使用 CentOS 7 或更高版本的系统！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}请使用 Ubuntu 16 或更高版本的系统！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}请使用 Debian 8 或更高版本的系统！${plain}\n" && exit 1
    fi
fi

install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install epel-release -y
        yum install wget curl unzip tar crontabs socat -y
    else
        apt update -y
        apt install wget curl unzip tar cron socat -y
    fi
}

# 0: running, 1: not running, 2: not installed
check_status() {
    if [[ ! -f /etc/systemd/system/XrayX.service ]]; then
        return 2
    fi
    temp=$(systemctl status XrayX | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

install_XrayX() {
    if [[ -e /usr/local/XrayX/ ]]; then
        rm /usr/local/XrayX/ -rf
    fi

    mkdir /usr/local/XrayX/ -p
	cd /usr/local/XrayX/

    if  [ $# == 0 ] ;then
        # 获取最新的 release
        last_version=$(curl -Ls "https://api.github.com/repos/leaderen/wyx2685-XrayR/releases" | grep '"tag_name":' | head -1 | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            echo -e "${red}检测 XrayX 版本失败，可能是超出 Github API 限制，请稍后再试，或手动指定版本安装${plain}"
            echo -e "${yellow}提示：可以手动指定版本安装，例如：bash install-xrayx.sh v0.9.2${plain}"
            exit 1
        fi
        echo -e "检测到 XrayX 最新版本：${last_version}，开始安装"

        # 尝试下载最新版本（上游二进制名仍为 XrayR）
        wget -q -N --no-check-certificate -O /usr/local/XrayX/XrayR-linux.zip https://github.com/leaderen/wyx2685-XrayR/releases/download/${last_version}/XrayR-linux-${arch}.zip
        if [[ $? -ne 0 ]]; then
            echo -e "${yellow}${last_version} 下载失败，尝试 v0.9.2...${plain}"
            # 如果最新版本下载失败，尝试 v0.9.2
            last_version="v0.9.2"
            wget -q -N --no-check-certificate -O /usr/local/XrayX/XrayR-linux.zip https://github.com/leaderen/wyx2685-XrayR/releases/download/${last_version}/XrayR-linux-${arch}.zip
            if [[ $? -ne 0 ]]; then
                echo -e "${red}下载 XrayX 失败，请确保你的服务器能够下载 Github 的文件${plain}"
                exit 1
            fi
        fi
    else
        if [[ $1 == v* ]]; then
            last_version=$1
	else
	    last_version="v"$1
	fi
        url="https://github.com/leaderen/wyx2685-XrayR/releases/download/${last_version}/XrayR-linux-${arch}.zip"
        echo -e "开始安装 XrayX ${last_version}"
        wget -q -N --no-check-certificate -O /usr/local/XrayX/XrayR-linux.zip ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red}下载 XrayX ${last_version} 失败，请确保此版本存在${plain}"
            exit 1
        fi
    fi

    unzip XrayR-linux.zip
    rm XrayR-linux.zip -f
    # 上游解压出的二进制名为 XrayR，重命名为 XrayX
    mv XrayR XrayX
    chmod +x XrayX
    mkdir /etc/XrayX/ -p
    rm /etc/systemd/system/XrayX.service -f
    # 从仓库远程下载 service 文件
    wget -q -N --no-check-certificate -O /etc/systemd/system/XrayX.service ${repo_raw}/XrayX.service
    if [[ $? -ne 0 ]]; then
        echo -e "${red}下载 XrayX.service 失败，请检查仓库地址或网络${plain}"
        exit 1
    fi
    systemctl daemon-reload
    systemctl stop XrayX
    systemctl unmask XrayX 2>/dev/null || true
    systemctl enable XrayX
    echo -e "${green}XrayX ${last_version}${plain} 安装完成，已设置开机自启"
    cp geoip.dat /etc/XrayX/
    cp geosite.dat /etc/XrayX/

    if [[ ! -f /etc/XrayX/config.yml ]]; then
        cp config.yml /etc/XrayX/
        echo -e ""
        echo -e "全新安装，请先参看教程：https://github.com/XrayR-project/XrayR，配置必要的内容"
    else
        systemctl start XrayX
        sleep 2
        check_status
        echo -e ""
        if [[ $? == 0 ]]; then
            echo -e "${green}XrayX 重启成功${plain}"
        else
            echo -e "${red}XrayX 可能启动失败，请稍后使用 XrayX log 查看日志信息，若无法启动，则可能更改了配置格式，请前往 wiki 查看：https://github.com/XrayR-project/XrayR/wiki${plain}"
        fi
    fi

    if [[ ! -f /etc/XrayX/dns.json ]]; then
        cp dns.json /etc/XrayX/
    fi
    if [[ ! -f /etc/XrayX/route.json ]]; then
        cp route.json /etc/XrayX/
    fi
    if [[ ! -f /etc/XrayX/custom_outbound.json ]]; then
        cp custom_outbound.json /etc/XrayX/
    fi
    if [[ ! -f /etc/XrayX/custom_inbound.json ]]; then
        cp custom_inbound.json /etc/XrayX/
    fi
    if [[ ! -f /etc/XrayX/rulelist ]]; then
        cp rulelist /etc/XrayX/
    fi
    # 从仓库远程下载管理脚本
    wget -q -N --no-check-certificate -O /usr/bin/XrayX ${repo_raw}/XrayX.sh
    if [[ $? -ne 0 ]]; then
        echo -e "${red}下载 XrayX.sh 管理脚本失败，请检查仓库地址或网络${plain}"
        exit 1
    fi
    chmod +x /usr/bin/XrayX
    ln -sf /usr/bin/XrayX /usr/bin/xrayx # 小写兼容
    chmod +x /usr/bin/xrayx
    cd $cur_dir
    echo -e ""
    echo "XrayX 管理脚本使用方法 (兼容使用xrayx执行，大小写不敏感): "
    echo "------------------------------------------"
    echo "XrayX                    - 显示管理菜单 (功能更多)"
    echo "XrayX start              - 启动 XrayX"
    echo "XrayX stop               - 停止 XrayX"
    echo "XrayX restart            - 重启 XrayX"
    echo "XrayX status             - 查看 XrayX 状态"
    echo "XrayX enable             - 设置 XrayX 开机自启"
    echo "XrayX disable            - 取消 XrayX 开机自启"
    echo "XrayX log                - 查看 XrayX 日志"
    echo "XrayX update             - 更新 XrayX"
    echo "XrayX update x.x.x       - 更新 XrayX 指定版本"
    echo "XrayX config             - 显示配置文件内容"
    echo "XrayX install            - 安装 XrayX"
    echo "XrayX uninstall          - 卸载 XrayX"
    echo "XrayX version            - 查看 XrayX 版本"
    echo "------------------------------------------"
}

echo -e "${green}开始安装${plain}"
install_base
install_XrayX $1
