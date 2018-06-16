#!/bin/bash

: '
 *  run_rack: run a single T-RACKs experiments either using one-to-all or all-to-all communication pattern
 *            with a given range of values for the T-RACKs RTO timer and the elephant threshold
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
racktmin=${14}
racktmax=${15}
rackackmin=${16}
rackackmax=${17}



kill -9 `ps aux | grep run_all | awk '{print $2}'`
kill -9 `ps -ef | grep defunct | awk '{print $2" "$3}'`

if [ "$sinter" == "" ]; then
    sinter=0;
fi

if [ "$ssize" == "" ]; then
    ssize=0;
fi

seed=123456 #`date +%s`
timenow=`date +"%Y-%m-%d"`

#rep1=$(( ($racktmax - $racktmin) / 5 ));
rep1=$(( $racktmax / 5 ));
rep2=$(( $rackackmax/ rackackmin ));

echo $rep1 $rep2
i=2;
j=1;
while [ $i -le $rep1 ];
do
#for i in {0..$rep1};
#do
    #for j in { 0..$rep2 };
    #do
    while [ $j -le $rep2 ];
    do
        t=$(( $racktmin + ($i * 5) ));
        ack=$(( $rackackmin * $j ));

        echo "i:$i j:$j"
        echo "interval:$t maxack:$ack"

        #if [[ $ack  $rackackmax || $t > $racktmax ]]; then
        #    break;
        #fi

        ### RANDOM retruns in range 0-32767
        #rackt=$(($RANDOM % $racktmax));
        #while [ $rackt -lt 1 ]; do
        #        rackt=$(($RANDOM % $racktmax));
        #done

        #rackmaxack=$((rackmaxack * 10));
        ###################### RACK ###########################
        sleep 1
        #if [ "$jobnum" != 0 ]; then
        rm *.log;

		if [ "$onetoall" == "one" ]; then
        	echo "python bin/run_all_to_one.py -i $job -n $num -c conf/$conffile -b $load -a $master -m $method -w $workers -k $persist -l $lossprobe -s $seed -B $backg -D $drop -I 0 -r 1 -T $t -M $ack -SI $sinter -SS $ssize" > cmd.log
			dsh -c -g cluster 'sudo killall -9 client; sudo killall -9 server; sudo killall -9 cat; sudo rmmod -f loss_probe;  sudo killall -9 tcpdump;  sudo killall -9 dstat; for i in `pgrep iperf`; do kill -9 $i; done;'
			python bin/run_all_to_one.py -i $job -n $num -c conf/$conffile -b $load -a $master -m $method -w $workers -k $persist -l $lossprobe -s $seed -B $backg -D $drop -I 0 -r 1 -T $t -M $ack -SI $sinter -SS $ssize; # 2>&1 | tee run.log;
		elif [ "$onetoall" == "all" ]; then
		    echo "python bin/run_all_to_all.py -i $job -n $num -c conf/$conffile -b $load -a $master -m $method -w $workers -k $persist -l $lossprobe -s $seed -B $backg -D $drop -I 0 -r 1 -T $t -M $ack -SI $sinter -SS $ssize" > cmd.log
			dsh -c -g cluster 'sudo killall -9 client; sudo killall -9 server; sudo killall -9 cat; sudo rmmod -f loss_probe;  sudo killall -9 tcpdump;  sudo killall -9 dstat; for i in `pgrep iperf`; do kill -9 $i; done;'
			python bin/run_all_to_all.py -i $job -n $num -c conf/$conffile -b $load -a $master -m $method -w $workers -k $persist -l $lossprobe -s $seed -B $backg -D $drop -I 0 -r 1 -T $t -M $ack -SI $sinter -SS $ssize; # 2>&1 | tee run.log;
		else
			echo "invalid input of the communication pattern, please enter either one for one-to-all or all for all-to-all"
		fi			
        mv *.log ./result/$timenow/job_$job/

        job=$(($job+1))
        #fi
        j=$(($j * 10));
    done
    i=$(($i + 1));
done

