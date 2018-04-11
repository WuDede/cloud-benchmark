#!/bin/bash

source frame_src/comm.func

main()
{
    local stop_flag=false
    local glog_flag=false
    for ac in $(seq $#)
    do
        case $1 in 
            stop)
                stop_flag=true
                shift
                ;;
            glog)
                glog_flag=true
                shift
                ;;
            *)
                break
                ;;
        esac 
    done 

    [ -d "$1" -a -f "$1/vm-list" ] || return 2
    local xiplist=$(grep -v "[[:blank:]]*#" $1/vm-list)
    local tmpdir=$(grep -w TMP_DIR $1/env | awk -F = '{print $2}')
    local loglist=""
    local logdir="$1/log/result/$(date +%Y-%m-%d-%H-%M-%S)"
    local kpid=""
    for xip in $xiplist
    do
        msg_show "now $xip"
        if [ $stop_flag = true ]; then 
            msg_warn "now rm -rf the file $tmpdir/perf.run.flag in $xip to stop the test"
            sshx $xip "test -f $tmpdir/perf.run.flag && rm -rf $tmpdir/perf.run.flag"
            kpid=$(sshx $xip "ps axfww | grep dist/test.sh | grep -vw grep" | awk '{print $1}')
            [ -n "$kpid" ] && sshx $xip kill -9 $kpid
            kpid=$(sshx $xip "ps axfww | grep -w Run | grep -vw grep" | awk '{print $1}')
            [ -n "$kpid" ] && sshx $xip kill -9 $kpid
            kpid=$(sshx $xip "ps axfww | grep -w qperf | grep -vw grep" | awk '{print $1}')
            [ -n "$kpid" ] && sshx $xip kill -9 $kpid
            kpid=$(sshx $xip "ps axfww | grep -w perf.run.flag | grep -vw grep" | awk '{print $1}')
            [ -n "$kpid" ] && sshx $xip kill -9 $kpid
            kpid=$(sshx $xip "ps axfww | grep -w perf-tmp | grep -vw grep" | awk '{print $1}')
            [ -n "$kpid" ] && sshx $xip kill -9 $kpid
            sshx $xip ps axf 
        fi
        if [ $glog_flag = true ]; then 
            msg_warn "now get logs from $xip:$tmpdir/result.*.log"
            mkdir -p $logdir/$xip
            loglist=$(sshy $xip ls $tmpdir/result.* 2>/dev/null | tr '\n' ' ')
            scpf $xip $loglist $logdir/$xip || return 1
        fi
        msg_warn "all logs save at $logdir"
    done 
}

main "$@"
