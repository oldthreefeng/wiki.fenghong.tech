---
title: "docker部署企业级应用openvpn"
date: "2019-08-04 17:09:32"
tags: 
  - ops
  - vpn
  - docker
---

[TOC]

### 部署openvpn-in-docker

- 生成默认的openvpn配置文件

```
[root@jx_develop openvpn]# docker run -v ${OVPN_DATA}:/etc/openvpn --rm kylemanna/openvpn ovpn_genconfig -c -u udp://139.196.203.158    //生成默认的openvpn配置
Unable to find image 'kylemanna/openvpn:latest' locally
latest: Pulling from kylemanna/openvpn
050382585609: Pull complete 
944a899b9c42: Pull complete 
59afa6e6f5d8: Pull complete 
f2941e48588b: Pull complete 
18e0142d2a50: Pull complete 
Digest: sha256:266c52c3df8d257ad348ea1e1ba8f0f371625b898b0eba6e53c785b82f8d897e
Status: Downloaded newer image for kylemanna/openvpn:latest
Processing PUSH Config: 'block-outside-dns'
Processing Route Config: '192.168.254.0/24'  
Processing PUSH Config: 'dhcp-option DNS 8.8.8.8'
Processing PUSH Config: 'dhcp-option DNS 8.8.4.4'
Processing PUSH Config: 'comp-lzo no'
Successfully generated config
Cleaning up before Exit ...
[root@jx_develop openvpn]# ls
ccd  openvpn.conf  ovpn_env.sh
[root@jx_develop openvpn]# vim ovpn_env.sh 
[root@jx_develop openvpn]# ls
ccd  openvpn.conf  ovpn_env.sh
[root@jx_develop openvpn]# vim openvpn.conf 
```

- 增加默认用户

默认的配置文件只有254个client链接，增加`openvpn`的用户数，
`github`上的的方法
`server 172.20.0.0 255.255.0.0 `
`route 172.20.0.0 255.255.0.0 `

全部的配置文件如下：

```
server 172.20.0.0 255.255.0.0
verb 3
key /etc/openvpn/pki/private/139.196.203.158.key
ca /etc/openvpn/pki/ca.crt
cert /etc/openvpn/pki/issued/139.196.203.158.crt
dh /etc/openvpn/pki/dh.pem
tls-auth /etc/openvpn/pki/ta.key
key-direction 0
keepalive 10 60
persist-key
persist-tun

proto udp
# Rely on Docker to do port mapping, internally always 1194
port 1194
dev tun0
status /tmp/openvpn-status.log

user nobody
group nogroup
client-to-client
comp-lzo no

### Route Configurations Below
route 172.20.0.0 255.255.0.0

### Push Configurations Below
push "block-outside-dns"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"
push "comp-lzo no"
```

- 证书生成

> 初始化ca，dh等相关证书，要输入几次密码，都是确认Ca证书的密码

```
[root@jx_develop openvpn]# docker run -v ${OVPN_DATA}:/etc/openvpn --rm -it kylemanna/openvpn ovpn_initpki

init-pki complete; you may now create a CA or requests.
Your newly created PKI dir is: /etc/openvpn/pki


Using SSL: openssl OpenSSL 1.1.1c  28 May 2019

Enter New CA Key Passphrase: 
Re-Enter New CA Key Passphrase: 
Generating RSA private key, 2048 bit long modulus (2 primes)
.....................................+++++
.........................+++++
e is 65537 (0x010001)
Can't load /etc/openvpn/pki/.rnd into RNG
140068301057352:error:2406F079:random number generator:RAND_load_file:Cannot open file:crypto/rand/randfile.c:98:Filename=/etc/openvpn/pki/.rnd
You are about to be asked to enter information that will be incorporated
into your certificate request.
What you are about to enter is what is called a Distinguished Name or a DN.
There are quite a few fields but you can leave some blank
For some fields there will be a default value,
If you enter '.', the field will be left blank.
-----
Common Name (eg: your user, host, or server name) [Easy-RSA CA]:qianxiangtest

CA creation complete and you may now import and sign cert requests.
Your new CA certificate file for publishing is at:
/etc/openvpn/pki/ca.crt


Using SSL: openssl OpenSSL 1.1.1c  28 May 2019
Generating DH parameters, 2048 bit long safe prime, generator 2
This is going to take a long time
........................................................................................................................................................................+...................+..........................................................................................+..............................+..............................................................+...................................................................................................................................................................+.........................................................................................+........+.......................................+.........................................................................................................................................................................................................+...................................+...............................+........................................................................+...................................................+...................................................................+...........................................................................................................................................+..............................................................................................+......................................................................................................................+............................................................................+....................................................................................................................................................................................+................................+....................+.........................................................................................+..........................................................................................................................................................................................................+..........................................................................................................................+.....................................................................................................+....................................................................+.................................................+.........................................................................................................................+...........................................+..........................................................................................................................................................................................................................................................................+......................................+...........................+......+..........................................................................+..................................................................................................................++*++*++*++*

DH parameters of size 2048 created at /etc/openvpn/pki/dh.pem


Using SSL: openssl OpenSSL 1.1.1c  28 May 2019
Generating a RSA private key
.................................+++++
.........+++++
writing new private key to '/etc/openvpn/pki/private/139.196.203.158.key.XXXXCOHnGl'
-----
Using configuration from /etc/openvpn/pki/safessl-easyrsa.cnf
Enter pass phrase for /etc/openvpn/pki/private/ca.key:
Check that the request matches the signature
Signature ok
The Subject's Distinguished Name is as follows
commonName            :ASN.1 12:'139.196.203.158'
Certificate is to be certified until Jul 20 07:20:59 2022 GMT (1080 days)

Write out database with 1 new entries
Data Base Updated

Using SSL: openssl OpenSSL 1.1.1c  28 May 2019
Using configuration from /etc/openvpn/pki/safessl-easyrsa.cnf
Enter pass phrase for /etc/openvpn/pki/private/ca.key:

An updated CRL has been created.
CRL file: /etc/openvpn/pki/crl.pem
```

