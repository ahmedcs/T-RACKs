#!/bin/sh

: '
 * draw_queue_detailed: draw detailed queue size over a certain period or samples (e.g., 100000 points in this case)
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
set output "queue1.png"
plot "queue.tr" every ::0::100000 using 3:9 notitle with lines; #lp
EOF



