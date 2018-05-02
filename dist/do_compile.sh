#!/bin/sh

main()
{
	#yum -y install make gcc vim perl automake libtool qperf
	local xpwd=$(pwd)

	#wget http://soft.vpser.net/test/unixbench/unixbench-5.1.2.tar.gz
	cd ./unixbench-5.1.2 &&
	make || return 1
	cd $xpwd

	#wget https://github.com/akopytov/sysbench/archive/1.0.14.zip
	#mv 1.0.14.zip sysbench-1.0.14.zip
	cd ./sysbench-1.0.14 &&
	./autogen.sh &&
	./configure --prefix=$xpwd/sysbench-1.0.14/testbin --without-mysql &&
	make &&
	make install || return 1
    cd $xpwd

	#wget http://www.numberworld.org/y-cruncher/y-cruncher%20v0.7.5.9481-static.tar.gz

    #wget -r -np -nH -R index.html https://www.cs.virginia.edu/stream/FTP/Code/
    cd ./stream
    gcc -O3 -fopenmp -D OPENMP -D STREAM_ARRAY_SIZE=64000000 -D NTIMES=100 stream.c -o stream
    cd $xpwd

    #wget http://cdn.primatelabs.com/Geekbench-3.4.1-Linux.tar.gz
    #tar xf Geekbench-3.4.1-Linux.tar.gz
    cd ./Geekbench-3.4.1-Linux
    ./geekbench_x86_64 -r lhcici521@163.com qpp6g-kq4el-bo72w-mdngp-2kcvx-eu2uq-gjrkp-l5q7r-qi36y

    cd $xpwd
	rm -rf $1
	touch $1
}

main "$@"
