#!/bin/bash

# 服务器出入口网络带宽速率计算
# Author: admin@test.com
# 兼容修改debian11: dami
# 加载基础环境

PATH="$PATH:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin"
set +m

if [[ -e "${HOME}/.bash_profile" ]]; then
    source ~/.bash_profile
elif [[ -e "${HOME}/.profile" ]]; then
    source ~/.profile
else
    source /etc/profile
fi

# 设置脚本语言
Old_LANG=$LANG
LANG="en_US.utf8"

if [ -f '/etc/redhat-release' ];then
    # 查看系统版本
    System_Release_D=`sed -n 's/.*release[[:space:]]\([0-9]\)\.[0-9].*/\1/p'  /etc/redhat-release`
    System_Type=`sed -n 's/\(.*\)[[:space:]]Linux.*release[[:space:]]\([0-9]\)\.[0-9].*/\1/p' /etc/redhat-release`
elif [ -f '/etc/system-release' ];then
    # 查看系统版本
    System_Release_D=`sed -n 's/.*release[[:space:]]\([0-9][0-9]\)\.[0-9].*/\1/p'  /etc/system-release`
    System_Type=`sed -n 's/\(.*\)[[:space:]]release[[:space:]]\([0-9][0-9]\)\.[0-9].*/\1/p'  /etc/system-release`
elif grep -Eqi "Debian" /etc/issue || grep -Eqi "Debian" /etc/os-release; then
    System_Release_D=`cat /etc/*-release | grep VERSION_ID | awk -F = '{print $2}' | awk -F "\"" '{print $2}'`
    System_Type=`lsb_release -s -d|awk '{print $1}'`

    apt install bc -y
    apt install net-tools -y
else
    System_Release_D=`lsb_release -s -d|awk -F'[ .]+' '{print $2}'`
    System_Type=`lsb_release -s -d|awk '{print $1}'`
fi
if [[ ${System_Release_D} -eq 7 ]];then
    # 安装必要的依赖
    Init_Install_Packages_Name_List=(wget )
    for Install_Packages_Name in ${Init_Install_Packages_Name_List[@]};do
        Check_Install_Info=`rpm -q "${Install_Packages_Name}"`
        if [[ "${Check_Install_Info}" =~ "is not installed" ]];then
            Info_Echo "install package ${Install_Packages_Name}"
            yum -y install "${Install_Packages_Name}" &> /dev/null
        fi
    done
fi


# echo "System_Release_D:${System_Release_D}"
# echo "System_Type:${System_Type}"

# 检查是否有测速请求进程未完成
ps -o pid,command|awk '/Speed_Test_File[[:space:]]/ {print $1}'|xargs -i kill {} 2> /dev/null
# 默认流量出口网卡
Default_Network_Device_Name=`route -n|awk '/^0.0.0.0/ {print $8}' |uniq`
if [ -z "${Default_Network_Device_Name}" ];then
    echo "网卡名称获取失败!"&&exit 1
fi
# 获取物理网卡速率
Network_Device_Speed=`route -n|awk '/^0.0.0.0/{print $8}'|uniq |xargs -i ethtool {} 2>/dev/null|awk '/Speed/ {print $2}'`
if [ "${Network_Device_Speed}" = '100Mb/s' ];then
    Network_Conf_Speed='2'
elif [ "${Network_Device_Speed}" = '1000Mb/s' ];then
    Network_Conf_Speed='10'
elif [ "${Network_Device_Speed}" = '10000Mb/s' ];then
    Network_Conf_Speed='20'
elif [ "${Network_Device_Speed}" = '20000Mb/s' ];then
    Network_Conf_Speed='30'
elif [ "${Network_Device_Speed}" = '25000Mb/s' ];then
    Network_Conf_Speed='40'
else
    Network_Device_Speed='虚拟机'
    Network_Conf_Speed='4'
fi


