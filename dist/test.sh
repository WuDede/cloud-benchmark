#!/bin/sh

TDIR=$1
NR_ITER=1000
NR_UNIXBENCH=1
NR_Y_CRUNCHER=1
NR_SYSBENCH=1
NR_QPERF=1
LOG_PREFIX=$$
NR_CPU=$(cat /proc/cpuinfo | grep -i processor | wc -l)
RUN_FLAG=$TDIR/perf.run.flag
SSH_OPT="-o ServerAliveInterval=5 -o ServerAliveCountMax=2 -o StrictHostKeyChecking=no -o ConnectTimeout=5"

test_unixbench()
{
	local nr_iter=1
	local logfile=$TDIR/result.${LOG_PREFIX}.unixbench.log
	local ts=
	local te=
	local tc=
	[ -n "$1" ] && nr_iter=$1
	cd $TDIR/dist/unixbench-5.1.2
	for i in $(seq $nr_iter)
	do 
		[ -f $RUN_FLAG ] || return
		ts=$(awk '{print $1}' /proc/uptime)
		./Run -q -c $NR_CPU -i 1 system 2>&1 | tee -a $logfile
		te=$(awk '{print $1}' /proc/uptime)
		tc=$(echo $ts $te | awk '{print $2 - $1}')
		echo unixbench test at $(date "+%Y/%m/%d %H:%M:%S") cost $tc seconds >> $logfile
		sleep 3
	done 
}

test_y_cruncher()
{
	local nr_iter=1
	local logfile=$TDIR/result.${LOG_PREFIX}.y-cruncher.log
	local ts=
	local te=
	local tc=
	[ -n "$1" ] && nr_iter=$1
	cd $TDIR/dist/y-cruncher_v0.7.5.9481-static
	for i in $(seq $nr_iter)
	do 
		[ -f $RUN_FLAG ] || return
		ts=$(awk '{print $1}' /proc/uptime)
		./y-cruncher bench $(( NR_CPU * 16 ))M 2>&1 | tee -a $logfile
		te=$(awk '{print $1}' /proc/uptime)
		tc=$(echo $ts $te | awk '{print $2 - $1}')
		echo  test y-cruncher at $(date "+%Y/%m/%d %H:%M:%S") cost $tc seconds >> $logfile
		sleep 3
	done 
}

test_sysbench_fileio()
{
	local timeout=30
	local blksize=4096
	local rwratio=1
	echo -n "sysbench timeout=$timeout blksize=$blksize rwratio=$rwratio testmode=$1 "
	./sysbench --time=$timeout fileio --file-block-size=blksize --file-test-mode=$1 --file-rw-ratio=$rwratio run 2>&1 | grep "read, MiB\|written, MiB" | tr '\n' ' ' | sed "s|[[:blank:]]\+| |g"
	echo ""
}

test_sysbench_memory()
{
	local timeout=30
	local blksize=$1
	local oper=$2
	local mode=$3
	echo -n "sysbench timeout=$timeout blksize=$blksize oper=$oper mode=$mode "
	./sysbench --time=$timeout --num-threads=$NR_CPU --memory-block-size=$blksize memory --memory-total-size=4096G --memory-oper=$oper --memory-access-mode=$mode run 2>&1 | grep "events per second:" | sed "s|[[:blank:]]\+| |g"
}

test_sysbench()
{
	local nr_iter=1
	local logfile=$TDIR/result.${LOG_PREFIX}.sysbench.log
	local ts=
	local te=
	local tc=
	[ -n "$1" ] && nr_iter=$1
	cd $TDIR/dist/sysbench-1.0.14/testbin/bin
	for i in $(seq $nr_iter)
	do 
		[ -f $RUN_FLAG ] || return
		ts=$(awk '{print $1}' /proc/uptime)

		for fileop in seqwr seqrd seqrewr rndwr rndrd rndrewr
		do
			test_sysbench_fileio $fileop 2>&1 | tee -a $logfile
		done

		echo -n "timeout=30 threads=$NR_CPU " 2>&1 | tee -a $logfile
		./sysbench --time=30 --num-threads=$NR_CPU cpu run 2>&1 | grep "events per second:" 2>&1 | tee -a $logfile

		test_sysbench_memory 8 read seq 2>&1 | tee -a $logfile
		test_sysbench_memory 8 write seq 2>&1 | tee -a $logfile
		test_sysbench_memory 8 read rnd 2>&1 | tee -a $logfile
		test_sysbench_memory 8 write rnd 2>&1 | tee -a $logfile
		test_sysbench_memory 1K read seq 2>&1 | tee -a $logfile
		test_sysbench_memory 1K write seq 2>&1 | tee -a $logfile
		test_sysbench_memory 1K read rnd 2>&1 | tee -a $logfile
		test_sysbench_memory 1K write rnd 2>&1 | tee -a $logfile

		for trd_times in 1 2 4 8 16 32 64 128 256
		do 
			echo -n "timeout=30 threads=$(( NR_CPU * trd_times )) " 2>&1 | tee -a $logfile
			./sysbench --time=30 --threads=$(( NR_CPU * trd_times )) threads run 2>&1 | grep "total number of events:" 2>&1 | tee -a $logfile
		done 

		te=$(awk '{print $1}' /proc/uptime)
		tc=$(echo $ts $te | awk '{print $2 - $1}')
		echo  test y-cruncher at $(date "+%Y/%m/%d %H:%M:%S") cost $tc seconds >> $logfile
		sleep 3
	done 
}

