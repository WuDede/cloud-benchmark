#!/bin/sh
SSH_OPT="-o ServerAliveInterval=5 -o ServerAliveCountMax=2 -o StrictHostKeyChecking=no -o ConnectTimeout=5"

for x in 209 171
do
    #phoronix-test-suite test need
    #ssh $SSH_OPT root@192.168.1.$x yum -y install php xdg-utils php-xml pcre expat-devel
    ssh $SSH_OPT root@192.168.1.$x yum -y install make gcc vim perl automake libtool qperf php xdg-utils php-xml
    if [ $? -eq 0 ]; then
        echo "VM $192.168.1.$x install packages SUCCESS"
    else
        echo "VM $192.168.1.$x install packages FAIL"
        exit 1
    fi
done
