---
title: "Kubuntu from install to use ssr"
date: "2018-12-12 09:59:32"
tags: 
- Linux
- ubuntu
- shadowsocks
- chrome
- SwitchyOmega
collection: Manage Kownledge
---

[TOC]

摘要：

- 科学上网
- lxc容器

系统：Kubuntu 18.04 X86_64

# 一键恢复

重装了一次系统或者重装chrome，发现`Proxy SwitchyOmega`这个软件的配置没有自动保存功能，比较尴尬，只能重新导入，这边只好保存了一下自己的配置文件，安装好`Proxy SwitchyOmega`,选择`import/Export`  ----> `Restore from online`;我这边保存在自己的阿里云上了，路径如下

```
https://www.fenghong.tech/OmegaOptions.bak
```

# 科学上网

- 服务器安装

服务器安装ssr可以看[flyzy](https://www.flyzy2005.com/fan-qiang/shadowsocks/shadowsocks-config-multiple-users/)
github地址:`git clone https://github.com/flyzy2005/ss-fly`

- 安装代理

安装`shadowsocks`,这里不要用系统自带的`sudo apt install shadowsocks`,下载的不是最新的，不支持加密选项，会报错，这里博主犯错了，习惯了用`vim`编辑，所以这里我推荐使用。

```
$ sudo apt-get install python-pip -y
$ sudo apt-get install git -y
$ pip install git+https://github.com/shadowsocks/shadowsocks.git@master
$ sudo apt-get install vim -y

#下载的shadowsocks是最新版，在/home/$user/.local/bin/{ssserver,sslocal}

$ sudo echo "export PATH=/home/feng/.local/bin:$PATH" > /etc/profile.d/ss.sh
$ . /etc/profile.d/ss.sh
$ echo $PATH
/home/feng/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin

#已经在环境变量里面，所以可以直接运行。
```

- 配置文件创建

`server`字段: 为服务的ip地址

`server_port`字段: 为服务器开启的端口一般设置在1024之后，建议为8810。

```
$ sudo vim /etc/shadowsocks.json
{
    "server": "serverip",
    "server_port": port,
    "local_address": "127.0.0.1",
    "local_port": 1080,
    "timeout":300,
    "password": "password",
    "method": "aes-256-cfb",
    "fast_open":false
}
```

- 启动

```
$ sudo sslocal -c /etc/shadowsocks.json -d start 

#sslocal -h  查看帮助
  -c CONFIG              path to config file
  -s SERVER_ADDR         server address
  -p SERVER_PORT         server port, default: 8388
  -b LOCAL_ADDR          local binding address, default: 127.0.0.1
  -l LOCAL_PORT          local port, default: 1080
  -k PASSWORD            password
  -m METHOD              encryption method, default: aes-256-cfb
```

## 默认开机启动

ubuntu18.04默认是`systemd`管理启动

以前启动mysql服务:

```
sudo service mysqld start
```

现在：

```
sudo systemctl start mariadb.service
```

`systemd` 默认读取 `/etc/systemd/system` 下的配置文件，该目录下的文件会链接`/lib/systemd/system/`下的文件。

执行 `ls /lib/systemd/system` 你可以看到有很多启动脚本，其中就有我们需要的 `rc.local.service`：

```
$ cat /lib/systemd/system/rc.local.service 
#  SPDX-License-Identifier: LGPL-2.1+
#
#  This file is part of systemd.
#
#  systemd is free software; you can redistribute it and/or modify it
#  under the terms of the GNU Lesser General Public License as published by
#  the Free Software Foundation; either version 2.1 of the License, or
#  (at your option) any later version.

# This unit gets pulled automatically into multi-user.target by
# systemd-rc-local-generator if /etc/rc.local is executable.
[Unit]
Description=/etc/rc.local Compatibility
Documentation=man:systemd-rc-local-generator(8)
ConditionFileIsExecutable=/etc/rc.local
After=network.target

[Service]
Type=forking
ExecStart=/etc/rc.local start
TimeoutSec=0
RemainAfterExit=yes
GuessMainPID=no
```

- 正常启动文件

> [Unit] 段: 启动顺序与依赖关系
>
> [Service] 段: 启动行为,如何启动，启动类型
>
> [Install] 段: 定义如何安装这个配置文件，即怎样做到开机启动

可以看出，`/etc/rc.local` 的启动顺序是在网络后面，但是显然它少了 Install 段，也就没有定义如何做到开机启动，所以显然这样配置是无效的。 因此我们就需要在后面帮他加上 [Install] 段:

```
[Install]  
WantedBy=multi-user.target  
Alias=rc-local.service
```

这里需要注意一下，ubuntu-18.04 默认是没有 `/etc/rc.local` 这个文件的，需要自己创建

```
$ sudo touch /etc/rc.local
```

然后把你需要启动脚本写入 `/etc/rc.local` ，我们不妨写一些测试的脚本放在里面，以便验证脚本是否生效.

- 创建开机启动的软链接,这点也比较关键，`systemd` 默认读取 `/etc/systemd/system` 下的配置文件, 所以还需要在 `/etc/systemd/system` 目录下创建软链接

```
ln -s /lib/systemd/system/rc.local.service /etc/systemd/system/
```

- 开机自动启动shadowsocks

```
$ sudo vim /etc/rc.local

home/feng/.local/bin/sslocal -c /etc/shadowsocks.json -d start
```

- tips，如果上述操作不成功，可以尝试手工启动

```
]# vim ss.sh
#!/bin/bash
/usr/bin/sudo $HOME/.local/bin/sslocal -c /etc/shadowsocks.json -d start
]# chmod +x ss.sh
]# ./ss.sh
输入秘密即可开启
```

## fixfox代理设置

- 打开firefox浏览器，添加`Proxy SwitchyOmega`

```
1.在浏览器里输入about:addons
2.在 Search on addons.mozilla.org里输入 Proxy SwitchyOmega 
3.点击Add添加后，有浏览器告诉你如何安装
```

- 设置Proxy

```
#点击已经添加的Proxy SwitchyOmega 
1.#点击Profiles下的Proxy
	Scheme 		Protocol 	Server 		Port 	
	(default) 	SOCKS5		127.0.0.1   1080

2.#点击Profiles下的auto switch
		添加
	Rule list rules 	(Any request matching the rule list below) 	proxy
	Default 											            Direct
	
	Rule List Config
		Rule List Format Switchy		AutoProxy #选择AutoProxy
		
	Rule List URL	
		https://raw.githubusercontent.com/gfwlist/gfwlist/master/gfwlist.txt
	#设置完后，点击Download Profile Now 
	
3.#点击ACTIONS ----Apply changes  
	至此设置完成
```

- 点击firefox，进行访问，在浏览器右上角点击小圆圈选择`auto swith`,然后访问google吧

```
$ tail /var/log/shadowsocks.log 
INFO: loading config from /etc/shadowsocks/config.json
2018-07-25 21:15:49 INFO   starting local at 127.0.0.1:1080
2018-07-25 22:18:31 INFO   connecting www.google.com:443 from 127.0.0.1:49532
2018-07-25 22:18:31 INFO   connecting www.google.com:443 from 127.0.0.1:49536
2018-07-25 22:18:31 INFO   connecting www.google.com:443 from 127.0.0.1:49540
```

- chrome代理设置

> [SwitchyOmega](https://github.com/FelisCatus/SwitchyOmega/releases)下载github上的chrome的.crx文件.
>
> 进入chrome浏览器，进入拓展管理页面，勾选开发模式，把下载好的crx文件拖入插件区域即可。
>
> 后续可以参照firefox即可。

如果拖拽不了.crx文件，请使用下面的命令进入chrome，即可安装

```
# /opt/google/chrome/chrome --enable-easy-off-store-extension-install
```

感谢阅读！

## 踏坑学习

- 安装shadowsocks

```
sudo apt-get install shadowsocks
```

后面的操作基本上面进行，依然访问不了

```
tail -f /var/log/shadowsocks.log 
2018-07-25 22:18:31 INFO  clinet connecting denied
```

这里权限拒绝，是支持的加密方式可能和我的VPS不一样 。安装最新的shadowscoks即可解决问题！

# ubuntu-lxc容器创建

```
sudo apt-get install lxc*     			#搭建lxc    
sudo apt-get install yum	 			#搭建yum
sudo lxc-create -n temp -t centos 		#创建centos系统主机名为temp。
sudo chroot /var/lib/lxc/temp/rootfs passwd		#输入root密码
sudo lxc-copy -n temp -N node01			#fork新的虚拟机以temp为模板。
sudo lxc-ls
sudo lxc-ls -f							#查看容器信息
sudo lxc-start -n node01				#开启 node01
sudo lxc-console -n node01				#进入 node01
sudo lxc-ls -f				
ssh root@10.0.3.116						#ssh连接
sudo lxc-info -n node01
sudo lxc-start temp
sudo lxc-info -n temp
sudo lxc-stop -n node01					#停止服务
sudo lxc-destroy -n node01				#销毁容器
```
