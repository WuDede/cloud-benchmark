#!/bin/sh
# $1 -- 期望同时多少个VM一起跑测试，默认都跑

source frame_src/comm.func
source frame_src/global.var
source frame_src/init.func

main()
{
    rm -rf $TEST_PKG
    tar zcf $TEST_PKG dist || return 1
    setup_tmux_run "$@" || return 1
}

main "$@"