test_qperf()
{
	local nr_iter=1
	local logfile=$TDIR/result.${LOG_PREFIX}.qperf.log
	local ts=
	local te=
	local tc=
	[ -n "$1" ] && nr_iter=$1

	ts=$(awk '{print $1}' /proc/uptime)
	#qperf test between 2 vms, so we need wait for another vm ready
	#in vm-list has vm1 vm2
	local myip=$(/sbin/ifconfig | grep 192.168 | sed "s|.*\(192.168\.[0-9]\+\.[0-9]\+\).*netmask.*|\1|g")
	local vm1=$(grep -w "${myip}" ./vm-list | grep -v "^[[:blank:]]*#" | awk '{print $1}')
	local vm2=$(grep -w "${myip}" ./vm-list | grep -v "^[[:blank:]]*#" | awk '{print $2}')
	local reip=$([ "$myip" = "$vm1" ] && echo $vm2 || echo $vm1)
	echo "myip=$myip reip=$reip vm1=$vm1 vm2=$vm2" | tee -a $logfile
	[ -z "$myip" -o -z "$vm1" -o -z "$vm2" -o -z "$reip" ] && return 1
	#mark that we are ok, if file ${RUN_FLAG}.qperf exist, means $reip ready
	ssh $SSH_OPT root@$reip touch ${RUN_FLAG}.qperf
	#start server
	qperf 2>&1 > ${logfile}.qperf-server &
	#wait the other vm ready
	while [ -f ${RUN_FLAG} -a -f ${RUN_FLAG}.qperf ]
	do
		sleep 3
	done
	# vm2 wait vm1 test ok
	if [ "$myip" = "$vm2" ]; then 
		#vm1 test ok then create file ${RUN_FLAG}.qperf.step1
		while [ ! -f ${RUN_FLAG}.qperf.step1 ] && [ -f ${RUN_FLAG} ]
		do
			sleep 10
		done 
	fi 
	#do test
	for i in $(seq $nr_iter)
	do 
		[ -f ${RUN_FLAG} ] || break
		qperf $reip -t 10 -oo msg_size:1:64K:*2 -vu sctp_lat tcp_lat udp_lat sctp_bw tcp_bw udp_bw 2>&1 | tee -a $logfile
	done 
	#vm1 wait vm2 test ok
	if [ "$myip" = "$vm1" ]; then 
		rm -rf ${RUN_FLAG}.qperf.step1
		touch ${RUN_FLAG}.qperf.step1
		ssh $SSH_OPT root@$reip "rm -rf ${RUN_FLAG}.qperf.step1; touch ${RUN_FLAG}.qperf.step1"
	else 
		rm -rf ${RUN_FLAG}.qperf.step2
		touch ${RUN_FLAG}.qperf.step2
		ssh $SSH_OPT root@$reip "rm -rf ${RUN_FLAG}.qperf.step2; touch ${RUN_FLAG}.qperf.step2"
	fi 
	#wait all test ok
	while [ -f ${RUN_FLAG} ]
	do
		if [ -f ${RUN_FLAG}.qperf.step1 -a -f ${RUN_FLAG}.qperf.step2 ]; then 
			rm -rf ${RUN_FLAG}.qperf.step1 ${RUN_FLAG}.qperf.step2
			kill -9 $(ps axf | grep -w qperf | grep -vw grep | awk '{print $1}') 
			break
		fi
		sleep 10
	done
	te=$(awk '{print $1}' /proc/uptime)
	tc=$(echo $ts $te | awk '{print $2 - $1}')
	echo  test qperf at $(date "+%Y/%m/%d %H:%M:%S") cost $tc seconds 2>&1 | tee -a $logfile
}

do_test()
{
	test_unixbench $NR_UNIXBENCH
	test_y_cruncher $NR_Y_CRUNCHER
	test_sysbench $NR_SYSBENCH
	
	test_qperf $NR_QPERF
}

main()
{
	if [ ! -f $TDIR/dist/compile.done ]; then 
		cd $TDIR/dist
		sh ./do_compile.sh $TDIR/dist/compile.done || return 1
	fi 
	rm -rf $RUN_FLAG ${RUN_FLAG}*
	touch $RUN_FLAG
	for p in NR_ITER LOG_PREFIX NR_UNIXBENCH NR_Y_CRUNCHER NR_SYSBENCH NR_QPERF NR_CPU RUN_FLAG SSH_OPT
	do 
		eval echo "$p=\$p"
	done 

	for i in $(seq $NR_ITER)
	do 
		do_test "$@"
	done 
}

main "$@" 2>&1 | tee -a $TDIR/all.test.log