Upload_Test(){
    # 临时测速文件
    Temp_Speed_File="/dev/shm/Speed_Test_File"
    if [ ! -f "${Temp_Speed_File}" ];then
        # 使用内存计算 70%剩余内存

        if [ "$System_Type" == "Debian" ];then
            total_mem=$(free -m | awk '/Mem:/ {print $2}')
            available_mem=$(free -m | awk '/Mem:/ {print $7}')
            Temp_Speed_Size=$(echo "scale=2; $available_mem * 0.7 * 1024" | bc)
            Temp_Speed_Size=`printf "%.0f\n" "$Temp_Speed_Size"`
            # echo "debain:$Temp_Speed_Size"
        else
            Temp_Speed_Size=`awk -F":[[:space:]]" '/^MemAvailable:/ {print $2}' /proc/meminfo  |awk '{printf "%.0F",$1*0.7}'`
        fi
        # echo "Temp_Speed_Size:${Temp_Speed_Size}"

        if [ "${Temp_Speed_Size}" -gt 2000001 ];then
            # 不允许超过2GB
            Temp_Speed_Size='2000000'
        fi
        echo "开始生成 $((${Temp_Speed_Size}/1024))M 的临时文件：${Temp_Speed_File}"
        # 生成临时测速文件
        dd if=/dev/zero of=${Temp_Speed_File} bs=1024 count=${Temp_Speed_Size} &> /dev/null
    fi
    # 上传测速地址Url
    Upload_Speed_Url_List=('https://www.baidu.com/speed' 'https://main.qcloudimg.com/speed' 'https://www.aliyun.com/speed' 'https://qcloudimg.tencent-cloud.cn/speed' 'https://staticintl.cloudcachetci.com/speed' 'https://res-static.hc-cdn.cn/speed' 'https://portal.hc-cdn.com/speed' 'https://ecloud.10086.cn/speed' 'https://www.ctyun.cn/speed' 'https://cucc.wocloud.cn/speed' 'https://nd-static.bdstatic.com/speed' 'https://lol.qq.com/speed' 'https://wappass.baidu.com/speed' 'https://daoju.qq.com/speed' 'https://pay.qq.com/speed' 'https://www.migu.cn/speed' 'https://query.aliyun.com/speed' 'https://bce.bdstatic.com/speed')
    for num in $(seq 1 "${Network_Conf_Speed}");do
        for Upload_Speed_Url in ${Upload_Speed_Url_List[@]};do
            (curl -s -k --connect-timeout 4 -4 -A 'Chrome' --interface "${Default_Network_Device_Name}" -F "data=@${Temp_Speed_File}" "${Upload_Speed_Url}?${RANDOM}" &> /dev/null &)
        done &
    done &
    sleep 5
    echo "当前默认网卡 ${Default_Network_Device_Name} 上行测速将开始，等待10s..."
    # 历史出口流量
    Old_Network_Outlet_Flow_Sum=`awk '{print $1}' /sys/class/net/${Default_Network_Device_Name}/statistics/tx_bytes`
    sleep 10
    # 最新新出口流量
    New_Network_Outlet_Flow_Sum=`awk '{print $1}' /sys/class/net/${Default_Network_Device_Name}/statistics/tx_bytes`
    # 网卡出口流量字节速率
    Network_Outlet_Flow_Sum=`echo |awk "{printf \"%f\", (${New_Network_Outlet_Flow_Sum}-${Old_Network_Outlet_Flow_Sum})/10}"`
    # 网卡出口流量比特速率
    Network_Outlet_Flow_Sum_D=`echo |awk "{printf \"%f\",(${New_Network_Outlet_Flow_Sum}-${Old_Network_Outlet_Flow_Sum})*8/10}"`
    # 标准出口比特速率
    Network_Outlet_Device_Flow_Sum_D=`echo|awk "{printf \"%f\",${Network_Outlet_Flow_Sum_D/.*}/1024/1024}"`
    # 标准出口字节速率
    Network_Outlet_Device_Flow_Sum=`echo|awk "{printf \"%.2f\",${Network_Outlet_Flow_Sum/.*}/1024/1024}"`
    # 清理未完成进程
    ps -o pid,command -x|awk '/Speed_Test_File[[:space:]]/ {print $1}'|xargs -i kill -9 {} 2> /dev/null
    if [ -z "${1}" ];then
        rm -f "${Temp_Speed_File}"
    fi
}

