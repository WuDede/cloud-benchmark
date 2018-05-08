#!/bin/sh
# $1 -- tmpdir
# $2 -- host WORK_DIR

MANAGER_IP=192.168.1.60
MY_IP=$(/sbin/ifconfig | grep 192.168 | sed "s|.*\(192.168\.[0-9]\+\.[0-9]\+\).*netmask.*|\1|g")
TDIR=$1
NR_ITER=20
LOG_PREFIX=$$
NR_CPU=$(cat /proc/cpuinfo | grep -i processor | wc -l)
RUN_FLAG=$TDIR/perf.run.flag
SSH_OPT="-o ServerAliveInterval=5 -o ServerAliveCountMax=2 -o StrictHostKeyChecking=no -o ConnectTimeout=5"

test_unixbench()
{
    local nr_iter=1
    [ -n "$1" ] && nr_iter=$1
    local logfile=$TDIR/result.${LOG_PREFIX}.unixbench.log
    local ts=
    local te=
    local tc=
    cd $TDIR/dist/unixbench-5.1.2
    for i in $(seq $nr_iter)
    do
        [ -f $RUN_FLAG ] || return
        ts=$(awk '{print $1}' /proc/uptime)
        echo "START_EOS_PERF_TEST UnixBench $i" | tee -a $logfile
        echo "./Run -q -c $NR_CPU -i 1 system"
        ./Run -q -c $NR_CPU -i 1 system 2>&1 | tee -a $logfile
        te=$(awk '{print $1}' /proc/uptime)
        tc=$(echo $ts $te | awk '{print $2 - $1}')
        echo TIME_COST unixbench test at $(date "+%Y/%m/%d-%H:%M:%S") cost $tc seconds 2>&1 | tee -a $logfile
        echo "END_EOS_PERF_TEST UnixBench $i" | tee -a $logfile
        sleep 3
    done
}

test_y_cruncher()
{
    local nr_iter=1
    [ -n "$1" ] && nr_iter=$1
    local logfile=$TDIR/result.${LOG_PREFIX}.y-cruncher.log
    local ts=
    local te=
    local tc=
    cd $TDIR/dist/y-cruncher_v0.7.5.9481-static

    local pi_bit=64M
    if [ $NR_CPU -eq 1 ]; then
        pi_bit=64M
    elif [ $NR_CPU -gt 1 -a $NR_CPU -le 4 ]; then
        pi_bit=256M
    elif [ $NR_CPU -gt 4 -a $NR_CPU -le 8 ]; then
        pi_bit=512M
    elif [ $NR_CPU -gt 8 -a $NR_CPU -le 12 ]; then
        pi_bit=512M
    elif [ $NR_CPU -gt 12 -a $NR_CPU -le 16 ]; then
        pi_bit=512M
    elif [ $NR_CPU -gt 16 -a $NR_CPU -le 20 ]; then
        pi_bit=1G
    elif [ $NR_CPU -gt 20 -a $NR_CPU -le 24 ]; then
        pi_bit=1G
    elif [ $NR_CPU -gt 24 -a $NR_CPU -le 28 ]; then
        pi_bit=2G
    elif [ $NR_CPU -gt 28 -a $NR_CPU -le 32 ]; then
        pi_bit=2G
    elif [ $NR_CPU -gt 32 ]; then
        pi_bit=4G
    fi

    for i in $(seq $nr_iter)
    do
        [ -f $RUN_FLAG ] || return
        ts=$(awk '{print $1}' /proc/uptime)
        echo "START_EOS_PERF_TEST y-cruncher $i" | tee -a $logfile
        echo "./y-cruncher skip-warnings bench $pi_bit" 2>&1 | tee -a $logfile
        ./y-cruncher skip-warnings bench $pi_bit 2>&1 | tee -a $logfile
        te=$(awk '{print $1}' /proc/uptime)
        tc=$(echo $ts $te | awk '{print $2 - $1}')
        echo  TIME_COST test y-cruncher at $(date "+%Y/%m/%d-%H:%M:%S") cost $tc seconds 2>&1 | tee -a $logfile
        echo "END_EOS_PERF_TEST y-cruncher $i" | tee -a $logfile
        sleep 3
    done
}

