#!/bin/bash

for i in `seq 1 10`
do
    nc 192.168.2.1 3128
    if [ $? == 0 ] ; then
        exit 0
    else
        sleep 1
    fi
done    

sleep 20