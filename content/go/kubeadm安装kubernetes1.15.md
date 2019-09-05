---
title: "kubeadm 安装 kubernetes1.15"
date: 2019-06-27 15:56
tag: 
- go
- kubernetes1.15
---

[TOC]

kubeadm是Kubernetes官方提供的用于快速安装Kubernetes集群的工具，伴随Kubernetes每个版本的发布都会同步更新，kubeadm会对集群配置方面的一些实践做调整，通过实验kubeadm可以学习到Kubernetes官方在集群配置上一些新的最佳实践。

## 环境准备

### 主机名

设置永久主机名称，然后重新登录:

```
hostnamectl set-hostname master # 将 master 替换为当前主机名
```

- 设置的主机名保存在 `/etc/hostname` 文件中；

如果 DNS 不支持解析主机名称，则需要修改每台机器的 `/etc/hosts` 文件，添加主机名和 IP 的对应关系：

```
cat >> /etc/hosts <<EOF
192.168.18.10 master
192.168.18.11 node01
192.168.18.12 node02
EOF
```

### 关闭防火墙

在每台机器上关闭防火墙，清理防火墙规则，设置默认转发策略：

```
systemctl stop firewalld
systemctl disable firewalld
iptables -F && iptables -X && iptables -F -t nat && iptables -X -t nat
iptables -P FORWARD ACCEPT
```

### 关闭 swap 分区

如果开启了 swap 分区，kubelet 会启动失败(可以通过将参数 --fail-swap-on 设置为 false 来忽略 swap on)，故需要在每台机器上关闭 swap 分区。同时注释 `/etc/fstab` 中相应的条目，防止开机自动挂载 swap 分区：

```
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab 
```

### 关闭 SELinux

关闭 SELinux，否则后续 K8S 挂载目录时可能报错 `Permission denied`：

```
setenforce 0
sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
```

### 加载内核模块

```
cat > /etc/sysconfig/modules/ipvs.modules <<EOF
#!/bin/bash
modprobe -- ip_vs
modprobe -- ip_vs_rr
modprobe -- ip_vs_wrr
modprobe -- ip_vs_sh
modprobe -- nf_conntrack_ipv4
EOF
chmod 755 /etc/sysconfig/modules/ipvs.modules && bash /etc/sysconfig/modules/ipvs.modules && lsmod | grep -e ip_vs -e nf_conntrack_ipv4
```

上面脚本创建了的`/etc/sysconfig/modules/ipvs.modules`文件，保证在节点重启后能自动加载所需模块。 使用`lsmod | grep -e ip_vs -e nf_conntrack_ipv4`命令查看是否已经正确加载所需的内核模块。

接下来还需要确保各个节点上已经安装了ipset软件包`yum install ipset`。 为了便于查看ipvs的代理规则，最好安装一下管理工具ipvsadm `yum install ipvsadm`。

### 优化内核参数

```bash
$ cat > kubernetes.conf <<EOF
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-ip6tables=1
net.ipv4.ip_forward=1
net.ipv4.tcp_tw_recycle=0
vm.swappiness=0 # 禁止使用 swap 空间，只有当系统 OOM 时才允许使用它
vm.overcommit_memory=1 # 不检查物理内存是否够用
vm.panic_on_oom=0 # 开启 OOM
fs.inotify.max_user_instances=8192
fs.inotify.max_user_watches=1048576
fs.file-max=52706963
fs.nr_open=52706963
net.ipv6.conf.all.disable_ipv6=1
net.netfilter.nf_conntrack_max=2310720
EOF

$ cp kubernetes.conf  /etc/sysctl.d/kubernetes.conf
$ sysctl -p /etc/sysctl.d/kubernetes.conf
```

### 安装Docker

Kubernetes从1.6开始使用CRI(Container Runtime Interface)容器运行时接口。默认的容器运行时仍然是Docker，使用的是kubelet中内置`dockershim` CRI实现。