- 启动服务

> 暴露服务1194端口

```
[root@jx_develop openvpn]# docker run -v $OVPN_DATA:/etc/openvpn -d -p 1194:1194/udp --cap-add=NET_ADMIN --name openvpn kylemanna/openvpn
2b5fefd34b6296aa09f95dfeb63556d6f386d0bbc77c8e5e6ce61552951ffd63
[root@jx_develop openvpn]# docker start openvpn
openvpn

```

- 生成用户配置文件

```
# cat sh/generate.sh 
#!/bin/bash
read -p "please your username: " NAME
docker run -v /data/openvpn:/etc/openvpn --rm -it kylemanna/openvpn easyrsa build-client-full $NAME nopass
docker run -v /data/openvpn:/etc/openvpn --rm kylemanna/openvpn ovpn_getclient $NAME > /data/openvpn/conf/"$NAME".ovpn
### 禁用全局代理，仅代理宝盾系统和沣临珠宝系统。
sed -i "/redirect-gateway def1/d"  /data/openvpn/conf/"$NAME".ovpn
sed -i "/remote-cert-tls server/a\route 10.9.0.0 255.255.0.0 vpn_gateway" /data/openvpn/conf/"$NAME".ovpn
sed -i "/remote-cert-tls server/a\route xx.xx.xx.xx 255.255.255.255 vpn_gateway" /data/openvpn/conf/"$NAME".ovpn
sed -i "/remote-cert-tls server/a\route-nopull" /data/openvpn/conf/"$NAME".ovpn


```

- 删除用户授权配置文件

```
# cat sh/revoke.sh 
#!/bin/bash
read -p "Delete username: " DNAME
docker run -v /data/openvpn:/etc/openvpn --rm -it kylemanna/openvpn:2.4 easyrsa revoke $DNAME
docker run -v /data/openvpn:/etc/openvpn --rm -it kylemanna/openvpn:2.4 easyrsa gen-crl
docker run -v /data/openvpn:/etc/openvpn --rm -it kylemanna/openvpn:2.4 rm -f /etc/openvpn/pki/reqs/"$DNAME".req
docker run -v /data/openvpn:/etc/openvpn --rm -it kylemanna/openvpn:2.4 rm -f /etc/openvpn/pki/private/"$DNAME".key
docker run -v /data/openvpn:/etc/openvpn --rm -it kylemanna/openvpn:2.4 rm -f /etc/openvpn/pki/issued/"$DNAME".crt
```

### 客户端路由配置

很多时候我们希望自己的客户端能够自定义路由，而且更该服务端的配置并不是一个相对较好的做法

找到我们的 ovpn 配置文件

到最后一行,去掉这个

`redirect-gateway def1`
即是我们全部流量走 VPN 的配置

- route-nopull

客户端加入这个参数后,OpenVPN 连接后不会添加路由,也就是不会有任何网络请求走 OpenVPN

- vpn_gateway

当客户端加入 `route-nopull` 后,所有出去的访问都不从 OpenVPN 出去,但可通过添加 vpn_gateway 参数使部分IP访问走 OpenVPN 出去

```
route 192.168.255.0 255.255.255.0 vpn_gateway
route 192.168.10.0 255.255.255.0 vpn_gateway
```

- net_gateway

和 `vpn_gateway` 相反,他表示在默认出去的访问全部走 OpenVPN 时,强行指定部分 IP 访问不通过 OpenVPN 出去

```
max-routes 1000 # 表示可以添加路由的条数,默认只允许添加100条路由,如果少于100条路由可不加这个参数
route 172.121.0.0 255.255.0.0 net_gateway
```