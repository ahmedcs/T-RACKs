if 0 { 
 *  Elephants only - The tcl script to run an elephants only experiments
 *
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
}


set simulationTime [lindex $argv 0]
set tcptype [lindex $argv 1]
set qtype [lindex $argv 2]
set N [lindex $argv 3]
set B [lindex $argv 4]
set packetSize  [lindex $argv 5]
set minrto  [lindex $argv 6]
set tcpopt [lindex $argv 7] 
set sample [lindex $argv 8]
set RACKenable [lindex $argv 9] 
set vmdelay [lindex $argv 10]

puts "$sample $RACKenable $vmdelay"

########################Util Functions#########################

# Function to insert the shaper between two nodes
Simulator instproc insert-shaper {shaper n1 n2} {
         $self instvar link_
         set sid [$n1 id]
         set did [$n2 id]
         set templink $link_($sid:$did)
         set linktarget [$templink get-target]
         $templink set-target $shaper
         $shaper target $linktarget
} 

SimpleLink instproc set-target {tg} {
    $self instvar link_
    $link_ target $tg
}

SimpleLink instproc get-target {} {
    $self instvar link_
    set tg [$link_ target]
    return $tg 
}

Simulator instproc reverse-target-shaper {shaper1 shaper2} {
	 $shaper1 reverse-shaper $shaper2
}

Simulator instproc reverse-target-node {shaper n1} {
	 $shaper reverse-target $n1
}

#########################TCP####################################
set switchAlg $qtype
set enableNAM 0
set enabletr 0
set ackRatio 1 
set tcpstart [expr $simulationTime/3]

set RTT 0.0001 ; #in msec
set K 20
set qpacketSize [expr $packetSize + 40]

Agent/TCP set tcpTick_ 0.00001
Agent/TCP set packetSize_ $packetSize
Agent/UDP set packetSize_   [expr $qpacketSize]
Agent/TCP set minrto_ $minrto ;
Agent/TCP set delay_growth_ false ;	# default changed on 2001/5/17.
Agent/TCP set rtxcur_init_ [expr (2 * $vmdelay + $RTT) * 3]

if {$tcpopt == "1"} {
	set sourceAlg DC-TCP-Sack
} else {
	set sourceAlg DC-TCP-Newreno
	Agent/TCP/FullTcp set interval_ 0.0;  #delayed ACK interval = 40ms
}

if {$qtype == "RED"} {
Agent/TCP set ecn_ 1
Agent/TCP set old_ecn_ 1
Agent/TCP/FullTcp set ecn_syn_ true
Agent/TCP/FullTcp set ecn_syn_wait_ true 
}

Agent/TCP set window_ 3
#Agent/TCP set window_ 10
#Agent/TCP set windowInit_ 10
if {$tcpopt == 1} {
	#Agent/TCP set window_ 12560
	#Agent/TCP set slow_start_restart_ false
	#Agent/TCP set windowOption_ 0
}



#########################FullTCP###################################
Agent/TCP/FullTcp set segsize_ $packetSize
#Agent/TCP/FullTcp set segsperack_ $ackRatio; 
#Agent/TCP/FullTcp set spa_thresh_ 3000;
#Agent/TCP/FullTcp set interval_ [expr 4 * $RTT] ; #0.0004; #delayed ACK interval = 40ms
#########################DCTCP###################################


#########################RED####################################
#Queue/RED set limit_ 150
if {$qtype == "RED"} {
Queue/RED set bytes_ false
Queue/RED set queue_in_bytes_ true
Queue/RED set mean_pktsize_ $qpacketSize
Queue/RED set setbit_ true
Queue/RED set gentle_ false
Queue/RED set queue_in_bytes_ true
Queue/RED set q_weight_ 1.0
Queue/RED set mark_p_ 1.0
Queue/RED set thresh_ [expr $K]
Queue/RED set maxthresh_ [expr $K]
	
}




##########################setting TCP and AQM##################################

set startMeasurementTime 0.0
set stopMeasurementTime 0.99
set flowClassifyTime [expr 2 * $vmdelay + ($N+1) * $RTT/4]

