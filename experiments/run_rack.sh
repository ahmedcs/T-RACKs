#!/bin/bash

: '
 *  run_rack: run a single T-RACKs experiments either using one-to-all or all-to-all communication pattern
 *  Author: Ahmed Mohamed Abdelmoniem Sayed, <ahmedcs982@gmail.com, github:ahmedcs>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of CRAPL LICENCE avaliable at
 *    http://matt.might.net/articles/crapl/.
 *    http://matt.might.net/articles/crapl/CRAPL-LICENSE.txt
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *  See the CRAPL LICENSE for more details.
 *
 * Please READ carefully the attached README and LICENCE file with this software
'

onetoall=$1
job=$2
jobnum=$3
load=$4
num=$5
conffile=$6
master=$7
method=$8
persist=$9
workers=$10
lossprobe=${11}
drop=${12}
backg=${13}
rackt=${14}
rackack=${15}



kill -9 `ps aux | grep run_all | awk '{print $2}'`
kill -9 `ps -ef | grep defunct | awk '{print $2" "$3}'`

if [ "$sinter" == "" ]; then
    sinter=0;
fi

if [ "$ssize" == "" ]; then
    ssize=0;
fi

seed=123456
timenow=`date +"%Y-%m-%d"`

dsh -c -g cluster 'sudo killall -9 client; sudo killall -9 server; sudo killall -9 cat; sudo rmmod -f loss_probe;  sudo killall -9 tcpdump;  sudo killall -9 dstat; for i in `pgrep iperf`; do kill -9 $i; done;'

if [ "$onetoall" == "1" ]; then
	echo "python bin/run_all_to_one.py -i $job -n $num -c conf/$conffile -b $load -a $master -m $method -w $workers -k $persist -l $lossprobe -s $seed -B $backg -D $drop -I 0 -r 1 -T $rackt -M $rackack -SI $sinter -SS $ssize" > cmd.log
	python bin/run_all_to_one.py -i $job -n $num -c conf/$conffile -b $load -a $master -m $method -w $workers -k $persist -l $lossprobe -s $seed -B $backg -D $drop -I 0 -r 1 -T $rackt -M $rackack -SI $sinter -SS $ssize; # 2>&1 | tee run.log;
else
	echo "python bin/run_all_to_all.py -i $job -n $num -c conf/$conffile -b $load -a $master -m $method -w $workers -k $persist -l $lossprobe -s $seed -B $backg -D $drop -I 0 -r 1 -T $racktt -M $rackack -SI $sinter -SS $ssize" > cmd.log
	python bin/run_all_to_all.py -i $job -n $num -c conf/$conffile -b $load -a $master -m $method -w $workers -k $persist -l $lossprobe -s $seed -B $backg -D $drop -I 0 -r 1 -T $rackt -M $rackack -SI $sinter -SS $ssize; # 2>&1 | tee run.log;
fi

mv *.log ./result/$timenow/job_$job/


