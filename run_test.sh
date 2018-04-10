#!/bin/sh

source frame_src/comm.func
source frame_src/global.var
source frame_src/init.func

main()
{
    #rm -rf $TEST_PKG
    #tar zcf $TEST_PKG dist || return 1
    setup_tmux_run "$@" || return 1
}

main "$@"
