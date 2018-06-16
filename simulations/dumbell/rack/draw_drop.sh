#!/bin/sh

: '
 * draw_drop: draw the per flow drop information
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


nodes=$1
colnum=$(($nodes + 3))

gnuplot -persist << EOF
reset
set title "Cumulative Drops"
set xlabel "Simulation Time (s)"
set ylabel "Cumulative Drops in packets"
set terminal png
set output "drops.png"
plot "mytracefile.tr" using 1:$colnum notitle with lines; #lp
EOF


echo "executing gnuplot for the drop file"

nodenum=$(( $nodes / $2)) 

numinfig=$nodenum
totalservers=$nodenum
end=$(($totalservers/$numinfig - 1))
for j in `seq 0 $end`
do
k1=$(($j*$numinfig+2));
k2=$(($k1+$numinfig-1)); 
gnuplot -persist << EOF
reset
set title "Drops - Servers $(($k1-1))-$(($k2-1))"
set xlabel "Simulation Time (s)"
set ylabel " Drops in packets "
set terminal png
set output "Drops - Servers $(($k1-1))-$(($k2-1)).png"
title(n)  =  sprintf("s_%d", n-1)
plot for [i=$k1:$k2] "dropfile.tr" using 1:i t title(i) with lines
EOF

done


for j in `seq 0 $end`
do
k1=$(($nodenum + $j*$numinfig +2));
k2=$(($k1+$numinfig-1)); 
gnuplot -persist << EOF
reset
set title "Drops - Servers $(($k1-1))-$(($k2-1))"
set xlabel "Simulation Time (s)"
set ylabel "Drops in packets "
set terminal png
set output "Drops - Servers $(($k1-1))-$(($k2-1)).png"
title(n)  =  sprintf("s_%d", n-1)
plot for [i=$k1:$k2] "dropfile.tr" using 1:i t title(i) with lines
EOF

done

gnuplot -persist << EOF
reset
set title "Total Per Flow Drops"
set xlabel "Source No."
set ylabel "Total Drops in packets"
set terminal png
set output "source-drop1.png"
set xtics 1
plot "source-drop.tr" every ::0::$(($nodenum-1)) u 1:2 notitle with point 
EOF

gnuplot -persist << EOF
reset
set title "Total Per Flow Drops"
set xlabel "Source No."
set ylabel "Total Drops in packets"
set terminal png
set output "source-drop2.png"
set xtics 1
plot "source-drop.tr" every ::$nodenum::$(($nodenum*2)) u 1:2 notitle with point 
EOF