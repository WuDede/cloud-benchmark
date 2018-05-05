#!/bin/sh
SSH_OPT="-o ServerAliveInterval=5 -o ServerAliveCountMax=2 -o StrictHostKeyChecking=no -o ConnectTimeout=5"

pts_dep="php xdg-utils php-xml pcre expat-devel libevent libevent-devel numactl-devel golang glibc-static gcc-c++ pcre pcre-devel unzip bzip2 patch autoconf"
oth_dep="make gcc vim perl automake libtool qperf"
for x in 75
do
    ssh $SSH_OPT root@192.168.1.$x rm -rf /tmp/pkg_install &&
    scp $SSH_OPT -r ./pkg root@192.168.1.$x:/tmp/pkg_install &&
    ssh $SSH_OPT root@192.168.1.$x yum -y install $oth_dep $pts_dep
    if [ $? -eq 0 ]; then
        echo "VM $192.168.1.$x install packages SUCCESS"
    else
        echo "VM $192.168.1.$x install packages FAIL"
        exit 1
    fi
    ssh $SSH_OPT root@192.168.1.$x "rpm -ivh /tmp/pkg_install/*"
done
