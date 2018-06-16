#!/bin/sh

: '
 * int_goodput: draw all the instantaneous goodput of the elephant flows
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


echo "executing gnuplot for the Mice throughput file"

gnuplot -persist << EOF
reset
set title "INST Goodput - Server 1"
set xlabel "Simulation Time (s)"
set ylabel "Goodput Mb/s "
set terminal png
set yrange [0:1100]
set output "INST - Servers1.png"
plot "thrfile.tr" using 1:3 notitle with lines; #lp
EOF

nodenum=$(( $1 / 2)) 

numinfig=$nodenum
totalservers=$nodenum
end=$(($totalservers/$numinfig - 1))
for j in `seq 0 $end`
do
k1=$(($j*$numinfig+3));
k2=$(($k1+$numinfig-1)); 
gnuplot -persist << EOF
reset
set title "INST Goodput - Servers $(($k1-2))-$(($k2-2))"
set xlabel "Simulation Time (s)"
set ylabel "Goodput Mb/s "
set terminal png
set yrange [0:1100]
set output "INST - Servers $(($k1-1))-$(($k2-1)).png"
title(n)  =  sprintf("s_%d", n-1)
plot for [i=$k1:$k2] "thrfile.tr" using 1:i notitle with lines; #lp
EOF

done


for j in `seq 0 $end`
do
k1=$(($nodenum + $j*$numinfig +3));
k2=$(($k1+$numinfig-1)); 
gnuplot -persist << EOF
reset
set title "INST Goodput - Servers $(($k1-2))-$(($k2-2))"
set xlabel "Simulation Time (s)"
set ylabel "Goodput Mb/s "
set terminal png
set yrange [0:1100]
set output "INST - Servers $(($k1-1))-$(($k2-1)).png"
title(n)  =  sprintf("s_%d", n-1)
plot for [i=$k1:$k2] "thrfile.tr" using 1:i notitle with lines; #lp
EOF

done


gnuplot -persist << EOF
reset
set title "Total Goodput (Utilization)"
set xlabel "Simulation Time (s)"
set ylabel "Goodput Mb/s "
set terminal png
set yrange [0:1100]
set output "Total Goodput (Utilization).png"
plot "thrfile.tr" using 1:2 notitle with lines; #lp
