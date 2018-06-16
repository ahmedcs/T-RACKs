#!/bin/sh

: '
 * draw_queue: draw the instantaneous queue size over time
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


gnuplot -persist << EOF
reset
set title "Queue Size"
set xlabel "Simulation Time (s)"
set ylabel "Queue Size in bytes "
set terminal png
set output "queue.png"
plot "queue.tr" using 3:9 notitle with lines; #lp
EOF



