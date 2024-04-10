#!/usr/bin/env bash
# parms define
# args: [i, $ip_start, $master_ip_start,$master_num_instances, $worker_ip_start,$worker_num_instances]
# $1 第几个节点  $2 ip段 $3 ip开始  $4 节点数量 $5 ip开始  $6 节点数量
# change time zone
cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
timedatectl set-timezone Asia/Shanghai
rm /etc/yum.repos.d/CentOS-Base.repo
cp /vagrant/yum/*.* /etc/yum.repos.d/
mv /etc/yum.repos.d/CentOS7-Base-163.repo /etc/yum.repos.d/CentOS-Base.repo
# using socat to port forward in helm tiller
# install  kmod and ceph-common for rook
yum install -y wget curl conntrack-tools vim net-tools telnet tcpdump bind-utils socat ntp kmod ceph-common dos2unix
yum install -y nfs-utils
echo 10.129.0.12:/home/nfs /mnt nfs rw,sync 0 0 >>/etc/fstab
mount -a
ls /mnt
kubernetes_release="/vagrant/kubernetes-server-linux-amd64.tar.gz"
#k8s_version="1.16.14"
k8s_version="1.14.8"
# Download Kubernetes
# if [[ $(hostname) == "node1" ]] && [[ ! -f "$kubernetes_release" ]]; then
if [[ ! -f "$kubernetes_release" ]]; then #hyper-v环境下共享路径有问题，没反向复制到宿主，始终复制
    #wget https://storage.googleapis.com/kubernetes-release/release/v$k8s_version/kubernetes-server-linux-amd64.tar.gz -P /vagrant/
    wget http://192.168.82.71:8083/mirror/v$k8s_version/kubernetes-server-linux-amd64.tar.gz -P /vagrant/
fi

# enable ntp to sync time
echo 'sync time'
systemctl start ntpd
systemctl enable ntpd
echo 'disable selinux'
setenforce 0
sed -i 's/=enforcing/=disabled/g' /etc/selinux/config

echo 'enable iptable kernel parameter'
cat >>/etc/sysctl.conf <<EOF
net.ipv4.ip_forward=1
EOF
sysctl -p

echo 'set host name resolution'
for ((i = 1; i <= $4; i++)); do
    echo $2$(expr $3 + $i) master$i >>/etc/hosts
done
echo 'set host name resolution'
for ((i = 1; i <= $6; i++)); do
    echo $2$(expr $5 + $i) worker$i >>/etc/hosts
done

#修改按照数量自动添加
#cat >>/etc/hosts <<EOF
#10.129.0.101 node1
#10.129.0.102 node2
#10.129.0.103 node3
#EOF

cat /etc/hosts

# echo 'set nameserver'
# echo "nameserver 8.8.8.8">/etc/resolv.conf
# cat /etc/resolv.conf

echo 'disable swap'
swapoff -a
sed -i '/swap/s/^/#/' /etc/fstab

#create group if not exists
egrep "^docker" /etc/group >&/dev/null
if [ $? -ne 0 ]; then
    groupadd docker
fi

usermod -aG docker vagrant
rm -rf ~/.docker/
yum install -y docker.x86_64
# To fix docker exec error, downgrade docker version, see https://github.com/openshift/origin/issues/21590
yum downgrade -y docker-1.13.1-75.git8633870.el7.centos.x86_64 docker-client-1.13.1-75.git8633870.el7.centos.x86_64 docker-common-1.13.1-75.git8633870.el7.centos.x86_64

cat >/etc/docker/daemon.json <<EOF
{
  "registry-mirrors" : [
	"https://reg-mirror.qiniu.com",
	"https://hub-mirror.c.163.com",
	"https://mirror.ccs.tencentyun.com",
	"https://docker.mirrors.ustc.edu.cn",
	"https://dockerhub.azk8s.cn",
	"https://registry.docker-cn.com"
  ]
}
EOF

echo 'install flannel...'
yum install -y flannel

echo 'create flannel config file...'

cat >/etc/sysconfig/flanneld <<EOF
# Flanneld configuration options
FLANNEL_ETCD_ENDPOINTS="http://$2$(expr $3 + 1):2379"
FLANNEL_ETCD_PREFIX="/kube-centos/network"
FLANNEL_OPTIONS="-iface=eth1"
EOF

echo 'enable flannel with host-gw backend'
rm -rf /run/flannel/
systemctl daemon-reload
systemctl enable flanneld
systemctl start flanneld

echo 'enable docker'
systemctl daemon-reload
systemctl enable docker
systemctl start docker

echo "copy pem, token files"
mkdir -p /etc/kubernetes/ssl
cp /vagrant/pki/* /etc/kubernetes/ssl/
cp /vagrant/conf/token.csv /etc/kubernetes/
cp /vagrant/conf/bootstrap.kubeconfig /etc/kubernetes/
cp /vagrant/conf/kube-proxy.kubeconfig /etc/kubernetes/
cp /vagrant/conf/kubelet.kubeconfig /etc/kubernetes/

tar -xzvf /vagrant/kubernetes-server-linux-amd64.tar.gz --no-same-owner -C /vagrant
cp /vagrant/kubernetes/server/bin/* /usr/bin

dos2unix -q /vagrant/systemd/*.service
cp /vagrant/systemd/*.service /usr/lib/systemd/system/
mkdir -p /var/lib/kubelet
mkdir -p ~/.kube
cp /vagrant/conf/admin.kubeconfig ~/.kube/config

echo "configure node$1"
#cp "/vagrant/node$1/*" /etc/kubernetes/
cat >/etc/kubernetes/kubelet <<EOF
###
## kubernetes kubelet (minion) config
#
## The address for the info server to serve on (set to 0.0.0.0 or "" for all interfaces)
KUBELET_ADDRESS="--address=$2$(expr $5 + $1)"
#
## The port for the info server to serve on
#KUBELET_PORT="--port=10250"
#
## You may leave this blank to use the actual hostname
KUBELET_HOSTNAME="--hostname-override=worker$1"
#
## location of the api-server
## COMMENT THIS ON KUBERNETES 1.8+
# KUBELET_API_SERVER="--api-servers=http://172.20.0.113:8080"
#
## pod infrastructure container
KUBELET_POD_INFRA_CONTAINER="--pod-infra-container-image=registry.aliyuncs.com/google_containers/pause:3.1"
#
## Add your own!
KUBELET_ARGS="--runtime-cgroups=/systemd/system.slice --kubelet-cgroups=/systemd/system.slice --cgroup-driver=systemd --cluster-dns=10.254.0.2 --bootstrap-kubeconfig=/etc/kubernetes/bootstrap.kubeconfig --kubeconfig=/etc/kubernetes/kubelet.kubeconfig --cert-dir=/etc/kubernetes/ssl --cluster-domain=cluster.local --hairpin-mode promiscuous-bridge --serialize-image-pulls=false"

EOF

cat >/etc/kubernetes/proxy <<EOF
###
# kubernetes proxy config
# default config should be adequate
# Add your own!
KUBE_PROXY_ARGS="--bind-address=$2$(expr $5 + $1) --kubeconfig=/etc/kubernetes/kube-proxy.kubeconfig --cluster-cidr=10.254.0.0/16 --hostname-override=worker$1"
EOF

systemctl daemon-reload
systemctl enable kubelet
systemctl start kubelet
systemctl enable kube-proxy
systemctl start kube-proxy

if [[ $1 -eq 3 ]]; then

    echo "deploy coredns"
    cd /vagrant/addon/dns/
    ./dns-deploy.sh -r 10.254.0.0/16 -i 10.254.0.2 | kubectl apply -f -
    cd -

    echo "deploy kubernetes dashboard"
    kubectl apply -f /vagrant/addon/dashboard/kubernetes-dashboard.yaml
    echo "create admin role token"
    kubectl apply -f /vagrant/yaml/admin-role.yaml
    echo "the admin role token is:"
    kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep admin-token | cut -d " " -f1) | grep "token:" | tr -s " " | cut -d " " -f2
    echo "login to dashboard with the above token"
    echo https://$2$(expr $3 + 1):$(kubectl -n kube-system get svc kubernetes-dashboard -o=jsonpath='{.spec.ports[0].port}')
    echo "install traefik ingress controller"
    kubectl apply -f /vagrant/addon/traefik-ingress/
fi

echo "Configure Kubectl to autocomplete"
source <(kubectl completion bash)                    # setup autocomplete in bash into the current shell, bash-completion package should be installed first.
echo "source <(kubectl completion bash)" >>~/.bashrc # add autocomplete permanently to your bash shell.