test_sysbench_fileio()
{
    local timeout=30
    local blksize=4096
    ./sysbench --time=$timeout fileio --file-block-size=$blksize --file-test-mode=$1 prepare 1>&2
    echo -n "FILEIO ./sysbench --time=$timeout fileio --file-block-size=$blksize --file-test-mode=$1 run "
    ./sysbench --time=$timeout fileio --file-block-size=$blksize --file-test-mode=$1 run 2>&1 | grep "read, MiB\|written, MiB" | tr '\n' ' ' | sed "s|[[:blank:]]\+| |g"
    echo ""
    ./sysbench --time=$timeout fileio --file-block-size=$blksize --file-test-mode=$1 cleanup 1>&2
}

test_sysbench_memory()
{
    local timeout=30
    local blksize=$1
    local oper=$2
    local mode=$3
    echo -n "MEMORY ./sysbench --time=$timeout --threads=$NR_CPU --memory-block-size=$blksize memory --memory-total-size=4096G --memory-oper=$oper --memory-access-mode=$mode run "
    ./sysbench --time=$timeout --threads=$NR_CPU --memory-block-size=$blksize memory --memory-total-size=4096G --memory-oper=$oper --memory-access-mode=$mode run 2>&1 | grep "MiB transferred"
}

test_sysbench()
{
    local nr_iter=1
    [ -n "$1" ] && nr_iter=$1
    local logfile=$TDIR/result.${LOG_PREFIX}.sysbench.log
    local ts=
    local te=
    local tc=
    cd $TDIR/dist/sysbench-1.0.14/testbin/bin
    for i in $(seq $nr_iter)
    do
        [ -f $RUN_FLAG ] || return
        ts=$(awk '{print $1}' /proc/uptime)
        echo "START_EOS_PERF_TEST sysbench $i" | tee -a $logfile

        echo "start do sysbench test" | tee -a $logfile
        for fileop in seqwr seqrd rndwr rndrd
        do
            test_sysbench_fileio $fileop | tee -a $logfile
        done

        echo -n "CPU ./sysbench --time=30 --threads=$NR_CPU cpu run " 2>&1 | tee -a $logfile
        ./sysbench --time=30 --threads=$NR_CPU cpu run 2>&1 | grep "events per second:" 2>&1 | tee -a $logfile

        test_sysbench_memory 8 read seq | tee -a $logfile
        test_sysbench_memory 8 write seq | tee -a $logfile
        test_sysbench_memory 8 read rnd | tee -a $logfile
        test_sysbench_memory 8 write rnd | tee -a $logfile
        test_sysbench_memory 1K read seq | tee -a $logfile
        test_sysbench_memory 1K write seq | tee -a $logfile
        test_sysbench_memory 1K read rnd | tee -a $logfile
        test_sysbench_memory 1K write rnd | tee -a $logfile

        for trd_times in 1 2 4 8 16 32 64 128 256
        do
            echo -n "THREADS ./sysbench --time=30 --threads=$(( NR_CPU * trd_times )) threads run " 2>&1 | tee -a $logfile
            ./sysbench --time=30 --threads=$(( NR_CPU * trd_times )) threads run 2>&1 | grep "total number of events:" 2>&1 | tee -a $logfile
        done

        te=$(awk '{print $1}' /proc/uptime)
        tc=$(echo $ts $te | awk '{print $2 - $1}')
        echo  TIME_COST test sysbench at $(date "+%Y/%m/%d-%H:%M:%S") cost $tc seconds 2>&1 | tee -a $logfile
        echo "END_EOS_PERF_TEST sysbench $i" | tee -a $logfile
        sleep 3
    done
}

