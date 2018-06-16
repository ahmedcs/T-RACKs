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

files=`ls -d -1 */trace*`;

rm *.tmp
rm *.pdf

for f in $files; 
do

  
dname=`dirname $f`; 

if [[ "$dname" == *_bak ]]; then
	continue;
fi

basen=`basename $f`;
scharr=(${basen//-/});
inex=0
	for x in "${exclude[@]}";
	do
		if [[ $x == "${scharr[1]}" ]]; then
			echo "Break: " $x  "${scharr[1]}"
			inex=1;
			break;
		fi
	done
	if [ "$inex" == "1" ]; then
		echo "continue: " $x  "${scharr[1]}"
		continue;
	fi
	echo "$dname" >> schemefile.tmp
	echo "${scharr[1]}" >> loadfile.tmp
done

scheme=`cat schemefile.tmp | sort -u`;

i=0
for x in $scheme;
do
	s[$i]=$x; 
	i=$(( $i + 1 ));
done

sn[0]="Workload2"
sn[1]="Workload1"

gnuplot --persist << EOF 
	########### flow size CDF #########
	reset 
	
	scheme="${s[*]}"
	schemename="${sn[*]}"

	tot=0
	do for [ val in scheme ] {
		print val
		tot = tot + 1
	}
	
	set term pdf enhanced color size 3.15,2.45 font ",10"
    set key right bottom center notitle nobox
    set output 'Size-CDF.pdf'

    print "Size CDF"
    set autoscale xfixmin
    set autoscale xfixmax
    set yrange [0:1]
    set xrange [*:*]
    set logscale x
    set xlabel "size (bytes)"
    set ylabel "CDF (%)"
    val(x) = (x / 2)  + 1
    do for [i=1:tot] { print word(scheme, i).'/trace-30' }
    plot for [i=1:tot] word(scheme, i).'/trace-30' u (\$2 * 1460):(1./$num) smooth cumulative with line linetype val(i) dashtype val(i) lw 3 title word(schemename, i)
    
EOF