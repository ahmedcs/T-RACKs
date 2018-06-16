#!/bin/bash

datdir=$1
num=$2
myArray=( "$@" )
for ((i=2; i < $#; i++));
do 
    exclude[$i]="${myArray[$i]}";
    echo "${myArray[$i]}" "${exclude[$i]}" ;
done

curdir=$PWD
cd $datdir
files=`ls -d -1 */flow.res`;
trfiles=`ls -d -1 */flow.tr`;
logfiles=`ls -d -1 */logFile.tr`;

for  file in $trfiles;
do
    python $curdir/result.py -a -n $num -i $file;
    #cat $file | sort -k 2,2 | awk 'BEGIN{min=$8-$2}{print ($8 - $2 - min), $1;}'  > `dirname $file`/trace.tr
    awk '{print ($8 - $2), $1;}' $file  > `dirname $file`/trace.tr
done

rm trace-*
	
dirs=`ls -d *_*_$i_*`
for i in $dirs;
do
	#echo $i
	xarr=(${i//_/ });
	cp $i/trace.tr ./trace-${xarr[2]}
	# dnames=(${i//_/ });
# 	if [[ "${dnames[2]}" == "$i" ]]; then
# 		echo cp ${dirs[0]}/trace.tr ./trace-$i.tr
# 		cp ${dirs[0]}/trace.tr ./trace-$i.tr
# 		continue;
# 	fi
done

rm *.res
rm *.tmp
rm *.fin
rm *.pdf

for f in $logfiles; 
do  
dname=`dirname $f`; 
scharr=(${dname//_/ });
t=`cat  $f | grep Time | awk '{print $2}'`
if [ "${scharr[1]}" == "pfabric" ]; then
	if [ "${scharr[7]}" == "0" ]; then
    	echo "${scharr[3]}" "$t" >> "${scharr[1]}_${scharr[2]}.fin";
	else
		echo "${scharr[3]}" "$t" >> "${scharr[1]}_${scharr[2]}-rack.fin";
	fi
else
	if [ "${scharr[7]}" == "0" ]; then
    	echo "${scharr[2]}" "$t" >> "${scharr[1]}.fin";
	else
		echo "${scharr[2]}" "$t" >> "${scharr[1]}-rack.fin";
	fi
fi
done;

for f in $files; 
do 
dname=`dirname $f`;
scharr=(${dname//_/ });
inex=0
for x in "${exclude[@]}";
do
    if [[ $x == "${scharr[1]}" || $x == "${scharr[1]}_${scharr[2]}" ]]; then
        echo "Break: " $x  "${scharr[1]}"
        inex=1;
        break;
    fi
done
if [ "$inex" == "1" ]; then
    echo "continue: " $x  "${scharr[1]}"
    continue;
fi
if [ "${scharr[1]}" == "pfabric" ]; then
	#echo "${scharr[1]}-${scharr[2]}" >> schemefile.tmp;
	if [ "${scharr[7]}" == "0" ]; then
		echo "pfabric" >> schemefile.tmp
		echo "${scharr[3]}" >> loadfile.tmp
		#line=`cat *_"${scharr[1]}_${scharr[2]}_${scharr[3]}"_*_0/*.res`
		line=`cat $f`;
		echo "${scharr[3]}" $line >> "${scharr[1]}_${scharr[2]}.res";
	else
		echo "pfabric-rack" >> schemefile.tmp
		echo "${scharr[3]}" >> loadfile.tmp
		#line=`cat *_"${scharr[1]}_${scharr[2]}_${scharr[3]}"_*_1/*.res`
		line=`cat $f`;
		echo "${scharr[3]}" $line >> "${scharr[1]}_${scharr[2]}-rack.res";
	fi
else
	if [ "${scharr[7]}" == "0" ]; then
	    echo "NONRACK: ${scharr[@]}" 
		echo "${scharr[1]}" >> schemefile.tmp;
		echo "${scharr[2]}" >> loadfile.tmp; 
		#line=`cat *_"${scharr[1]}_${scharr[2]}"_*_0/*.res`;
		line=`cat $f`;
		echo "${scharr[2]}" $line >> "${scharr[1]}.res";
	else
		echo "RACK: ${scharr[@]}" 
		echo "${scharr[1]}-rack" >> schemefile.tmp;
		echo "${scharr[2]}" >> loadfile.tmp; 
		#line=`cat *_"${scharr[1]}_${scharr[2]}"_*_1/*.res`;
		line=`cat $f`;
		echo "${scharr[2]}" $line >> "${scharr[1]}-rack.res";	
	fi
fi
done

total=`ls *.res | wc -l`
files=`ls -d -1 *.res`;
scheme=`cat schemefile.tmp | sort -u`;
load=`cat loadfile.tmp | sort -u`;
cat *.res >> all.res;

i=0
for x in $scheme;
do
	if [ "$x" == "droptail" ]; then
		s[$i]="DT";
	fi
	if [ "$x" == "dctcp" ]; then
		s[$i]="DCTCP";
	fi
	if [ "$x" == "red" ]; then
		s[$i]="RED";
	fi
	if [ "$x" == "droptail-rack" ]; then
		s[$i]="DT-RACK";
	fi
	if [ "$x" == "red-rack" ]; then
		s[$i]="RED-RACK";
	fi
	if [ "$x" == "dctcp-rack" ]; then
		s[$i]="DCTCP-RACK";
	fi
	#s[$i]=$x; 
	i=$(( $i + 1 ));
done

i=0
for x in $load;
do
	l[$i]=$( printf '%d' "$x" );
	i=$(( $i + 1 ));
done

i=0
for x in $scheme #`cat schemefile.tmp` #$files;
do
	#f[$i]=$x;
	f[$i]="$x.res";
	i=$(( $i + 1 ));
done


i=0
for x in *.fin;
do
    echo $x;
    finf[$i]=$x;
	i=$(( $i + 1 ));
done

gnuplot --persist << EOF  

	filenames="${f[*]}"
    finfiles="${finf[*]}"
    load="${l[*]}"
	schemes="${s[*]}"
	
	tot=0
	do for [ val in filenames ] {
		print val
		tot = tot + 1
	}
	
    print "\n" 
    do for [ i=1:tot ] {
        print word(schemes, i)
	}
    
    print "\n"  
	
	ltot=0
    do for [ val in load ] {
		print val
		ltot = ltot + 1
	}
	
	#unset xrange
	#set xtics load
    #plot for [f in filenames] f using 2:(\$4 / 1000) with lp lw 4 title sprintf("%s", f)
	
    set key horiz outside
    set key bottom center notitle nobox samplen 2
    set term pdf enhanced color size 3.15,2.52 font ",10"

    print "plot time against inter-arrival"
    set autoscale xfixmin
    set autoscale xfixmax
    set yrange [*:*]
    #set xrange [*:*]
    set xrange [20:100]
    set xlabel "Network load"
    
    set output 'avg-all.pdf'
    set ylabel "Average FCT in (s)"
    plot for [i=1:tot] word(filenames,i) using 1:(\$4 / 1000) with lp lw 4 title word(schemes,i)
    
    set ylabel "Average FCT in (s)"
    set output 'avg-smallavg.pdf'
    plot for [i=1:tot] word(filenames,i) using 1:(\$6 / 1000) with lp lw 4 title word(schemes,i)
    
    set ylabel "Max FCT in (s)"
    set output 'avg-smallmax.pdf'
    plot for [i=1:tot] word(filenames,i) using 1:(\$7 / 1000) with lp lw 4 title word(schemes,i)
    
    set ylabel "AVG FCT in (s)"
    set output 'avg-mediumavg.pdf'
    plot for [i=1:tot] word(filenames,i) using 1:(\$9 / 1000) with lp lw 4 title word(schemes,i)
    
    set ylabel "Max FCT in (s)"
    set output 'avg-mediummax.pdf'
    plot for [i=1:tot] word(filenames,i) using 1:(\$10 / 1000) with lp lw 4 title word(schemes,i)
    
    set ylabel "AVG FCT in (s)"
    set output 'avg-largeavg.pdf'
    plot for [i=1:tot] word(filenames,i) using 1:(\$12 / 1000) with lp lw 4 title word(schemes,i)
    
    set ylabel "Max FCT in (s)"
    set output 'avg-largemax.pdf'
    plot for [i=1:tot] word(filenames,i) using 1:(\$13 / 1000) with lp lw 4 title word(schemes,i)
    
    
    set ylabel "Timeouts (#)"
    set output 'timeout.pdf'
    plot for [i=1:tot] word(filenames,i) using 1:(\$3) with lp lw 4 title word(schemes,i)
    
    set yrange [9900:10010]
    set ylabel "Finished (#)"
    set output 'finish.pdf'    
    plot for [i=1:tot] word(filenames,i) using 1:(\$2) with lp lw 4 title word(schemes,i), 10000 title ""
    
    set yrange [*:*]
    set ylabel "Simulation Duration (s)"
    set output 'Sim-Time.pdf'    
    plot for [i=1:tot] word(finfiles,i) using 1:(\$2) with lp lw 4 title word(schemes,i)
    
    set yrange [0:*]
    set ylabel "# of unfinished flows"
    set output 'unfinished.pdf'
    plot for [i=1:tot] word(filenames,i) using 1:(\$14) with lp lw 4 title word(schemes,i)
    
    ############ flow interarrival CDF ##########
    reset
     
    set term pdf enhanced color size 3.15,2.52 font ",10"
    set key left top center reverse notitle nobox samplen 2
    set output 'interarr-CDF.pdf'

    print "inter-arrival CDF"
    set autoscale xfixmin
    set autoscale xfixmax
    set yrange [0:1]
    set xrange [100:*]
    set logscale x
    set xlabel "Inter-arrival (usec)"
    set ylabel "CDF (%)"
    plot for [i=1:ltot] 'trace-'.word(load, i) u ((\$1 - 1) * 1000000):(1./$num) smooth cumulative with lp linetype i dashtype i lw 1 ps 0.3 title 'load-'.word(load, i).'%'
    
EOF