set lineRate 1Gb
set inputLineRate 1Gb
 
set traceSamplingInterval $sample
set throughputSamplingInterval [expr 5 * $sample]
set dropSamplingInterval $sample


set ns [new Simulator]

if {$enableNAM != 0} {
    set namfile [open out.nam w]
    $ns namtrace-all $namfile
}

if {$enabletr != 0} {
    set trfile [open out.tr w]
    $ns trace-all $trfile
}

for {set i 0} {$i < $N} {incr i} {
set tcptracefile($i) [open tcptracefile-$i.tr w]
}
set mytracefile [open mytracefile.tr w]
set throughputfile [open thrfile.tr w]
set dropfile [open dropfile.tr w]
set dfile [open source-drop.tr w]

proc finish {} {
        global ns enableNAM enabletr namfile mytracefile throughputfile qfile dropfile dfile trfile tcptracefile N
        $ns flush-trace
	for {set i 0} {$i < $N} {incr i} {
		close $tcptracefile($i)
	}
        close $mytracefile
        close $throughputfile
	close $dropfile
        if {$enableNAM != 0} {
	    close $namfile
	    exec nam out.nam &
	}
	if {$enabletr != 0} {
   		close $trfile
	}
	close $dfile
	exit 0
}

set meanq 0
set oldmeanq 0
set count 0
set oldbdepartures 0

proc tcpTrace {} {
    global ns N traceSamplingInterval tcp tcptracefile
    set now [$ns now]

	for {set i 0} {$i < $N} {incr i} {
	    set cwnd [$tcp($i) set cwnd_]
	    set seqno [$tcp($i) set t_seqno_]
	    set ssthresh [$tcp($i) set ssthresh_]
	    set rtt [$tcp($i) set rtt_] 
	    set backoff [$tcp($i) set backoff_]
	    set retransmit [$tcp($i) set nrexmitpack_]
	    set cwndcut [$tcp($i) set ncwndcuts1_] 
	    set ecn [$tcp($i) set necnresponses_]   
	    puts $tcptracefile($i) "$now $seqno $cwnd $ssthresh $rtt $backoff $retransmit $cwndcut $ecn"
	}
     
    $ns at [expr $now+$traceSamplingInterval] "tcpTrace"
}

proc myTrace {file} {
    global ns N traceSamplingInterval tcp qfile MainLink nbow nclient packetSize enableBumpOnWire tcptype meanq oldmeanq count
    
    set now [$ns now]
    
    for {set i 0} {$i < $N} {incr i} {
	set cwnd($i) [$tcp($i) set cwnd_]
	set wnd($i) [$tcp($i) set window_]
	set dctcp_alpha($i) [$tcp($i) set dctcp_alpha_]
    }
    
    $qfile instvar barrivals_ bdepartures_ bdrops_ pdrops_
    puts -nonewline $file "$now $cwnd(0)"
if {$tcptype == "TCP"} {
    for {set i 1} {$i < $N} {incr i} {
	puts -nonewline $file " $cwnd($i)"
    }
}
 	 #puts -nonewline $file " [expr $parrivals_-$pdepartures_-$pdrops_]"
    set meanq [expr $meanq + $barrivals_-$bdepartures_-$bdrops_]
    incr count
    if { $count == 10 } {
	    puts -nonewline $file " [expr $meanq / $count]" 
	    set oldmeanq [expr $meanq / $count] 
            set meanq 0
	    set count 0
    }  else {
	 puts -nonewline $file " $oldmeanq"
    }  
    puts $file " $pdrops_"
     
    $ns at [expr $now+$traceSamplingInterval] "myTrace $file"
}

