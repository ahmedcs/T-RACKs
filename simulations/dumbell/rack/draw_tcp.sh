#!/bin/sh

: '
 * tcp_draw: draw all tcp state related metrics such seqno, cwnd, etc
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

mkdir tcp
N=$(($1-1));
echo "executing gnuplot for the Mice throughput file"

for i in `seq 0 $N`
do
gnuplot -persist << EOF
reset
set title "TCP seqno"
set xlabel "Simulation Time (s)"
set ylabel "seqno"
set terminal png
set output "tcp/seqno-$i.png"
plot "tcptracefile-$i.tr" using 1:2 notitle with lines; #lp
EOF
done

for i in `seq 0 $N`
do
gnuplot -persist << EOF
reset
set title "TCP CWND"
set xlabel "Simulation Time (s)"
set ylabel "cwnd"
set terminal png
set output "tcp/cwnd-$i.png"
plot "tcptracefile-$i.tr" using 1:3 notitle with lines; #lp
EOF
done

for i in `seq 0 $N`
do
gnuplot -persist << EOF
reset
set title "TCP RTT"
set xlabel "Simulation Time (s)"
set ylabel "RTT"
set terminal png
set output "tcp/rtt-$i.png"
plot "tcptracefile-$i.tr" using 1:5 notitle with lines; #lp
EOF
done

for i in `seq 0 $N`
do
gnuplot -persist << EOF
reset
set title "TCP Restransmit"
set xlabel "Simulation Time (s)"
set ylabel "Restransmit no."
set terminal png
set output "tcp/retransmit-$i.png"
plot "tcptracefile-$i.tr" using 1:7 notitle with lines; #lp
EOF
done


for i in `seq 0 $N`
do
gnuplot -persist << EOF
reset
set title "TCP backoff"
set xlabel "Simulation Time (s)"
set ylabel "backoff time "
set terminal png
set output "tcp/backoff-$i.png"
plot "tcptracefile-$i.tr" using 1:6 notitle with lines; #lp
EOF
done


for i in `seq 0 $N`
do
gnuplot -persist << EOF
reset
set title "TCP CWND cuts"
set xlabel "Simulation Time (s)"
set ylabel "CWND cut no."
set terminal png
set output "tcp/cwndcut-$i.png"
plot "tcptracefile-$i.tr" using 1:8 notitle with lines; #lp
EOF
done
