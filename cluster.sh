#!/bin/bash
ip=`ip a | grep inet | grep -v inet6 | grep -v 127.0.0.1 | sed 's/^[ \t]*//g' | cut -d ' ' -f2 |cut -d '/' -f1 | grep -v 172. | head -1`
# 单节点:3 master(9331-9333) + 3 volume(8081-8083) + 1 filer(8888) + 1 mount

# Github 加速
curl https://gitlab.com/ineo6/hosts/-/raw/master/hosts > ~/1.txt
cat ~/1.txt >> /etc/hosts

# 安装基础软件
yum -y install wget tar tree

# 配置 go 运行环境
cd /usr/local
# 下载
wget https://golang.google.cn/dl/go1.22.5.linux-amd64.tar.gz

# 解压
tar -zxf go1.22.5.linux-amd64.tar.gz -C /usr/local/

# 配置环境变量
cat >> /etc/profile <<EOF

export GOROOT=/usr/local/go
export GOPATH=$GOROOT/bin
export GOOS=linux
export GOBIN=$GOROOT/bin
export GOTOOLS=$GOROOT/pkg/tool/
export PATH=$PATH:$GOBIN:$GOTOOLS

EOF
# 使配置文件生效
source /etc/profile

# 查看
go version


#将二进制文件复制到指定目录(如果有则不覆盖)
#cp -n bin/weed /usr/local/bin
rm -rf /usr/local/bin/linux_amd64.tar.gz
mkdir -p /usr/local/bin
wget -P /usr/local https://github.com/seaweedfs/seaweedfs/releases/download/3.71/linux_amd64.tar.gz 
tar -zxf /usr/local/linux_amd64.tar.gz  -C /usr/local/bin

#创建目录结构
#创建日志目录
mkdir -p /seaweedfs/log/{master1,master2,master3,volume1,volume2,volume3,filer,mount}

# 创建数据存储目录
mkdir -p /seaweedfs/{master/{mdir1,mdir2,mdir3},volume/{data1,data2,data3}

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
cat <<EOF > /lib/systemd/system/${service_name}.service
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
service_name="weed-master-server1"
command="/usr/local/bin/weed -logdir=/seaweedfs/log/master1 master -mdir=/seaweedfs/master/mdir1 -peers=${ip}:9331,${ip}:9332,${ip}:9333 -port=9331 -defaultReplication=001"
create_service

service_name="weed-master-server2"
command="/usr/local/bin/weed -logdir=/seaweedfs/log/master2 master -mdir=/seaweedfs/master/mdir2 -peers=${ip}:9331,${ip}:9332,${ip}:9333 -port=9332 -defaultReplication=001"
create_service

service_name="weed-master-server3"
command="/usr/local/bin/weed -logdir=/seaweedfs/log/master3 master -mdir=/seaweedfs/master/mdir3 -peers=${ip}:9331,${ip}:9332,${ip}:9333 -port=9333 -defaultReplication=001"
create_service

#volume服务
service_name="weed-volume-server1"
command="/usr/local/bin/weed -logdir=/seaweedfs/log/volume1 volume -dir=/seaweedfs/volume/data1 -max=300  -mserver=${ip}:9331,${ip}:9332,${ip}:9333 -port=8081"
create_service

service_name="weed-volume-server2"
command="/usr/local/bin/weed -logdir=/seaweedfs/log/volume2 volume -dir=/seaweedfs/volume/data2 -max=300  -mserver=${ip}:9331,${ip}:9332,${ip}:9333 -port=8082"
create_service

service_name="weed-volume-server3"
command="/usr/local/bin/weed -logdir=/seaweedfs/log/volume3 volume -dir=/seaweedfs/volume/data3 -max=300  -mserver=${ip}:9331,${ip}:9332,${ip}:9333 -port=8083"
create_service

#filer服务
service_name="weed-filer-server"
command="/usr/local/bin/weed -logdir=/seaweedfs/log/filer filer -master=${ip}:9331,${ip}:9332,${ip}:9333 -port=8888 -defaultReplicaPlacement=001"
create_service

#mount服务
service_name="weed-mount-server"
command="/usr/local/bin/weed -logdir=/seaweedfs/log/mount mount -filer=${ip}:8888 -dir=/mount"
create_service

# 重载配置
systemctl daemon-reload

## 启动所有服务
systemctl start weed-master-server1.service
systemctl start weed-master-server2.service
systemctl start weed-master-server3.service
systemctl start weed-volume-server1.service
systemctl start weed-volume-server2.service
systemctl start weed-volume-server3.service
systemctl start weed-filer-server.service
systemctl start weed-mount-server.service

#设置服务开机自启
systemctl enable weed-master-server1.service
systemctl enable weed-master-server2.service
systemctl enable weed-master-server3.service
systemctl enable weed-volume-server1.service
systemctl enable weed-volume-server2.service
systemctl enable weed-volume-server3.service
systemctl enable weed-filer-server.service
systemctl enable weed-mount-server.service

#查看进程状态
ps -ef | grep weed