```bash
$ yum install -y yum-utils \
  device-mapper-persistent-data \
  lvm2
$ yum install docker-ce docker-ce-cli containerd.io
Loaded plugins: fastestmirror, product-id, search-disabled-repos, subscription-manager
This system is not registered with an entitlement server. You can use subscription-manager to register.
Loading mirror speeds from cached hostfile
 * epel: epel.dionipe.id
 * rpmfusion-free-updates: fr2.rpmfind.net
 * rpmfusion-nonfree-updates: fr2.rpmfind.net
 * webtatic: uk.repo.webtatic.com
Resolving Dependencies
--> Running transaction check
---> Package docker-ce.x86_64 3:18.09.3-3.el7 will be installed
--> Processing Dependency: container-selinux >= 2.9 for package: 3:docker-ce-18.09.3-3.el7.x86_64
--> Processing Dependency: containerd.io >= 1.2.2-3 for package: 3:docker-ce-18.09.3-3.el7.x86_64
--> Processing Dependency: docker-ce-cli for package: 3:docker-ce-18.09.3-3.el7.x86_64
--> Processing Dependency: libcgroup for package: 3:docker-ce-18.09.3-3.el7.x86_64
--> Running transaction check
---> Package containerd.io.x86_64 0:1.2.4-3.1.el7 will be installed
---> Package docker-ce.x86_64 3:18.09.3-3.el7 will be installed
--> Processing Dependency: container-selinux >= 2.9 for package: 3:docker-ce-18.09.3-3.el7.x86_64
---> Package docker-ce-cli.x86_64 1:18.09.3-3.el7 will be installed
---> Package libcgroup.x86_64 0:0.41-20.el7 will be installed
--> Finished Dependency Resolution
Error: Package: 3:docker-ce-18.09.3-3.el7.x86_64 (docker-ce-stable)
           Requires: container-selinux >= 2.9
 You could try using --skip-broken to work around the problem
 You could try running: rpm -Va --nofiles --nodigest
```

centosm默认yum安装docker会报错`container-selinux >= 2.9`,建存储库以指向CentOS repo。在其中创建一个文件`/etc/yum.repos.d`并为其命名，`centos.repo`并添加以下存储库资源。

```bash
# Create new repo to enable CentOS
[centos]
name=CentOS-7
baseurl=http://ftp.heanet.ie/pub/centos/7/os/x86_64/
enabled=1
gpgcheck=1
gpgkey=http://ftp.heanet.ie/pub/centos/7/os/x86_64/RPM-GPG-KEY-CentOS-7
```

然后，`container-selinux`从CentOS镜像站点安装。将版本更改为此站点中列出的最新版本。

```bash
$ yum update
$ yum install -y http://mirror.centos.org/centos/7/extras/x86_64/Packages/container-selinux-2.74-1.el7.noarch.rpm

$ systemctl enable docker
$ systemctl start docker
```

### 修改docker cgroup driver为systemd