proc throughputTrace {file} {
    global ns throughputSamplingInterval qfile flowstats N flowClassifyTime oldbdepartures
    
    set now [$ns now]
    
    $qfile instvar bdepartures_
    
    puts -nonewline $file "$now [expr ($bdepartures_-$oldbdepartures)*8/$throughputSamplingInterval/1000000]"
    set oldbdepartures $bdepartures_
    #set bdepartures_ 0
    if {$now <= $flowClassifyTime} {
	for {set i 0} {$i < [expr $N-1]} {incr i} {
	    puts -nonewline $file " 0"
	}
	puts $file " 0"
    }

     if {$now > $flowClassifyTime} { 
	for {set i 0} {$i < [expr $N-1]} {incr i} {
	    $flowstats($i) instvar bdepartures_
	    puts -nonewline $file " [expr $bdepartures_*8/$throughputSamplingInterval/1000000]"
	    set bdepartures_ 0
	}
	$flowstats([expr $N -1 ]) instvar bdepartures_
	puts $file " [expr $bdepartures_*8/$throughputSamplingInterval/1000000]"
	set bdepartures_ 0
    }
    $ns at [expr $now+$throughputSamplingInterval] "throughputTrace $file"
}

proc dropTrace {file} {
    global ns dropSamplingInterval qfile flowstats N flowClassifyTime simulationTime totaldrops
    
    set now [$ns now]
    
    puts -nonewline $file "$now"
     if {$now <= $flowClassifyTime} {
	for {set i 0} {$i < [expr $N-1]} {incr i} {
	    puts -nonewline $file " 0"
	}
	puts $file " 0"
    }

    if {$now > $flowClassifyTime} { 
	for {set i 0} {$i < [expr $N - 1]} {incr i} {
	    $flowstats($i) instvar pdrops_
	    puts -nonewline $file " $pdrops_"
            set totaldrops($i)  $pdrops_
	    set $pdrops_ 0
	}
	$flowstats([expr $N -1]) instvar pdrops_
	set totaldrops([expr $N -1])  $pdrops_
	puts $file " $pdrops_"
	set $pdrops_ 0
    }
    $ns at [expr $now+$dropSamplingInterval] "dropTrace $file"
}

$ns color 0 Red
$ns color 1 Orange
$ns color 2 Yellow
$ns color 3 Green
$ns color 4 Blue
$ns color 5 Violet
$ns color 6 Brown
$ns color 7 Black

for {set i 0} {$i < [expr $N]} {incr i} {
    set n($i) [$ns node]
}

set nqueue1 [$ns node]
set nqueue2 [$ns node]
set nclient [$ns node]


$nqueue1 color red
$nqueue1 shape box
$nclient color blue

for {set i 0} {$i < [expr $N]} {incr i} {
    $ns duplex-link $n($i) $nqueue1 $inputLineRate $vmdelay DropTail
    #$ns duplex-link $n($i) $nqueue1 $inputLineRate [expr $RTT / 6] DropTail
    $ns queue-limit $n($i) $nqueue1 [expr $B * 20]
    $ns duplex-link-op $n($i) $nqueue1 queuePos 0.025
    	
    ####################### Shaper #################################
    
	    set shaper($i) [new RACK]
	    set rshaper($i) [new RACK] 

   	    if { $RACKenable == 1 } {
	    $shaper($i) set-enabled $RACKenable
	    $rshaper($i) set-enabled $RACKenable
	    }

	    $shaper($i) set-vmdelay $vmdelay
	    $rshaper($i) set-vmdelay $vmdelay

	    $shaper($i) set-RTT  $RTT
	    $rshaper($i) set-RTT  $RTT

	    $ns insert-shaper $shaper($i)  $n($i) $nqueue1
	    $ns insert-shaper $rshaper($i)  $nqueue1 $n($i) 
	    #$ns reverse-target-shaper $shaper($i) $rshaper($i)
	    #$ns reverse-target-shaper $rshaper($i) $shaper($i)
	    #$shaper($i) activate-fid $i
            #$rshaper($i) activate-fid $i
    
    ####################### Shaper #################################
}

$ns duplex-link $nqueue1 $nqueue2 $lineRate [expr $RTT / 4] $switchAlg
$ns queue-limit $nqueue1 $nqueue2 $B

$ns duplex-link $nqueue2 $nclient $lineRate [expr $RTT / 4] DropTail
$ns queue-limit $nqueue2 $nclient [expr $B * 20]
$ns duplex-link-op $nqueue2 $nclient color "green"
$ns duplex-link-op $nqueue2 $nclient queuePos 0.25


