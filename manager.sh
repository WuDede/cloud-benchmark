#!/bin/bash
# $1 -- WORK_DIR的绝对路径
# $2 -- 期望同时多少个VM一起跑测试，默认都跑

source frame_src/comm.func

main()
{
    [ -d $1 ] || return 1

    local vmlist=$(grep -v "^[[:blank:]]*#" $1/vm-list)
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
    [ -n "$2" -a "$2" -ge 1 -a "$2" -lt $nr_vm ] && nr_set=$2
    #正在跑测试的VM数
    local nr_run=0
    #跳着挑选虚拟机执行测试
    local jump_step=2
    local jump_flag=0
    local vm_seek=1
    local xip=

    #主循环
    while true
    do
        #轮询一次
        for vip in $vmlist
        do
            [ -f $tmpdir/run-start-flag.$vip ] && $(( nr_run + 1 ))
            [ -f $tmpdir/run-end-flag.$vip ] && { rm -rf $tmpdir/run-start-flag.$vip $tmpdir/run-end-flag.$vip; $(( nr_run - 1 )); }
        done
        [ $nr_set -eq $nr_run ] && { sleep 5; continue; }
        [ $nr_set -lt $nr_run ] && { msg_err "nr_set=$nr_set nr_run=$nr_run, please check"; return 1; }
        #把少的几个测试拉起来
        for i in $(seq $(( nr_set - nr_run )))
        do
            #挑选一个么有跑测试的VM
            for j in $(seq $nr_vm)
            do
                [ $vm_seek -gt $nr_vm ] && vm_seek=1
                xip=$(sed -n "$vm_seek p" $1/real-list)
                vm_seek=$(( vm_seek + 1 ))
                [ -f $tmpdir/run-start-flag.$xip ] && continue
                jump_flag=$(( jump_flag + 1 ))
                #跳过jump_step个没有跑测试的VM之后，确定本次要跑的xip
                [ $(( jump_flag % jump_step )) -eq 0 ] && break
            done
            msg_warn "xip=$xip now setup the test flag"
            ssh $SSH_OPT root@$xip "touch $tmpdir/do_test.ring.flag"
        done
        sleep 5
    done
}

main "$@"
