#!/bin/bash

: '
 * run_all_mix: run a mix of mice and elephant experiment with various parameter settings
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


simtime=5
sample=0.0005

for N in "100" #"2" "4" "8"
do
for tcpop in  "0"
do
for qsize in  "100" #"166"
do
for minrto in "0.2" #"0.02" "0.0002"
do
for RACK in   "1" #"0" "1" 
do
for vmdelay in "0.0005"
do
for rep in "5"
do
(./run-mix.sh $simtime $N $qsize $minrto $tcpop $sample $RACK $vmdelay $rep > TCP-$(date +%Y-%m-%d.%H.%M.%S).log ) >& TCP-ERR-$(date +%Y-%m-%d.%H.%M.%S).log
done
done
done
done
done
done
done
