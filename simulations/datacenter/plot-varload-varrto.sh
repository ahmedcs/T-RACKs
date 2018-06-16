#!/bin/bash

datdir=$1
num=$2
myArray=( "$@" )



for x in "droptail" "red" "dctcp";
do

j=0
for ((i=2; i < $#; i++));
do 
    f[$j]="${myArray[$i]}/websearch/$x-rack.res";
    j=$(( $j + 1));
done

outdir=$datdir/figs/$x
mkdir -p $outdir

gnuplot --persist << EOF  

	filenames="${f[*]}"
	schemes="RTT 5RTT 10RTT 50RTT 100RTT"
	load="30 40 50 60 70 80 90"
	
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
	
    set key horiz outside
    set key bottom center notitle nobox samplen 2
    set term pdf enhanced color size 3,2.5 font ",10"

    print "plot time against inter-arrival"
    set autoscale xfixmin
    set autoscale xfixmax
    set yrange [*:*]
    set xrange [*:*]
    set xlabel "Network load"
    
    set ylabel "Max FCT in (ms)"
    set output 'avg-smallmax.pdf'
    plot for [i=1:tot] word(filenames,i) using 1:(\$7) with lp lw 4 title word(schemes,i)
     
    set output '$outdir/avg-all.pdf'
    set ylabel "Average FCT in (ms)"
    plot for [i=1:tot] word(filenames,i) using 1:(\$4) with lp lw 4 title word(schemes,i)
	    
    set ylabel "Average FCT in (ms)"
    set output '$outdir/avg-smallavg.pdf'
    plot for [i=1:tot] word(filenames,i) using 1:(\$6) with lp lw 4 title word(schemes,i)
    
    set ylabel "AVG FCT in (ms)"
    set output '$outdir/avg-mediumavg.pdf'
    plot for [i=1:tot] word(filenames,i) using 1:(\$9) with lp lw 4 title word(schemes,i)
    
    set ylabel "Max FCT in (ms)"
    set output '$outdir/avg-mediummax.pdf'
    plot for [i=1:tot] word(filenames,i) using 1:(\$10) with lp lw 4 title word(schemes,i)
    
    set ylabel "AVG FCT in (ms)"
    set output '$outdir/avg-largeavg.pdf'
    plot for [i=1:tot] word(filenames,i) using 1:(\$12) with lp lw 4 title word(schemes,i)
    
    set ylabel "Max FCT in (ms)"
    set output '$outdir/avg-largemax.pdf'
    plot for [i=1:tot] word(filenames,i) using 1:(\$13) with lp lw 4 title word(schemes,i)
       
    set ylabel "Timeouts (#)"
    set output '$outdir/timeout.pdf'
    plot for [i=1:tot] word(filenames,i) using 1:(\$3) with lp lw 4 title word(schemes,i)
    
    set yrange [9900:10010]
    set ylabel "Finished (#)"
    set output '$outdir/finish.pdf'    
    plot for [i=1:tot] word(filenames,i) using 1:(\$2) with lp lw 4 title word(schemes,i), 10000 title ""
    
    set yrange [*:*]
    set ylabel "Simulation Duration (s)"
    set output '$outdir/Sim-Time.pdf'    
    plot for [i=1:tot] word(finfiles,i) using 1:(\$2) with lp lw 4 title word(schemes,i)
    
    set yrange [0:*]
    set ylabel "# of unfinished flows"
    set output '$outdir/unfinished.pdf'
    plot for [i=1:tot] word(filenames,i) using 1:(\$14) with lp lw 4 title word(schemes,i)
    
EOF

done
exit; 