---
title: "openvpn compile & install"
date: "2019-01-18 20:11"
tag: ops
---

[TOC]

为了方便团队成员从异地访问开发环境，考虑使用OpenVPN搭建虚拟局域网。部署的环境和版本信息如下:

- CentOS 7
- OpenVPN

## 1.easy-rsa生成证书



从[这里](https://codeload.github.com/OpenVPN/easy-rsa-old/zip/master)下载easy-rsa。

```
$ unzip easy-rsa-old-master.zip
$ cd easy-rsa-old-master/easy-rsa/2.0
 
$ ls
build-ca        build-key-pkcs12  inherit-inter      pkitool
build-dh        build-key-server  list-crl           revoke-full
build-inter     build-req         openssl-0.9.6.cnf  sign-req
build-key       build-req-pass    openssl-0.9.8.cnf  vars
build-key-pass  clean-all         openssl-1.0.0.cnf  whichopensslcnf

$ln -s openssl-1.0.0.cnf openssl.cnf
```

可修改vars文件中定义的变量用于生成证书的基本信息。下面生成CA证书：

```
$source vars
$./clean-all
$./build-ca
```

因为已经在var中填写了证书的基本信息，所以一路回车即可。生成证书如下：

```
$ ls keys/
ca.crt  ca.key  index.txt  serial
```

生成服务器端秘钥：

```
$ ./build-key-server server
......
Common Name (eg, your name or your server's hostname) [server]:
A challenge password []:1234
......

$ ls keys
01.pem  ca.crt  ca.key  index.txt  index.txt.attr  index.txt.old  serial  serial.old  server.crt  server.csr  server.key
```

生成客户端证书：

```
$ ./build-key client
......
Common Name (eg, your name or your server's hostname) [client]:
A challenge password []:1234
......
```

> Common Name用于区分客户端，不同的客户端应该有不同的名称。

Generating DH parameters：

```
$ ./build-dh

$ ls keys/
01.pem  02.pem  ca.crt  ca.key  client.crt  client.csr  client.key  dh2048.pem  index.txt  index.txt.attr  index.txt.attr.old  index.txt.old  serial  serial.old  server.crt  server.csr  server.key
```

## 2.编译OpenVPN



### 2.1 安装依赖

pam-devel：

```
$ yum install -y pam-devel
```

lzo:

```
$ wget http://www.oberhumer.com/opensource/lzo/download/lzo-2.10.tar.gz
$ tar -zxvf lzo-2.10.tar.gz
$ cd lzo-2.10
$ ./configure --enable-shared 
$ make 
$ make install 
```

### 2.2 编译安装OpenVPN

下载OpenVPN源码：

```
$ wget https://swupdate.openvpn.org/community/releases/openvpn-2.4.4.tar.gz
```

编译安装OpenVPN：

```
$ tar -zxvf openvpn-2.4.4.tar.gz
$ cd openvpn-2.4.4
$ ./configure --prefix=/usr/local/openvpn
$ make 
$ make install
```

## 3.配置OpenVPN



创建配置文件目录和证书目录：

```
$ mkdir -p /etc/openvpn
$ mkdir -p /etc/openvpn/pki
```

生成tls-auth key并将其拷贝到证书目录中：

```
$ /usr/local/openvpn/sbin/openvpn --genkey --secret ta.key
$ mv ta.key /etc/openvpn/pki
```

将签名生成的CA证书秘钥和服务端证书秘钥拷贝到证书目录中：

```
$ cp ca.key ca.crt server.crt server.key dh2048.pem /etc/openvpn/pki/

$ ls /etc/openvpn/pki/
ca.crt  ca.key  dh2048.pem  server.crt  server.key
```

将OpenVPN源码下的配置文件`sample/sample-config-files/server.conf`拷贝到`/etc/openvpn`目录。

编辑服务端配置文件`/etc/openvpn/server.conf`：

```
$ vim /etc/openvpn/server.conf
local 192.168.1.2 # 服务端IP
port 1194

proto tcp
dev tun

ca /etc/openvpn/pki/ca.crt
cert /etc/openvpn/pki/server.crt
key /etc/openvpn/pki/server.key
dh /etc/openvpn/pki/dh2048.pem

server 10.8.0.0 255.255.255.0 # 分配给客户端的虚拟局域网段
ifconfig-pool-persist ipp.txt

# 推送路由和DNS到客户端
push "route 192.168.1.0 255.255.255.0"
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 192.168.1.1"
push "dhcp-option DNS 8.8.8.8"

client-to-client

keepalive 10 120

tls-auth /etc/openvpn/pki/ta.key 0

cipher AES-256-CBC

comp-lzo

max-clients 10

user nobody
group nobody

persist-key
persist-tun

status /var/log/openvpn-status.log
log  /var/log/openvpn.log
log-append  /var/log/openvpn.log

verb 3
```

确认内核已经开启路由转发功能:

```
$ sysctl net.ipv4.ip_forward
net.ipv4.ip_forward = 1
```

确认iptables filter表的FOWARD链是ACCEPT状态：

```
$ iptables -nvL

$ iptables -P FORWARD ACCEPT
```

添加iptables转发规则，对所有源地址（openvpn为客户端分配的地址）为10.8.0.0/24的数据包转发后进行源地址转换，伪装成openvpn服务器内网地址192.168.1.2， 这样VPN客户端就可以访问服务器内网的其他机器了。

```
$ iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o em1 -j SNAT --to-source 192.168.1.2
```

贴一下我的iptables表：

```
# Generated by iptables-save v1.4.7 on Wed Jan 30 10:50:41 2019
*nat
:PREROUTING ACCEPT [511307:27018662]
:POSTROUTING ACCEPT [0:0]
:OUTPUT ACCEPT [8863045:542441750]
-A POSTROUTING -j MASQUERADE 
-A POSTROUTING -s 10.8.0.0/24 -o eth0 -j MASQUERADE 
COMMIT
# Completed on Wed Jan 30 10:50:41 2019
# Generated by iptables-save v1.4.7 on Wed Jan 30 10:50:41 2019
*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [8105799:4491852599]
:OUTPUT ACCEPT [579627360:226177092815]
-A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT 
-A INPUT -p icmp -j ACCEPT 
-A INPUT -i lo -j ACCEPT 
-A INPUT -p udp -m state --state NEW -m udp --dport 1194 -j ACCEPT 
-A INPUT -p tcp -m tcp --dport 1194 -j ACCEPT 
-A INPUT -p udp -m udp --dport 1194 -j ACCEPT 
-A INPUT -j REJECT --reject-with icmp-host-prohibited 
COMMIT
# Completed on Wed Jan 30 10:50:41 2019
```

创建openvpn的systemd unit文件：

```
cat > /etc/systemd/system/openvpn.service <<EOF
[Unit]
Description=openvpn
After=network.target

[Service]
EnvironmentFile=-/etc/openvpn/openvpn
ExecStart=/usr/local/openvpn/sbin/openvpn \
       --config /etc/openvpn/server.conf
Restart=on-failure
Type=simple
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
```

启动并设置为开机启动：

```
$ systemctl start openvpn
$ systemctl enable openvpn
```

查看端口监听：

```
$ netstat -nltp | grep 1194
tcp        0      0 192.168.1.2:1194        0.0.0.0:*                           88462/openvpn
```

## 4.客户端连接测试



从[这里](https://swupdate.openvpn.org/community/releases/openvpn-install-2.4.4-I601.exe)下载OPENVPN的windows客户端，安装完成后。 将以下证书和秘钥文件拷贝到安装目录中C:\Program Files\OpenVPN\config：

```
ca.crt
client.crt
client.key
ta.key
```

在这个目录下创建客户端的配置文件client.ovpn：

```
client
dev tun
proto tcp
remote xxx.xxx.xxx.xxx 11194
resolv-retry infinite
nobind
persist-key
persist-tun

ca ca.crt
cert client.crt
key client.key
remote-cert-tls server
tls-auth ta.key 1
cipher AES-256-CBC

comp-lzo
verb 3
```

- 其中 xxx.xxx.xxx.xxx 11194是外网IP和端口映射到了内网服务器的192.168.1.2 1194上。

接下来连接测试即可。

## 参考

- [OpenVPN Installation Notes](https://openvpn.net/index.php/open-source/documentation/install.html)

- [团队vpn安装](https://blog.frognew.com/2017/09/installing-openvpn.html#22-%E7%BC%96%E8%AF%91%E5%AE%89%E8%A3%85openvpn)