根据文档[CRI installation](https://kubernetes.io/docs/setup/cri/)中的内容，对于使用systemd作为init system的Linux的发行版，使用systemd作为docker的cgroup driver可以确保服务器节点在资源紧张的情况更加稳定，因此这里修改各个节点上docker的cgroup driver为systemd。

```bash
{
  "exec-opts": ["native.cgroupdriver=systemd"]
}
```

创建或修改`/etc/docker/daemon.json`：重启docker：

```bash
$ systemctl restart docker
```

### google的k8s镜像下载

google镜像问题，需要科学上网才能解决，这里提供代理解决方案

```bash
$ cat  <<EOF > azk8s.sh 
#!/bin/bash
## k8s关键镜像 ##
docker pull gcr.azk8s.cn/google_containers/coredns:1.3.1 k8s.gcr.io/coredns:1.3.1
docker pull gcr.azk8s.cn/google_containers/etcd:3.3.10 k8s.gcr.io/etcd:3.3.10
docker pull gcr.azk8s.cn/google_containers/kube-scheduler:v1.15.0 k8s.gcr.io/kube-scheduler:v1.15.0
docker pull gcr.azk8s.cn/google_containers/kube-controller-manager:v1.15.0 k8s.gcr.io/kube-controller-manager:v1.15.0
docker pull gcr.azk8s.cn/google_containers/kube-apiserver:v1.15.0 k8s.gcr.io/kube-apiserver:v1.15.0
docker pull gcr.azk8s.cn/google_containers/kube-proxy:v1.15.0 
docker pull gcr.azk8s.cn/google_containers/pause:3.1

## helm和tiller和dashboard镜像 ##
docker pull gcr.azk8s.cn/kubernetes-helm/tiller:v2.14.1 
docker pull gcr.azk8s.cn/google_containers/kubernetes-dashboard-amd64:v1.10.1
docker pull gcr.azk8s.cn/google_containers/metrics-server-amd64:v0.3.1

## 重新tag 镜像 ##
docker tag gcr.azk8s.cn/google_containers/coredns:1.3.1 k8s.gcr.io/coredns:1.3.1
docker tag gcr.azk8s.cn/google_containers/etcd:3.3.10 k8s.gcr.io/etcd:3.3.10
docker tag gcr.azk8s.cn/google_containers/pause:3.1 k8s.gcr.io/pause:3.1
docker tag gcr.azk8s.cn/google_containers/kube-proxy:v1.15.0 k8s.gcr.io/kube-proxy:v1.15.0
docker tag gcr.azk8s.cn/google_containers/kube-scheduler:v1.15.0 k8s.gcr.io/kube-scheduler:v1.15.0
docker tag gcr.azk8s.cn/google_containers/kube-controller-manager:v1.15.0 k8s.gcr.io/kube-controller-manager:v1.15.0
docker tag gcr.azk8s.cn/google_containers/kube-apiserver:v1.15.0 k8s.gcr.io/kube-apiserver:v1.15.0
docker tag gcr.azk8s.cn/kubernetes-helm/tiller:v2.14.1 gcr.io/kubernetes-helm/tiller:v2.14.1
docker tag gcr.azk8s.cn/google_containers/kubernetes-dashboard-amd64:v1.10.1 k8s.gcr.io/kubernetes-dashboard-amd64:v1.10.1
docker tag gcr.azk8s.cn/google_containers/metrics-server-amd64:v0.3.1 gcr.io/google_containers/metrics-server-amd64:v0.3.1
EOF

$ bash -x azk8s.sh 
### 据说kubeadm  --image-repository 可以直接更改镜像仓库，这样就不用担心被墙了。可以试一下
```



## 使用kubeadm部署Kubernetes

下面在各节点安装kubeadm和kubelet：

```bash
$ cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=0
EOF
```

yum安装kubeadm：

```bash
$ yum makecache fast
$ yum install -y kubelet kubeadm kubectl
```

因为这里本次用于测试三台主机上还运行其他服务，关闭swap可能会对其他服务产生影响，所以这里修改kubelet的配置去掉这个限制。 使用kubelet的启动参数`--fail-swap-on=false`去掉必须关闭Swap的限制，修改/etc/sysconfig/kubelet，加入：

```bash
KUBELET_EXTRA_ARGS=--fail-swap-on=false
```

在各节点开机启动kubelet服务：

```bash
$ systemctl enable kubelet.service
```

在master节点初始化集群：

```bash
$ kubeadm init \
  --kubernetes-version=v1.15.0 \
  --pod-network-cidr=10.244.0.0/16 \
  --apiserver-advertise-address=192.168.18.10 \
  --ignore-preflight-errors=Swap

  
不加--ignore-preflight-errors=Swap，kubeadm会报错
[init] Using Kubernetes version: v1.14.0
[preflight] Running pre-flight checks
        [WARNING Swap]: running with swap on is not supported. Please disable swap
[preflight] Pulling images required for setting up a Kubernetes cluster
[preflight] This might take a minute or two, depending on the speed of your internet connection
[preflight] You can also perform this action in beforehand using 'kubeadm config images pull'
[kubelet-start] Writing kubelet environment file with flags to file "/var/lib/kubelet/kubeadm-flags.env"
[kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
[kubelet-start] Activating the kubelet service
[certs] Using certificateDir folder "/etc/kubernetes/pki"
[certs] Generating "ca" certificate and key
[certs] Generating "apiserver" certificate and key
[certs] apiserver serving cert is signed for DNS names [node1 kubernetes kubernetes.default kubernetes.default.svc kubernetes.default.svc.cluster.local] and IPs [10.96.0.1 192.168.61.11]
[certs] Generating "apiserver-kubelet-client" certificate and key
[certs] Generating "front-proxy-ca" certificate and key
[certs] Generating "front-proxy-client" certificate and key
[certs] Generating "etcd/ca" certificate and key
[certs] Generating "etcd/peer" certificate and key
[certs] etcd/peer serving cert is signed for DNS names [node1 localhost] and IPs [192.168.18.10 127.0.0.1 ::1]
[certs] Generating "etcd/healthcheck-client" certificate and key
[certs] Generating "apiserver-etcd-client" certificate and key
[certs] Generating "etcd/server" certificate and key
[certs] etcd/server serving cert is signed for DNS names [node1 localhost] and IPs [192.168.18.10 127.0.0.1 ::1]
[certs] Generating "sa" key and public key
[kubeconfig] Using kubeconfig folder "/etc/kubernetes"
[kubeconfig] Writing "admin.conf" kubeconfig file
[kubeconfig] Writing "kubelet.conf" kubeconfig file
[kubeconfig] Writing "controller-manager.conf" kubeconfig file
[kubeconfig] Writing "scheduler.conf" kubeconfig file
[control-plane] Using manifest folder "/etc/kubernetes/manifests"
[control-plane] Creating static Pod manifest for "kube-apiserver"
[control-plane] Creating static Pod manifest for "kube-controller-manager"
[control-plane] Creating static Pod manifest for "kube-scheduler"
[etcd] Creating static Pod manifest for local etcd in "/etc/kubernetes/manifests"
[wait-control-plane] Waiting for the kubelet to boot up the control plane as static Pods from directory "/etc/kubernetes/manifests". This can take up to 4m0s
[apiclient] All control plane components are healthy after 18.503026 seconds
[upload-config] storing the configuration used in ConfigMap "kubeadm-config" in the "kube-system" Namespace
[kubelet] Creating a ConfigMap "kubelet-config-1.14" in namespace kube-system with the configuration for the kubelets in the cluster
[upload-certs] Skipping phase. Please see --experimental-upload-certs
[mark-control-plane] Marking the node node1 as control-plane by adding the label "node-role.kubernetes.io/master=''"
[mark-control-plane] Marking the node node1 as control-plane by adding the taints [node-role.kubernetes.io/master:NoSchedule]
[bootstrap-token] Using token: m23ls0.23n2edf9i5w37ik6
[bootstrap-token] Configuring bootstrap tokens, cluster-info ConfigMap, RBAC Roles
[bootstrap-token] configured RBAC rules to allow Node Bootstrap tokens to post CSRs in order for nodes to get long term certificate credentials
[bootstrap-token] configured RBAC rules to allow the csrapprover controller automatically approve CSRs from a Node Bootstrap Token
[bootstrap-token] configured RBAC rules to allow certificate rotation for all node client certificates in the cluster
[bootstrap-token] creating the "cluster-info" ConfigMap in the "kube-public" namespace
[addons] Applied essential addon: CoreDNS
[addons] Applied essential addon: kube-proxy

Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

Then you can join any number of worker nodes by running the following on each as root:

 kubeadm join 192.168.18.10:6443 --token rlylpe.lwh24h3j33usmi7s     --discovery-token-ca-cert-hash sha256:3209293d8057e442d18f9586d4e2e92e759a33b2b918f09916dd674357c74a6c 
```

 其中有以下关键内容：

- `[kubelet-start]` 生成kubelet的配置文件”/var/lib/kubelet/config.yaml”
- `[certificates]`生成相关的各种证书
- `[kubeconfig]`生成相关的kubeconfig文件
- `[bootstraptoken]`生成token记录下来，后边使用`kubeadm join`往集群中添加节点时会用到.

执行提示命令：

```bash
$ mkdir -p $HOME/.kube
$ cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
$ chown $(id -u):$(id -g) $HOME/.kube/config
```

查看一下集群状态，确认个组件都处于healthy状态：

```bash
$ kubectl get cs
NAME                 STATUS    MESSAGE              ERROR
controller-manager   Healthy   ok
scheduler            Healthy   ok
etcd-0               Healthy   {"health": "true"}
```

集群初始化如果遇到问题，可以使用下面的命令进行清理：

```bash
$ kubeadm reset
$ ifconfig cni0 down
$ ip link delete cni0
$ ifconfig flannel.1 down
$ ip link delete flannel.1
$ rm -rf /var/lib/cni/
```

### 安装pod网络

```bash
$ wget https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
$ kubectl apply -f  kube-flannel.yml
## 查看安装的网络状态 ##
$ kubectl get pod --all-namespaces -o wide
NAMESPACE       NAME                                            READY   STATUS    RESTARTS   AGE     IP              NODE     NOMINATED NODE   READINESS GATES
kube-system     coredns-5c98db65d4-fsfzk                        1/1     Running   0          20m   10.244.0.2      master   <none>           <none>
kube-system     coredns-5c98db65d4-r9ckz                        1/1     Running   0          20m   10.244.0.3      master   <none>           <none>
kube-system     etcd-master                                     1/1     Running   0          19m   192.168.18.10   master   <none>           <none>
kube-system     kube-apiserver-master                           1/1     Running   0          19m   192.168.18.10   master   <none>           <none>
kube-system     kube-flannel-ds-amd64-nlw98                     1/1     Running   0          15m   192.168.18.10   master   <none>           <none>
kube-system     kube-controller-manager-master                  1/1     Running   0          19m   192.168.18.10   master   <none>           <none>
         5h18m   192.168.18.10   master   <none>           <none>
kube-system     kube-proxy-886c8                                1/1     Running   0          19m   192.168.18.10   master   <none>           <none>   
kube-system     kube-scheduler-master                           1/1     Running   0          19m   192.168.18.10   master   <none>           <none>

```

测试DNS:

```bash
$ kubectl run curl --image=radial/busyboxplus:curl -it
kubectl run --generator=deployment/apps.v1 is DEPRECATED and will be removed in a future version. Use kubectl run --generator=run-pod/v1 or kubectl create instead.
If you don't see a command prompt, try pressing enter.
[ root@curl-6bf6db5c4f-m5qws:/ ]$ nslookup kubernetes.default
Server:    10.96.0.10
Address 1: 10.96.0.10 kube-dns.kube-system.svc.cluster.local

Name:      kubernetes.default
Address 1: 10.96.0.1 kubernetes.default.svc.cluster.local
```

## 从节点加入kubernets集群

node01和node02的这几个镜像必须有，可以按照前面的脚本来下载：

```
pause:3.1
kube-proxy:v1.15.0
kubernetes-dashboard-amd64:v1.10.1
metrics-server-amd64:v0.3.1
```

从节点运行kubeadm join来加入集群：

```bash
$ kubeadm join 192.168.18.10:6443 --token rlylpe.lwh24h3j33usmi7s     --discovery-token-ca-cert-hash sha256:3209293d8057e442d18f9586d4e2e92e759a33b2b918f09916dd674357c74a6c --ignore-preflight-errors=Swap
```

运行命令后，在master上查看集群节点状态：

```bash
$ kubectl get node
NAME     STATUS   ROLES    AGE     VERSION
master   Ready    master   48m     v1.15.0
node01   Ready    <none>   20m     v1.15.0
node02   Ready    <none>   20m     v1.15.0
```

如果需要从集群中移除node02这个Node执行下面的命令：

```bash
$ kubectl drain node02 --delete-local-data --force --ignore-daemonsets
$ kubectl delete node node02
```

kube-proxy 开启ipvs：

```bash
$ kubectl edit cm kube-proxy -n kube-system
/mode ##定位至mode关键字 mode: "ipvs"
:wq! ## 需要强制写入并退出
```

重启kube-proxy服务：

```bash
$ kubectl get pod -n kube-system | grep kube-proxy | awk '{system("kubectl delete pod "$1" -n kube-system")}'
```

验证:

```bash
$ kubectl get pod -n kube-system | grep kube-proxy
kube-proxy-886c8                        1/1     Running   0          4h7m
kube-proxy-fxb2t                        1/1     Running   0          4h7m
kube-proxy-km2s4                        1/1     Running   0          4h7m

$ kubectl logs -n kube-system kube-proxy-886c8 
I0627 05:51:01.150550       1 server_others.go:170] Using ipvs Proxier.
W0627 05:51:01.151040       1 proxier.go:401] IPVS scheduler not specified, use rr by default
I0627 05:51:01.151312       1 server.go:534] Version: v1.15.0
I0627 05:51:01.169641       1 conntrack.go:52] Setting nf_conntrack_max to 131072
I0627 05:51:01.170109       1 config.go:187] Starting service config controller
I0627 05:51:01.170145       1 controller_utils.go:1029] Waiting for caches to sync for service config controller
I0627 05:51:01.170312       1 config.go:96] Starting endpoints config controller
I0627 05:51:01.170338       1 controller_utils.go:1029] Waiting for caches to sync for endpoints config controller
I0627 05:51:01.270656       1 controller_utils.go:1036] Caches are synced for service config controller
I0627 05:51:01.270679       1 controller_utils.go:1036] Caches are synced for endpoints config controller
```

## helm安装

Helm由客户端命helm令行工具和服务端tiller组成，Helm的安装十分简单。 下载helm命令行工具到master节点的/usr/bin下:

```bash
$ wget https://storage.googleapis.com/kubernetes-helm/helm-v2.14.1-linux-amd64.tar.gz
$ tar xf helm-v2.14.1-linux-amd64.tar.gz
$ cp linux-amd64/helm  /usr/bin
```

因为Kubernetes APIServer开启了RBAC访问控制，所以需要创建tiller使用的service account: tiller并分配合适的角色给它。 详细内容可以查看helm文档中的[Role-based Access Control](https://docs.helm.sh/using_helm/#role-based-access-control)。 这里简单起见直接分配cluster-admin这个集群内置的ClusterRole给它。创建rbac-config.yaml文件

```bash
$ cat >> EOF < rbac-config.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: tiller
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: tiller
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: tiller
    namespace: kube-system
EOF

$ kubectl create -f rbac-config.yaml
$ helm init --upgrade -i gcr.io/kubernetes-helm/tiller:v2.14.1  
$ helm repo remove stable
$ helm repo add stable https://kubernetes.oss-cn-hangzhou.aliyuncs.com/charts
```

**tiller默认被部署在k8s集群中的kube-system这个namespace下：**

```bash
$ kubectl get pod -n kube-system -l app=helm
NAME                             READY   STATUS    RESTARTS   AGE
tiller-deploy-7bf78cdbf7-jhmdk   1/1     Running   0          16m
```

查看helm的version：

```bash
$ helm version
Client: &version.Version{SemVer:"v2.14.1", GitCommit:"5270352a09c7e8b6e8c9593002a73535276507c0", GitTreeState:"clean"}
Server: &version.Version{SemVer:"v2.14.1", GitCommit:"5270352a09c7e8b6e8c9593002a73535276507c0", GitTreeState:"clean"}

```

创建了`tiller`的 ServceAccount 后还没完，因为我们的 Tiller 之前已经就部署成功了，而且是没有指定 `ServiceAccount` 的，所以我们需要给 Tiller 打上一个` ServiceAccount `的补丁,如果不打补丁,会导致后面的forbidden报错：

```
$ kubectl --namespace kube-system create serviceaccount tiller

$ kubectl create clusterrolebinding tiller-cluster-rule \
 --clusterrole=cluster-admin --serviceaccount=kube-system:tiller

$ kubectl --namespace kube-system patch deploy tiller-deploy \
 -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}' 
```

### 安装dashboard

dashboard.yaml

```
# Copyright 2017 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# ------------------- Dashboard Secret ------------------- #

apiVersion: v1
kind: Secret
metadata:
  labels:
    k8s-app: kubernetes-dashboard
  name: kubernetes-dashboard-certs
  namespace: kube-system
type: Opaque

---
# ------------------- Dashboard Service Account ------------------- #

apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    k8s-app: kubernetes-dashboard
  name: kubernetes-dashboard
  namespace: kube-system

---
# ------------------- Dashboard Role & Role Binding ------------------- #

kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: kubernetes-dashboard-minimal
  namespace: kube-system
rules:
  # Allow Dashboard to create 'kubernetes-dashboard-key-holder' secret.
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["create"]
  # Allow Dashboard to create 'kubernetes-dashboard-settings' config map.
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["create"]
  # Allow Dashboard to get, update and delete Dashboard exclusive secrets.
- apiGroups: [""]
  resources: ["secrets"]
  resourceNames: ["kubernetes-dashboard-key-holder", "kubernetes-dashboard-certs"]
  verbs: ["get", "update", "delete"]
  # Allow Dashboard to get and update 'kubernetes-dashboard-settings' config map.
- apiGroups: [""]
  resources: ["configmaps"]
  resourceNames: ["kubernetes-dashboard-settings"]
  verbs: ["get", "update"]
  # Allow Dashboard to get metrics from heapster.
- apiGroups: [""]
  resources: ["services"]
  resourceNames: ["heapster"]
  verbs: ["proxy"]
- apiGroups: [""]
  resources: ["services/proxy"]
  resourceNames: ["heapster", "http:heapster:", "https:heapster:"]
  verbs: ["get"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: kubernetes-dashboard-minimal
  namespace: kube-system
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: kubernetes-dashboard-minimal
subjects:
- kind: ServiceAccount
  name: kubernetes-dashboard
  namespace: kube-system

---
# ------------------- Dashboard Deployment ------------------- #

kind: Deployment
apiVersion: apps/v1
metadata:
  labels:
    k8s-app: kubernetes-dashboard
  name: kubernetes-dashboard
  namespace: kube-system
spec:
  replicas: 1
  revisionHistoryLimit: 10
  selector:
    matchLabels:
      k8s-app: kubernetes-dashboard
  template:
    metadata:
      labels:
        k8s-app: kubernetes-dashboard
    spec:
      containers:
      - name: kubernetes-dashboard
        image: k8s.gcr.io/kubernetes-dashboard-amd64:v1.10.1
        ports:
        - containerPort: 8443
          protocol: TCP
        args:
          - --auto-generate-certificates
          # Uncomment the following line to manually specify Kubernetes API server Host
          # If not specified, Dashboard will attempt to auto discover the API server and connect
          # to it. Uncomment only if the default does not work.
          # - --apiserver-host=http://my-address:port
        volumeMounts:
        - name: kubernetes-dashboard-certs
          mountPath: /certs
          # Create on-disk volume to store exec logs
        - mountPath: /tmp
          name: tmp-volume
        livenessProbe:
          httpGet:
            scheme: HTTPS
            path: /
            port: 8443
          initialDelaySeconds: 30
          timeoutSeconds: 30
      volumes:
      - name: kubernetes-dashboard-certs
        secret:
          secretName: kubernetes-dashboard-certs
      - name: tmp-volume
        emptyDir: {}
      serviceAccountName: kubernetes-dashboard
      # Comment the following tolerations if Dashboard must not be deployed on master
      tolerations:
      - key: node-role.kubernetes.io/master
        effect: NoSchedule

---
# ------------------- Dashboard Service ------------------- #

kind: Service
apiVersion: v1
metadata:
  labels:
    k8s-app: kubernetes-dashboard
  name: kubernetes-dashboard
  namespace: kube-system
spec:
  ports:
    - port: 443
      targetPort: 8443
  selector:
    k8s-app: kubernetes-dashboard

```

部署到dashboard

```
$ kubectl apply -f dashboard.yaml
```

查看授权token:

```bash
kubectl describe -n kube-system secret $(kubectl -n kube-system get secret | grep kubernetes-dashboard-token |awk '{print $1}')
Name:         dashboard-kubernetes-dashboard-token-fb7qg
Namespace:    kube-system
Labels:       <none>
Annotations:  kubernetes.io/service-account.name: dashboard-kubernetes-dashboard
              kubernetes.io/service-account.uid: f7eefc7a-1129-49d4-84eb-629dc1a90c08

Type:  kubernetes.io/service-account-token

Data
====
token:      eyJhbGciOiJSUzI1NiIsImtpZCI6IiJ9.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJpbmdyZXNzLW5naW54Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZWNyZXQubmFtZSI6ImRhc2hib2FyZC1rdWJlcm5ldGVzLWRhc2hib2FyZC10b2tlbi1mYjdxZyIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VydmljZS1hY2NvdW50Lm5hbWUiOiJkYXNoYm9hcmQta3ViZXJuZXRlcy1kYXNoYm9hcmQiLCJrdWJlcm5ldGVzLmlvL3NlcnZpY2VhY2NvdW50L3NlcnZpY2UtYWNjb3VudC51aWQiOiJmN2VlZmM3YS0xMTI5LTQ5ZDQtODRlYi02MjlkYzFhOTBjMDgiLCJzdWIiOiJzeXN0ZW06c2VydmljZWFjY291bnQ6aW5ncmVzcy1uZ2lueDpkYXNoYm9hcmQta3ViZXJuZXRlcy1kYXNoYm9hcmQifQ.f7TqF8CWpZJSUlhFyDPGwF21Em-Lx-BFJGZM_nsuF7FLkpBn0hxDmz8Hwtuho5WBegpDVRMuTzKk8odOpUikzvDmDkedjAQ0y_bDy1hDf1D2F8HKuBsbraZwPC9ep6VpvJ8h8AOIwFHIrw7C4p5ZmwrpXqcwVujmoUISpgCnQW0QhJJyAVAatowX8qxa9RDmHyQ4BG5_csGs7Mt0-pBsLNdAENMj6yw6IAGXRmZwO5XEZ5SFGeMBvSXRVnI2smeLqAtHnLKGevGjYu7M_DgU5K3Znp2ux1StJFFWrTqo1AP-D0XkcJ27DtA9Ccaqy09sh4WsZ_ekzHLA4u7IzChEgw
ca.crt:     1025 bytes
namespace:  13 bytes
```

如果没有利用ingress，客户端访问`p12`证书生成：

```bash
$ cd ~/.kube
$ grep 'client-certificate-data' config |head -n 1 |awk '{print $2}'  |base64 -d >> kubecfg.crt
$ grep 'client-key-data' config  |head -n 1 |awk '{print $2}' |base64 -d >> kubecfg.key
$ openssl pkcs12 -export -clcerts -inkey kubecfg.key -in kubecfg.crt -out kubecfg.p12 -name "kubernetes-web-client"
```

访问`https://192.168.18.11:6443/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy`

#### 客户端选择证书的原理

1. 证书选择是在客户端和服务端 SSL/TLS 握手协商阶段商定的；
2. 服务端如果要求客户端提供证书，则在握手时会向客户端发送一个它接受的 CA 列表；
3. 客户端查找它的证书列表(一般是操作系统的证书，对于 Mac 为 keychain)，看有没有被 CA 签名的证书，如果有，则将它们提供给用户选择（证书的私钥）；
4. 用户选择一个证书私钥，然后客户端将使用它和服务端通信；



