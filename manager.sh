#!/bin/bash
# $1 -- WORK_DIR的绝对路径
# $2 -- 期望同时多少个VM一起跑测试，默认都跑

source frame_src/comm.func

main()
{
    [ -d $1 ] || return 1

    local test_count=0
    local vmlist=$(sed "s|#.*||g" $1/vm-list | tr '\n' ' ')
    local tmpdir=$(grep "^TMP_DIR=" $1/env | awk -F = '{print $2}')
    mkdir -p $tmpdir
    #多少个待测试的VM
    local nr_vm=0

    rm -rf $1/real-list
    for vip in $vmlist
    do
        echo $vip >> $1/real-list
        nr_vm=$(( nr_vm + 1 ))
    done

    #设置多少个VM一起跑测试
    local nr_set=$nr_vm
    if [ -n "$2" ]; then
        [ "$2" -ge 1 -a "$2" -lt $nr_vm ] && nr_set=$2
    fi
    #正在跑测试的VM数
    local nr_run=0
    #跳着挑选虚拟机执行测试
    local jump_step=2
    local jump_skip=0
    local vm_seek=1
    local xip=

    msg_show "vmlist=$vmlist"
    msg_show "tmpdir=$tmpdir"

    #主循环
    while true
    do
        for vip in $vmlist
        do
            [ -f $tmpdir/run-end-flag.$vip ] && { rm -rf $tmpdir/run-start-flag.$vip $tmpdir/run-end-flag.$vip $tmpdir/run-start-flag.${vip}.cnt; }
        done
        nr_s=$(ls $tmpdir | grep "run-start-flag" | wc -l)
        nr_e=$(ls $tmpdir | grep "run-end-flag" | wc -l)
        nr_run=$(( nr_s - nr_e ))
        [ $nr_set -le $nr_run ] && { sleep 5; continue; }
        for i in $vmlist
        do
            [ $vm_seek -gt $nr_vm ] && vm_seek=1
            xip=$(sed -n "$vm_seek p" $1/real-list)
            vm_seek=$(( vm_seek + 1 ))
            [ -f $tmpdir/run-start-flag.$xip ] || break
        done
        jump_skip=$(( jump_skip + 1 ))
        jump_skip=$(( jump_skip % jump_step ))
        vm_seek=$(( vm_seek + jump_skip ))
        #错开下位置，避免老是固定的几个VM跑测试
        test_count=$(( test_count + 1 ))
        msg_warn "[$test_count] xip=$xip now setup the test flag"
        ssh $SSH_OPT root@$xip "touch $tmpdir/do_test.ring.flag"
        sleep 5
    done
}

main "$@"
