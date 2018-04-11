#!/bin/bash
# $1 -- input logs dir
# $2 -- output result file

source frame_src/comm.func
source frame_src/parse_logs.func

main()
{
    local tmpdir=$(mktemp -d)
    local log_ub=

    if [ $(ls "$1" | grep unixbench.log | wc -l) -ne 1 ]; then 
        msg_err "unixbench log file not ok"
        return 1
    else 
        log_ub="$1"/$(ls "$1" | grep unixbench.log)
        parse_unixbench $log_ub "$tmpdir/unixbench"
    fi 

    if [ $(ls "$1" | grep y-cruncher.log | wc -l) -ne 1 ]; then 
        msg_err "y-cruncher log file not ok"
        return 1
    else 
        log_ub="$1"/$(ls "$1" | grep y-cruncher.log)
        parse_y_cruncher $log_ub "$tmpdir/y-cruncher"
    fi 

    echo $tmpdir
    #rm -rf $tmpdir
}

main "$@"
