#!/bin/sh

main()
{
	#yum -y install make gcc vim perl automake libtool qperf
	local xpwd=$(pwd)

	#wget http://soft.vpser.net/test/unixbench/unixbench-5.1.2.tar.gz
	cd ./unixbench-5.1.2 &&
	make clean &&
	make || return 1
	cd $xpwd

	#wget https://github.com/akopytov/sysbench/archive/1.0.14.zip
	#mv 1.0.14.zip sysbench-1.0.14.zip
	cd ./sysbench-1.0.14 &&
	./autogen.sh &&
	./configure --prefix=$xpwd/sysbench-1.0.14/testbin --without-mysql &&
	make &&
	make install || return 1

	#wget http://www.numberworld.org/y-cruncher/y-cruncher%20v0.7.5.9481-static.tar.gz

	rm -rf /root/dist/compile.done
	touch /root/dist/compile.done
}

main "$@"