test_qperf()
{
    local nr_iter=1
    [ -n "$1" ] && nr_iter=$1
    local logfile=$TDIR/result.${LOG_PREFIX}.qperf.log
    local ts=
    local te=
    local tc=
    [ -n "$1" ] && nr_iter=$1

    for i in $(seq $nr_iter)
    do
        [ -f $RUN_FLAG ] || return
        ts=$(awk '{print $1}' /proc/uptime)
        echo "START_EOS_PERF_TEST qperf $i" | tee -a $logfile

        #in vm-list has vm1 vm2
        local qport=19765
        local server_pid=
        local myip=$(/sbin/ifconfig | grep 192.168 | sed "s|.*\(192.168\.[0-9]\+\.[0-9]\+\).*netmask.*|\1|g")
        local vm1=$(sed "s|#.*||g" $TDIR/dist/vm-list | grep -w "${myip}" | tail -n 1 | awk '{print $1}')
        local vm2=$(sed "s|#.*||g" $TDIR/dist/vm-list | grep -w "${myip}" | tail -n 1 | awk '{print $2}')
        local reip=$([ "$myip" = "$vm1" ] && echo $vm2 || echo $vm1)
        echo "myip=$myip reip=$reip vm1=$vm1 vm2=$vm2" | tee -a $logfile
        [ -z "$myip" -o -z "$vm1" -o -z "$vm2" -o -z "$reip" ] && return 1

        #固定vm1和vm2的端口号，vm1使用19763，vm2使用19764
        if [ $myip = $vm1 ]; then
            qport=19763
        else
            qport=19764
        fi
        #启动对端vm的服务
        echo "my ip is $myip , now start $reip qperf server with port $qport"
        ssh $SSH_OPT root@$reip "qperf --listen_port $qport > /dev/null 2>&1 &"
        server_pid=$(ssh $SSH_OPT root@$reip "ps axfww" | grep -vw grep | grep -w "qperf --listen_port $qport" | awk '{print $1}')
        [ -z "$server_pid" ] && { echo "server pid error"; return 1; }

        #do test
        for i in $(seq $nr_iter)
        do
            [ -f ${RUN_FLAG} ] || break
            #udp_bw may cause connect fail, remove it
            #echo "do test [qperf $reip --listen_port $qport -oo msg_size:1:64K:*2 -vu sctp_lat tcp_lat udp_lat sctp_bw tcp_bw]"
            #qperf $reip --listen_port $qport -oo msg_size:1:64K:*2 -vu sctp_lat tcp_lat udp_lat sctp_bw tcp_bw 2>&1 | tee -a $logfile
            echo "do test [qperf $reip --listen_port $qport -oo msg_size:1:64K:*2 -vu tcp_lat udp_lat tcp_bw]"
            qperf $reip --listen_port $qport -oo msg_size:1:64K:*2 -vu tcp_lat udp_lat tcp_bw 2>&1 | tee -a $logfile
        done

        te=$(awk '{print $1}' /proc/uptime)
        tc=$(echo $ts $te | awk '{print $2 - $1}')
        echo TIME_COST test qperf at $(date "+%Y/%m/%d-%H:%M:%S") cost $tc seconds 2>&1 | tee -a $logfile
        echo "END_EOS_PERF_TEST qperf $i" | tee -a $logfile
    done
}

test_stream()
{
    local nr_iter=1
    [ -n "$1" ] && nr_iter=$1
    local logfile=$TDIR/result.${LOG_PREFIX}.stream.log
    local ts=
    local te=
    local tc=
    cd $TDIR/dist/stream
    for i in $(seq $nr_iter)
    do
        [ -f $RUN_FLAG ] || return
        ts=$(awk '{print $1}' /proc/uptime)
        echo "START_EOS_PERF_TEST stream $i" | tee -a $logfile
        echo "export OMP_NUM_THREADS=1 && ./stream"
        export OMP_NUM_THREADS=1 && ./stream 2>&1 | tee -a $logfile
        te=$(awk '{print $1}' /proc/uptime)
        tc=$(echo $ts $te | awk '{print $2 - $1}')
        echo TIME_COST stream test at $(date "+%Y/%m/%d-%H:%M:%S") cost $tc seconds 2>&1 | tee -a $logfile
        echo "END_EOS_PERF_TEST stream $i" | tee -a $logfile
        sleep 3
    done
}

test_geekbench()
{
    local nr_iter=1
    [ -n "$1" ] && nr_iter=$1
    local logfile=$TDIR/result.${LOG_PREFIX}.geekbench.log
    local ts=
    local te=
    local tc=
    cd $TDIR/dist/Geekbench-3.4.1-Linux
    for i in $(seq $nr_iter)
    do
        [ -f $RUN_FLAG ] || return
        ts=$(awk '{print $1}' /proc/uptime)
        echo "START_EOS_PERF_TEST geekbench $i" | tee -a $logfile
        echo "./geekbench_x86_64 --no-upload --benchmark"
        ./geekbench_x86_64 --no-upload --benchmark 2>&1 | tee -a $logfile
        te=$(awk '{print $1}' /proc/uptime)
        tc=$(echo $ts $te | awk '{print $2 - $1}')
        echo TIME_COST stream test at $(date "+%Y/%m/%d-%H:%M:%S") cost $tc seconds 2>&1 | tee -a $logfile
        echo "END_EOS_PERF_TEST geekbench $i" | tee -a $logfile
        sleep 3
    done
}

