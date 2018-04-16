#!/bin/bash
# $1 -- input logs dir
# $2 -- output result file

source frame_src/comm.func
source frame_src/parse_logs.func

# $1 -- one target log dir
# $2 -- output result file
parse_one()
{
    [ -d "$1" ] || { msg_err "[$1] not dir"; return 1; }
    [ -w "$2" ] || { msg_err "file [$2] can't write"; return 1; }
    local tmpdir=$(mktemp -d)
    local tmpfile=
    local onename=$(basename $1)
    local spec=
    local ostype=
    local nrtmp=0
    local funcname=

    if [ -f "$1/../../../../vm-list" ]; then
        spec=$(grep -w "$onename" "$1/../../../../vm-list" | awk '{print $(NF-1)}')
        ostype=$(grep -w "$onename" "$1/../../../../vm-list" | awk '{print $(NF)}')
    fi
    for item in main unixbench y-cruncher sysbench qperf
    do
        funcname=$(echo parse_${item} | tr '-' '_')
        nrtmp=$(ls "$1" | grep ${item}.log | wc -l)
        if [ $nrtmp -ne 1 ]; then
            msg_err "$item log file in $1 not ok, nrtmp=$nrtmp"
            ls -al $1
            continue
        fi

        tmpfile="$1"/$(ls "$1" | grep ${item}.log)
        eval $funcname $tmpfile $tmpdir/$item || continue
        if [ -n "$spec" -a -n "$ostype" ]; then
            sed -i "s|^|$item $onename $spec $ostype |g" $tmpdir/$item
        else
            sed -i "s|^|$item $onename |g" $tmpdir/$item
        fi
        cat $tmpdir/$item >> $2
    done
    return 0
}

# $1 -- logs dir
# $2 -- output result file
main()
{
    [ -d "$1" ] || { msg_err "dir [$1] not exist"; return 1; }
    touch "$2" || { msg_err "create file [$2] fail"; return 1; }
    local one_list=$(ls "$1")

    for xone in $one_list
    do
        parse_one "$1/$xone" "$2" || return 1
    done
    sed -i "s|[[:blank:]]\+$||g" "$2"
    sed -i "s|[[:blank:]]\+|\t|g" "$2"
    return 0
}

main "$@"
