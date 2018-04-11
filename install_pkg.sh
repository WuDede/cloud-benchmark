#!/bin/sh

for x in 234 109
do
    ssh -o ServerAliveInterval=5 -o ServerAliveCountMax=2 -o StrictHostKeyChecking=no -o ConnectTimeout=5 root@192.168.1.$x yum -y install make gcc vim perl automake libtool qperf;
done
