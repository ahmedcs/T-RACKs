#!/bin/sh

: '
 * draw_fcomp: draw the flow completion time information after parsing by flow_completion.py
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


for j in `seq 1 5`
do
gnuplot -persist << EOF
reset
set title "Flow Completion times of patch $j"
set xlabel "Source No."
set ylabel "Time in (ms)"
set terminal png
set output "flowcomp$j.png"
set xtic 1
set xrange [$(($1/2)) : $(($1 + 1)) ]
set ytic 0.5
set yrange [ 0 : 4 ]
plot "fcomp$j.tr" using 1:2 notitle with point 
EOF
done

gnuplot -persist << EOF
reset
set title "Average Flow Completion times"
set xlabel "Source No."
set ylabel "Variance in (ms)"
set terminal png
set output "flowcompavg.png"
set xtic 1
set xrange [$(($1/2)) : $(($1 + 1)) ]
set ytic 0.5
set yrange [ 0 : 3 ]
plot "flowcompavg.tr" using 1:2 notitle with lp 
EOF


gnuplot -persist << EOF
reset
set title "Flow Completion times Variance"
set xlabel "Source No."
set ylabel "Variance in (ms)"
set terminal png
set output "flowcompvar.png"
set xtic 1
set xrange [$(($1/2)) : $(($1 + 1)) ]
set ytic 0.5
set yrange [ 0 : 3 ]
plot "flowcompvar.tr" using 1:2 notitle with lp 
EOF

gnuplot -persist << EOF
reset
set title "Flow Completion times Average-Standard Deviation"
set xlabel "Source No."
set ylabel "Average-Standard Deviation in (ms)"
set terminal png
set output "flowcompavgstd.png"
set xtic 1
set xrange [$(($1/2)) : $(($1 + 1)) ]
set ytic 0.5
set yrange [ 0 : 3 ]
plot "flowcompavgstd.tr" using 1:2:3 notitle with yerrorbars
EOF
