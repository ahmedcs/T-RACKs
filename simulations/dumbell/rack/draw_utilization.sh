#!/bin/sh


: '
 * draw_utilizations: draws the link utilization of the experiment time
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
set title "bottleneck utilization"
set xlabel "Simulation Time (s)"
set ylabel "Goodput Mb/s "
set terminal png
set output "utilization.png"
plot  "thrfile.tr" using 1:2 notitle with lines; #lp
EOF