#set qfile [$ns monitor-queue $nqueue1 $nqueue2 [open queue.tr w] $traceSamplingInterval]
#[$ns link $nqueue1 $nqueue2] start-tracing; #queue-sample-timeout;

set qfile [$ns monitor-queue $nqueue2 $nclient [open queue.tr w] $traceSamplingInterval]
[$ns link $nqueue2 $nclient] start-tracing; #queue-sample-timeout;



for {set i 0} {$i < [expr $N]} {incr i} {
    if {[string compare $sourceAlg "Newreno"] == 0 || [string compare $sourceAlg "DC-TCP-Newreno"] == 0} {
	set tcp($i) [new Agent/TCP/FullTcp/Newreno]
	set sink($i) [new Agent/TCP/FullTcp/Newreno]
	$sink($i) listen
    }
    if {[string compare $sourceAlg "Sack"] == 0 || [string compare $sourceAlg "DC-TCP-Sack"] == 0} { 
        set tcp($i) [new Agent/TCP/FullTcp/Sack]
	set sink($i) [new Agent/TCP/FullTcp/Sack]
	$sink($i) listen
    }

    $ns attach-agent $n($i) $tcp($i)
    $ns attach-agent $nclient $sink($i)
    
    $tcp($i) set fid_ [expr $i]
    $sink($i) set fid_ [expr $i]

    $ns connect $tcp($i) $sink($i)       
}


$ns at 0.0 "tcpTrace"
$ns at 0.0 "myTrace $mytracefile"
$ns at 0.0 "throughputTrace $throughputfile"
$ns at 0.0 "dropTrace $dropfile"
#$ns at 0.0 "$ftp(0) send 1000"
#$ns at $tcpstart "$ftp(0) start"
#$ns at [expr $simulationTime] "$ftp(0) stop"

set ru [new RandomVariable/Uniform]
$ru set min_ 0
$ru set max_ 1.0

for {set i 0} {$i < [expr $N]} {incr i} {
    set ftp($i) [new Application/FTP]
    $ftp($i) attach-agent $tcp($i) 
    set totaldrops($i) 0   
}

for {set i 0} {$i < [expr $N]} {incr i} {
     $ns at 0.0 "$ftp($i) start"
     $ns at [expr $simulationTime] "$ftp($i) stop"
    
}

set flowmon [$ns makeflowmon Fid]
set MainLink [$ns link $nqueue1 $nqueue2]

$ns attach-fmon $MainLink $flowmon

set fcl [$flowmon classifier]

$ns at $flowClassifyTime "classifyFlows"

 #for {set i 0} {$i < [expr $N * ($rep + 1)]} {incr i} {
proc classifyFlows {} {
    global N rep fcl flowstats
    puts "NOW CLASSIFYING FLOWS"
    for {set i 0} {$i < [expr $N]} {incr i} {
	set flowstats($i) [$fcl lookup autp 0 0 $i]
    }
} 


set startPacketCount 0
set stopPacketCount 0

proc startMeasurement {} {
global qfile startPacketCount
$qfile instvar pdepartures_   
set startPacketCount $pdepartures_
}

proc stopMeasurement {} {
global qfile startPacketCount stopPacketCount packetSize startMeasurementTime stopMeasurementTime simulationTime dfile N totaldrops
$qfile instvar pdepartures_  bdepartures_ 
set stopPacketCount $pdepartures_
puts "Throughput = [expr ($stopPacketCount-$startPacketCount)/(1024.0*1024*($stopMeasurementTime-$startMeasurementTime))*$packetSize*8] Mbps"
puts "Throughput = [expr $bdepartures_/(1024.0*1024*($stopMeasurementTime-$startMeasurementTime))*8] Mbps"
for {set i 0} {$i < $N} {incr i} {
	    puts $dfile "$i $totaldrops($i)"
	}
}

$ns at $startMeasurementTime "startMeasurement"
$ns at $stopMeasurementTime "stopMeasurement"
                      
$ns at $simulationTime "finish"

$ns run