Download_Test(){
    # 下载测速地址Url
    Download_Speed_Url_List=('https://speed.cloudflare.com/__down?bytes=150000000' 'http://lg-hkg.fdcservers.net/10GBtest.zip' 'https://cdn.engagement.ai/production/static/js/app.v1.ef1bc6bd4db830c68de1.js' 'https://mirrors.aliyun.com/centos/7/os/x86_64/LiveOS/squashfs.img' 'https://static.xinrenxinshi.com/official4/pc/A-AIM-20230609.mp4' 'http://mirrors.sohu.com/ubuntu/dists/kinetic/Contents-amd64.gz' 'https://mirrors.aliyun.com/ubuntu/dists/kinetic/Contents-amd64.gz' 'http://ftp.jp.debian.org/debian/dists/stretch/main/Contents-source.gz' 'ftp://www.mans.edu.eg/VMware%20Fusion%20Pro%2011.5.rar')
    # 下载速率
    for num in $(seq 1 "${Network_Conf_Speed}");do
        for Download_Speed_Url in ${Download_Speed_Url_List[@]};do
            (wget -q --no-check-certificate --dns-timeout=5 --connect-timeout=3 -O /dev/null -A 'Speed_Test_Query' "${Download_Speed_Url}?${RANDOM}" &> /dev/null &)
        done &
    done &
    sleep 5
    echo "当前默认网卡 ${Default_Network_Device_Name} 下行测速将开始，等待10s..."
    Old_Network_Ingress_Flow_Sum=`awk '{print $1}' /sys/class/net/${Default_Network_Device_Name}/statistics/rx_bytes`
    sleep 10
    New_Network_Ingress_Flow_Sum=`awk '{print $1}' /sys/class/net/${Default_Network_Device_Name}/statistics/rx_bytes`
    # 网卡入口流量字节速率
    Network_Ingress_Flow_Sum=`echo |awk "{printf \"%f\",(${New_Network_Ingress_Flow_Sum}-${Old_Network_Ingress_Flow_Sum})/10}"`
    # 网卡入口流量比特速率
    Network_Ingress_Flow_Sum_D=`echo |awk "{printf \"%f\",(${New_Network_Ingress_Flow_Sum}-${Old_Network_Ingress_Flow_Sum})*8}"`
    # 标准入口比特速率
    Network_Ingress_Device_Flow_Sum_D=`echo|awk "{printf \"%f\",${Network_Ingress_Flow_Sum_D/.*}/10485760}"`
    # 标准入口字节速率
    Network_Ingress_Device_Flow_Sum=`echo|awk "{printf \"%.2f\",${Network_Ingress_Flow_Sum/.*}/1024/1024}"`
    ps -o pid,command -x|awk '/Speed_Test_Query[[:space:]]/ {print $1}'|xargs -i kill -9 {} 2> /dev/null
    # 标准网络速率
    Network_Outlet_Device_Flow_Type="Mbps"
    # 标准硬盘速率
    Network_Outlet_Device_Flow_Type_D="MB"
}


Upload_Test
Download_Test

echo "当前默认网卡 ${Default_Network_Device_Name} 物理速率为: ${Network_Device_Speed} ,实际测试流量下行速率约为: ${Network_Ingress_Device_Flow_Sum_D/.*} ${Network_Outlet_Device_Flow_Type}/s,上行速率约为: ${Network_Outlet_Device_Flow_Sum_D/.*} ${Network_Outlet_Device_Flow_Type}/s"
echo "当前默认网卡 ${Default_Network_Device_Name} 物理速率为: ${Network_Device_Speed} ,实际测试流量下行格式化速率约为: ${Network_Ingress_Device_Flow_Sum} ${Network_Outlet_Device_Flow_Type_D}/s,出口流量格式化速率约为: ${Network_Outlet_Device_Flow_Sum} ${Network_Outlet_Device_Flow_Type_D}/s"