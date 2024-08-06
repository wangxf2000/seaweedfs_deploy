#!/bin/bash

# 单节点:1 master(9333) + 1 volume(8081) + 1 filer(8888)

# Github 加速
curl https://gitlab.com/ineo6/hosts/-/raw/master/hosts > ~/1.txt
cat ~/1.txt >> /etc/hosts

yum -y install wget tar tree

#将二进制文件复制到指定目录(如果有则不覆盖)
#cp -n bin/weed /usr/local/bin
mkdir -p /usr/local/bin
wget -P /usr/local https://github.com/seaweedfs/seaweedfs/releases/download/3.71/linux_amd64.tar.gz 
tar -zxf /usr/local/linux_amd64.tar.gz  -C /usr/local/bin

#创建目录结构
#创建日志目录
mkdir -p /seaweedfs/log/{master,volume,filer,mount}

# 创建数据存储目录
mkdir -p /seaweedfs/{master,volume}

# 创建挂载目录
mkdir -p /mount

# 生成配置文件
mkdir -p /etc/seaweedfs/
/usr/local/bin/weed scaffold -config filer -output="/etc/seaweedfs"

#查看目录结构
tree /seaweedfs -d

tree /etc/seaweedfs

#生成服务启动文件
function create_service(){
cat <<EOF > /lib/systemd/system/weed-${service_name}-server.service
[Unit]
Description=${service_name}
After=network.target

[Service]
ExecStart=${command}
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
}


#master服务
service_name="master"
command="/usr/local/bin/weed -logdir=/seaweedfs/log/master master -mdir=/seaweedfs/master  -port=9333"
create_service


#volume服务
service_name="volume"
command="/usr/local/bin/weed -logdir=/seaweedfs/log/volume volume -dir=/seaweedfs/volume -max=300 -mserver=localhost:9333 -port=8081"
create_service

#filer服务
service_name="filer"
command="/usr/local/bin/weed -logdir=/seaweedfs/log/filer filer -port=8888 -master=localhost:9333 "
create_service

#mount服务
service_name="mount"
command="/usr/local/bin/weed -logdir=/seaweedfs/log/mount mount -filer=localhost:8888 -dir=/mount"
create_service

systemctl daemon-reload

## 启动所有服务
systemctl start weed-master-server.service
systemctl start weed-volume-server.service
systemctl start weed-filer-server.service
systemctl start weed-mount-server.service

#设置服务开机自启
systemctl enable weed-master-server.service
systemctl enable weed-volume-server.service
systemctl enable weed-filer-server.service
systemctl enable weed-mount-server.service

#查看进程状态
ps -ef | grep weed
