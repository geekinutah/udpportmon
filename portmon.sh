#!/bin/bash

###############################################################################
# Purpose of this script is to watch for UDP ports that are in a "listening"  #
# state (accepting incoming packets). When a UDP port enters or leaves this   #
# state, an event should be generated. This is dispatched in the form of a    #
# blocking call to all executables in two user-defined directories. The       #
# parameters to these executables will be a list of ports opened or closed.   #
###############################################################################

###CONFIG VARS###
OPEN_DIR='./open.d/'
CLOSE_DIR='./close.d/'
##/CONFIG VARS###

FILE=$(mktemp)
ports=''
 
function notify {
    files=( $(find $1 -executable -type f | sort) )
    shift
    for f in $files; do
        $f $@
    done;
}
 
function notify_open {
    notify $OPEN_DIR $@
}
 
function notify_close {
    notify $CLOSE_DIR $@
}
 
while [ 1 -eq 1 ]; do
    ports=$(ss -nul | sed -n '1!p' | awk '{print $4}' | sed 's .*:  g' | sort -nu)

    if [ ! -s $FILE ]; then
        echo $ports | sed 's/ /\n/g' > $FILE
        temp=$(echo $ports | xargs)
        notify_open $temp
        sleep 1
        continue;
    fi

    $(echo $ports | sed 's/ /\n/g' | diff -q $FILE - > /dev/null)

    if [ $? -eq 1 ]; then

        closed=$(echo $ports | sed 's/ /\n/g' | diff $FILE - | grep '<' | sed 's <  g' | xargs)
        
        opened=$(echo $ports | sed 's/ /\n/g' | diff $FILE - | grep '>' | sed 's >  g' | xargs)

        if [ !  -z  $closed ]; then
            notify_close $closed;
        fi

        if [ !  -z  $opened ]; then
            notify_open $opened;
        fi
        echo $ports | sed 's/ /\n/g' > $FILE
    fi
    sleep 1
done