test_pts()
{
    local nr_iter=1
    [ -n "$1" ] && nr_iter=$1
    local logfile=$TDIR/result.${LOG_PREFIX}.pts.log
    local ts=
    local te=
    local tc=
    cd $TDIR/dist/pts-support
    local prefix_name="$(basename $TDIR | tr 'A-Z' 'a-z')"
    local identify=""
    local options=""
    local testitems=""
    for i in $(seq $nr_iter)
    do
        [ -f $RUN_FLAG ] || return
        ts=$(awk '{print $1}' /proc/uptime)
        echo "START_EOS_PERF_TEST PTS $i" | tee -a $logfile

        identify=$(date +%Y%m%d-%H%M%S)
        while read tests opts
        do
            options="${opts};$options"
            testitems="${testitems} $tests"
        done < ./pts-test-list
        echo TEST_RESULTS_NAME="${prefix_name}-${i}" TEST_RESULTS_IDENTIFIER="${prefix_name}-${i}-identifier-${identify}" TEST_RESULTS_DESCRIPTION="${prefix_name}-${i}-description-${identify}" PRESET_OPTIONS=\""$options"\" phoronix-test-suite internal-run $testitems | tee -a $logfile
        TEST_RESULTS_NAME="${prefix_name}-${i}" TEST_RESULTS_IDENTIFIER="${prefix_name}-${i}-identifier-${identify}" TEST_RESULTS_DESCRIPTION="${prefix_name}-${i}-description-${identify}" PRESET_OPTIONS="$options" phoronix-test-suite internal-run $testitems 2>&1 | tee -a $logfile
        phoronix-test-suite result-file-to-csv "${prefix_name}-${i}" > $TDIR/result.${LOG_PREFIX}.pts.${identify}.csv

        te=$(awk '{print $1}' /proc/uptime)
        tc=$(echo $ts $te | awk '{print $2 - $1}')
        echo TIME_COST stream test at $(date "+%Y/%m/%d-%H:%M:%S") cost $tc seconds 2>&1 | tee -a $logfile
        echo "END_EOS_PERF_TEST stream $i" | tee -a $logfile
        sleep 3
    done
}

do_test()
{
    #等待测试的标志文件，该文件存在，则表示测试可以进行，否则等待
    #echo "=======[waiting $TDIR/do_test.ring.flag]======="
    #while [ -f $RUN_FLAG ]
    #do
    #    [ -f $TDIR/do_test.ring.flag ] && break
    #    sleep 5
    #done
    #ssh $SSH_OPT dede@$MANAGER_IP "touch $TDIR/run-start-flag.$MY_IP" || return 1
    #echo "got $TDIR/do_test.ring.flag, let's go"

    #test_unixbench 1
    #test_y_cruncher 1
    #test_sysbench 1
    #test_stream 1
    #test_geekbench 1
    test_pts 1
    #test_qperf 1

    #测试完成，删除文件，同时设置管理机上的标志文件
    #rm -rf $TDIR/do_test.ring.flag
    #ssh $SSH_OPT dede@$MANAGER_IP "touch $TDIR/run-end-flag.$MY_IP" || return 1
    return 0
}

main()
{
    local logfile=$TDIR/result.${LOG_PREFIX}.main.log
    for rlsfile in $(ls /etc | grep -i release)
    do
        echo "FILE ---------> $rlsfile" | tee -a $logfile
        [ -r "/etc/$rlsfile" ] && cat "/etc/$rlsfile" | tee -a $logfile
    done
    uname -a | tee -a $logfile

    #try compile tools
    if [ ! -f $TDIR/dist/compile.done ]; then
        cd $TDIR/dist
        sh ./do_compile.sh $TDIR/dist/compile.done || return 1
    fi
    rm -rf $RUN_FLAG ${RUN_FLAG}*
    touch $RUN_FLAG
    for p in NR_ITER LOG_PREFIX NR_CPU RUN_FLAG SSH_OPT
    do
        eval echo "$p=\$$p"
    done

    for i in $(seq $NR_ITER)
    do
        [ -f $RUN_FLAG ] || break
        echo "===================================================="
        echo "                        $i "
        echo "===================================================="
        do_test "$@" || return 1
    done
    echo "TEST COMPLETE, UPLOAD RESULTS"
    ssh $SSH_OPT dede@$MANAGER_IP "mkdir -p $2/log/result/upload/$MY_IP"
    scp $SSH_OPT $TDIR/result.* dede@$MANAGER_IP:$2/log/result/upload/$MY_IP
    echo "TEST END, NOW SHUTDOWN THE MACHINE !!!!!!!!!!!!!"
    shutdown -P 0
    return 0
}

main "$@" 2>&1 | tee -a $TDIR/all.test.log
