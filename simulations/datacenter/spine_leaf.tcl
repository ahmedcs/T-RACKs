source "core_functions.tcl"

########################## Ahmed - Utility procedures##################################################
Simulator instproc other-queue { n1 n2 } {
	$self instvar link_
	[$link_([$n1 id]:[$n2 id]) queue] set otherpq_ [$link_([$n2 id]:[$n1 id]) queue]
	[$link_([$n2 id]:[$n1 id]) queue] set otherpq_ [$link_([$n1 id]:[$n2 id]) queue]

}

# Function to insert the shaper between two nodes
Simulator instproc insert-rack {shaper n1 n2} {
         $self instvar link_
         set sid [$n1 id]
         set did [$n2 id]
         set templink $link_($sid:$did)
         set linktarget [$templink get-target]
         $templink set-target $shaper
         $shaper target $linktarget
		 
		 puts "$shaper $n1 $n2 $templink $linktarget"
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

Simulator instproc reverse-two-rack {rack1 rack2} {
	 $rack1 reverse-rack $rack2
}

Simulator instproc reverse-target-node {shaper n1} {
	 $shaper reverse-target $n1
}
##########################End Ahmed ######################################################

set ns [new Simulator]
#set datenow [expr [clock format [clock seconds] -format {%H:%M:%S}]]
#puts "Date: $datenow"
set sim_start [clock seconds]
puts "start time is $sim_start"

if {$argc < 33} {
    puts "wrong number of arguments $argc"
    exit 0
}

remove-all-packet-headers;             # removes all packet headers
add-packet-header IP TCP;              # adds TCP/IP headers

####################### Parameters ####################################
set sim_end [lindex $argv 0]
set link_rate [lindex $argv 1]
set mean_link_delay [lindex $argv 2]
set host_delay [lindex $argv 3]
set queueSize [lindex $argv 4]
set load [lindex $argv 5]
set connections_per_pair [lindex $argv 6]
set meanFlowSize [lindex $argv 7]
set paretoShape [lindex $argv 8]
set flow_cdf [lindex $argv 9]

#### Multipath
set enableMultiPath [lindex $argv 10]
set perflowMP [lindex $argv 11]

#### Transport settings options
set sourceAlg [lindex $argv 12] ; # Sack or DCTCP-Sack
set initWindow [lindex $argv 13]
set ackRatio [lindex $argv 14]
set slowstartrestart [lindex $argv 15]
set DCTCP_g [lindex $argv 16] ; # DCTCP alpha estimation gain
set min_rto [lindex $argv 17]

#### Switch side options
set switchAlg [lindex $argv 18] ; # DropTail (pFabric), RED (DCTCP) or Priority (PIAS)
set DCTCP_K [lindex $argv 19]
set ECN_scheme_ [lindex $argv 20]

#### topology
set topology_spt [lindex $argv 21]
set topology_tors [lindex $argv 22]
set topology_spines [lindex $argv 23]
set topology_x [lindex $argv 24]

set flowlog [open [lindex $argv 25] w]

### Enable Rack Module
set rackval [lindex $argv 26]

### debuggin and tracing
set debugval [lindex $argv 27]
set traceval [lindex $argv 28]
### persistent connections
set npersistval [lindex $argv 29]

### persistent connections
set spacingval [lindex $argv 30]

#Num of RTT to use as RTO
set rackrttnum [lindex $argv 31]

### main dir
set maindirval [lindex $argv 32]

#tracedirectory
set tracedirval [lindex $argv 33]

#################### END - Parameters ##########################

#################### Init - variables ########################

set backg 0

set enablerack -1
set vmdelay 0
set eleph_thresh 0
set eleph 0

set enabletr 0
set enableeqtr 0
set enablecqtr 0
set enabletcptr 0
set enableNAM 0
set debug_state 0
set npersist 0
set spacing 0
set maindir "."
set tracedir "."

if { $rackval >= 1 } {
	set enablerack 1
	set vmdelay 0
	if { $rackval > 1 } {
		set eleph_thresh $rackval
	} else {
		set eleph 1
	}
	
} elseif { $rackval == 0 } {
	set enablerack 0
	set vmdelay 0
	set elephant 0
}

if { $traceval >= 1 } {
	set enabletcptr 1
}
if { $traceval >= 2 } {
	set enabletr 1
}
if { $traceval >= 3 } {
	set enableeqtr 1
	set enablecqtr 1
}
if { $traceval >= 4 } {
	set enableNAM 1
}
if { $debugval >= 0 } {
	set debug_state $debugval
}
if { $npersistval >= 0 } {
	set npersist $npersistval
}

if { $spacingval >= 0 } {
	set spacing $spacingval
}

if { $maindirval != "" } {
	set maindir $maindirval
}

if { $tracedirval != "" } {
	set tracedir $tracedirval
}
################################## NS tracing ########################################

if {$enableNAM == 1} {
	set namfile [open "$tracedir/out.nam" w]
    $ns namtrace-all $namfile
	puts "NAM ALL Enabled"
}

if {$enabletr == 1} {
	set trfile [open "$tracedir/main.out" w]
    $ns trace-all $trfile
	puts "Trace ALL Enabled"
}


if {$enabletcptr == 1} {
	set cwndfile [open "$tracedir/cwnd.out" w]
	set wndfile [open "$tracedir/wnd.out" w]
	puts "TCP Trace Enabled"
}

#### Packet size is in bytes.
set pktSize 1460
#### trace frequency
set queueSamplingInterval 0.0001
#set queueSamplingInterval 1
### Change queue size to BDP (between ToR end-hosts)
set queueSize [expr 2 * ($mean_link_delay + $host_delay) * $link_rate * 1000000000 / 8 / ($pktSize + 40)]

puts "Simulation input:"
puts "Dynamic Flow - Pareto"
puts "topology: spines server per rack = $topology_spt, x = $topology_x"
puts "sim_end $sim_end"
puts "link_rate $link_rate Gbps"
puts "link_delay $mean_link_delay sec"
puts "host_delay $host_delay sec"
puts "queue size $queueSize pkts"
puts "minimum RTO: $min_rto"
puts "load $load"
puts "connections_per_pair $connections_per_pair"
puts "enableMultiPath=$enableMultiPath, perflowMP=$perflowMP"
puts "source algorithm: $sourceAlg"
puts "TCP initial window: $initWindow"
puts "ackRatio $ackRatio"
puts "DCTCP_g $DCTCP_g"
puts "slow-start Restart $slowstartrestart"
puts "switch algorithm $switchAlg"
puts "DCTCP_K_ $DCTCP_K"
puts "pktSize(payload) $pktSize Bytes"
puts "pktSize(include header) [expr $pktSize + 40] Bytes"
puts "TCP spacing : $spacing"
puts "non-persistent: $npersist"

puts "RACK enabled or not: $enablerack"
puts "RACK vmdelay or not: $vmdelay"
puts "RACK elephant: $eleph"
puts "RACK eleph threshold: $eleph_thresh"
puts "RACK RTT Number: $rackrttnum"

puts " "


## number of servers
set S [expr $topology_spt * $topology_tors] ; #number of servers
## Uplink Capacity
set UCap [expr $link_rate * $topology_spt / $topology_spines / $topology_x] ; #uplink rate
#set UCap [expr $link_rate  * $topology_spt / $topology_x] ; #uplink rate

################# Transport Options ####################

set maxwindow 1000000

#0 -no pacing
#1 - traditional pacing. This option allows TCP to pace the packet in a rate of cwnd/RTT (packet/sec)
#2 - aggressive pacing. This option predicts the maximum value of congestion window at the end of this RTT (pCwnd). And pace the packet in a rate of pCwnd/ RTT (packet/sec)
if { $spacing > 0} {
	Agent/TCP set pace_packet_ spacing
}

Agent/TCP set ecn_ 1
Agent/TCP set old_ecn_ 1
Agent/TCP set use_rwnd_ 0
Agent/TCP/FullTcp set use_rwnd_ 0
Agent/TCP/FullTcp set flow_remaining_ 0
Agent/TCP set packetSize_ $pktSize
Agent/TCP/FullTcp set segsize_ $pktSize
Agent/TCP/FullTcp set spa_thresh_ 0
Agent/TCP set slow_start_restart_ $slowstartrestart
Agent/TCP set windowOption_ 0
Agent/TCP set minrto_ $min_rto
Agent/TCP set tcpTick_ 0.000001
Agent/TCP set maxrto_ 64

Agent/TCP/FullTcp set nodelay_ true; # disable Nagle
Agent/TCP/FullTcp set segsperack_ $ackRatio;
Agent/TCP/FullTcp set interval_ 0.000006
Agent/TCP/FullTcp/Newreno set recov_maxburst_ 2; # max burst dur recov
#Agent/TCP/FullTcp set debug_ 1

Agent/TCP set window_ $maxwindow
Agent/TCP set windowInit_ $initWindow
Agent/TCP set rtxcur_init_ $min_rto;
Agent/TCP/FullTcp/Sack set clear_on_timeout_ false;
Agent/TCP/FullTcp/Sack set sack_rtx_threshmode_ 2;

Agent/TCP/FullTcp set dynamic_dupack_ 100000.0; #disable dupack actions (i.e, FR)
if { $enablerack > -1 } {
 	Agent/TCP/FullTcp set dynamic_dupack_ 0; #enable dupack actions (i.e, FR)
}

if {$ackRatio > 2} {
    Agent/TCP/FullTcp set spa_thresh_ [expr ($ackRatio - 1) * $pktSize]
}

################# Ahmed ######################
## disable the orginial setup of setting upperbound on MaxCWND
## let MaxCWND grow as large as the Recieve window
Agent/TCP set maxcwnd_  $maxwindow

#if {$queueSize > $initWindow } {
#    Agent/TCP set maxcwnd_ [expr $queueSize - 1];
#} else {
#    Agent/TCP set maxcwnd_ $initWindow
#}

if {[string compare $sourceAlg "DCTCP"] == 0 || [string compare $sourceAlg "TCPECN"] == 0} {
	  set myAgent "Agent/TCP/FullTcp/Newreno";
	  if {[string compare $sourceAlg "DCTCP"] == 0} {
    		Agent/TCP set dctcp_ true
    		Agent/TCPSink set dctcp_ true
   			 Agent/TCP set dctcp_g_ $DCTCP_g
   	 }
}

} elseif {[string compare $sourceAlg "TCP"] == 0 } {
  ## disable ECN for TCP (no need)
  ##use normal SACK TCP not the modified version for RTCP
  Agent/TCP set ecn_ 0
  Agent/TCP set old_ecn_ 0
  Agent/TCP/FullTcp set flow_remaining_ 0

  set myAgent "Agent/TCP/FullTcp/Newreno";

} 
if { $enablerack > -1 } {

	  set myAgent "Agent/TCP/FullTcp/Newreno";
}

############################################# Switch Options ##############################################

Queue set limit_ $queueSize

Queue/DropTail set queue_in_bytes_ true
Queue/DropTail set mean_pktsize_ [expr $pktSize+40]
Queue/DropTail set drop_front_ 0

Queue/RED set bytes_ false
Queue/RED set queue_in_bytes_ true
Queue/RED set mean_pktsize_ [expr $pktSize+40]
Queue/RED set setbit_ true
Queue/RED set gentle_ false
Queue/RED set q_weight_ 1.0
Queue/RED set mark_p_ 1.0
Queue/RED set thresh_ $DCTCP_K
Queue/RED set maxthresh_ $DCTCP_K

if { $switchAlg == "RED" } {

Queue/RED set bytes_ false
Queue/RED set queue_in_bytes_ true
Queue/RED set mean_pktsize_ [expr $pktSize+40]
Queue/RED set setbit_ true
Queue/RED set gentle_ false
Queue/RED set q_weight_ 0.25
Queue/RED set mark_p_ 1.0
Queue/RED set thresh_ [expr $queueSize * 0.2]
Queue/RED set maxthresh_ [expr $queueSize * 0.4]


}

######################### Ahmed ####################################
#rtt in spine network is 2 * 4 (links) * linkdelay + error marigin
set mean_rtt [expr ($host_delay + $mean_link_delay) * 4]
set tot_conn [expr $S  * $S]

####################IQM#########################
if { [string compare $switchAlg "DropTail"] == 0 } {

set switchAlg "DropTail"

Queue/DropTail set drop_front_ false
Queue/DropTail set summarystats_ false
Queue/DropTail set queue_in_bytes_ true
Queue/DropTail set mean_pktsize_ [expr $pktSize + 40]

}


###################################### Multipathing #######################################
if {$enableMultiPath == 1} {
    $ns rtproto DV
    Agent/rtProto/DV set advertInterval [expr 10*$sim_end]
    Node set multiPath_ 1
    if {$perflowMP != 0} {
        Classifier/MultiPath set perflow_ 1
        Agent/TCP/FullTcp set dynamic_dupack_ 0; # enable duplicate ACK
    }
}

###################################### Topoplgy ######################3#####################
#Agent/TCP/FullTcp set dynamic_dupack_ 0; # enable duplicate ACK
#Agent/TCP/FullTcp set dynamic_dupack_ 100000; # enable duplicate ACK
Agent/TCP set rtxcur_init_ [expr 20 * $mean_rtt];
set debug_state 0
set connections_per_pair 1

puts "UCap: $UCap"

for {set i 0} {$i < $S} {incr i} {
    set s($i) [$ns node]
}

for {set i 0} {$i < $topology_tors} {incr i} {
    set n($i) [$ns node]
}

#set agg [$ns node]

for {set i 0} {$i < $topology_spines} {incr i} {
    set a($i) [$ns node]
}

############ Edge links ##############
for {set i 0} {$i < $S} {incr i} {
    set j [expr $i/$topology_spt]

	#if {$switchAlg == "DropTail/RWNDQ" || $switchAlg == "DropTail/RWNDSYNQ" || $switchAlg == "IQM" || $switchAlg == "DropTail"} {
	#	$ns duplex-link $s($i) $n($j) [set link_rate]Gb [expr $host_delay + $mean_link_delay] $switchAlg
		#$ns queue-limit $s($i) $n($j) [expr $queueSize * 10]
	#} else {
		$ns duplex-link $s($i) $n($j) [set link_rate]Gb [expr $host_delay + $mean_link_delay] $switchAlg
	#}

	if { $enableeqtr } {
		set qfile [$ns monitor-queue $ss($i) $n($j) [open "$tracedir/equeue$i-$j.tr" w] $queueSamplingInterval]
		[$ns link $ss($i) $n($j)] start-tracing; #queue-sample-timeout;
	}

    ########################### Ahmed ####################################
    if {$switchAlg == "DropTail/RWNDQ" || $switchAlg == "DropTail/RWNDSYNQ" || $switchAlg == "IQM"} {
        	$ns other-queue $ss($i) $n($j)
    #
    #    	#set  link1   [$ns link $s($i) $n($j)]
    #    	#set queue1     [$link1 queue]
    #    	#$queue1 set-link-capacity [[$link1 set link_] set bandwidth_];
    #    	#set  link2   [$ns link  $n($i) $s($j)]
    #    	#set queue2     [$link2 queue]
    #    	#$queue2 set-link-capacity [[$link2 set link_] set bandwidth_];
    }
}

############ Core links ##############
for {set i 0} {$i < $topology_tors} {incr i} {
   for {set j 0} {$j < $topology_spines} {incr j} {

       $ns duplex-link $n($i) $a($j) [set UCap]Gb $mean_link_delay $switchAlg

		if { $enablecqtr } {
			set qfile [$ns monitor-queue $n($i) $a($j) [open "$tracedir/cqueue$i-$j.tr" w] $queueSamplingInterval]
			[$ns link $n($i) $a($j)] start-tracing; #queue-sample-timeout;
		}

       ########################## Ahmed ####################################
       if {$switchAlg == "DropTail/RWNDQ" || $switchAlg == "DropTail/RWNDSYNQ" || $switchAlg == "IQM"} {
           	$ns other-queue $n($i) $a($j)

           	#set  link1   [$ns link $n($i) $a($j)]
           	#set queue1     [$link1 queue]
           	#$queue1 set-link-capacity [[$link1 set link_] set bandwidth_];
           	#set  link2   [$ns link  $a($i) $n($j)]
           	#set queue2     [$link2 queue]
           	#$queue2 set-link-capacity [[$link2 set link_] set bandwidth_];
       }
   }
}

#$ns duplex-link $agg $a([expr $topology_spines - 1]) [set UCap]Gb $mean_link_delay $switchAlg
##################################  Agents ############################################
set seed1 123450
set seed2 987650

#set meanFlowSize 138*1460;  ###re-adjust mean flow size to 138 packets

#set lambda [expr ($link_rate*$load*1000000000)/($meanFlowSize*8.0/1460*1500)]
set lambda [expr ($UCap*$load*1000000000)/($meanFlowSize*8.0/1460*1500)]
#set lambda [expr ($link_rate*$load*1000000000)/($mean_npkts*($pktSize+40)*8.0)]

puts "totalconnections: $tot_conn, mean_rtt: $mean_rtt"
puts "Arrival: Poisson with inter-arrival [expr 1/$lambda * 1000] ms per rack [expr 1/$lambda/$tot_conn * 1000] ms per pair"
puts "FlowSize: Pareto with mean = $meanFlowSize, shape = $paretoShape"

puts "Setting up connections ..."; flush stdout

set flow_gen 0
set flow_fin 0

set init_fid 1
for {set j 0} {$j < $S } {incr j} {
    for {set i 0} {$i < $S } {incr i} {
        if {$i != $j} {
                set agtagr($i,$j) [new Agent_Aggr_pair]
                $agtagr($i,$j) setup $s($i) $s($j) "$i $j" $connections_per_pair $init_fid "TCP_pair"
                $agtagr($i,$j) attach-logfile $flowlog

                puts -nonewline "($i,$j) -> $init_fid,"
				#puts  "($i,$j) -> $init_fid  "
                #For Poisson/Pareto
				if { $flow_cdf != "EXP" } {
					#$agtagr($i,$j) set_PCarrival_process [expr $lambda/($S - 1) ] $flow_cdf [expr 17*$i+1244*$j] [expr 33*$i+4369*$j]
					$agtagr($i,$j) set_PCarrival_process [expr $lambda ] $flow_cdf [expr $i * $seed1 + $j * $seed2]  [expr $i * $seed2 + $j * $seed1]
					
					#$agtagr($i,$j) set_PCarrival_process [expr $lambda / ($S-1) ] $flow_cdf [expr 17*$i+1244*$j] [expr 33*$i+4369*$j]
					#$agtagr($i,$j) set_PCarrival_process [expr $lambda ] $flow_cdf [expr 17*$i+1244*$j] [expr 33*$i+4369*$j]

				} else {
					$agtagr($i,$j) set_PEarrival_process [expr $lambda/($S - 1) ] [expr $meanFlowSize] [expr $i * $seed1 + $j * $seed2]  [expr $i * $seed2 + $j * $seed1]
				}
				#set testpair($i,$j) [new TCP_pair]
				#$testpair($i,$j) setup $s($i) $s($j) ;				

				#puts "going to WARM up after 0.2"
                #$ns at 0.1 "$agtagr($i,$j) warmup 0.5 5"
                $ns at 1 "$agtagr($i,$j) init_schedule"

                set init_fid [expr $init_fid + $connections_per_pair];
            }
        }
}

# for {set j 0} {$j < $S } {incr j} {
#     for {set i 0} {$i < $S } {incr i} {
#         if {$i != $j} {
#    			 for {set k 0} {$k < 1} {incr k} {
#                 set agtagr($i,$j) [new Agent_Aggr_pair]
#                 $agtagr($i,$j) setup $s($i) $s($j) "$i $j" $connections_per_pair $init_fid "TCP_pair"
#                 $agtagr($i,$j) attach-logfile $flowlog
#
#                 puts -nonewline "($i,$j) -> $init_fid,"
# 								#puts  "($i,$j) -> $init_fid  "
#                 #For Poisson/Pareto
# 						if { $flow_cdf != "EXP" } {
	# 					#$agtagr($i,$j) set_PCarrival_process [expr $lambda/($S - 1) ] $flow_cdf [expr 17*$i+1244*$j] [expr 33*$i+4369*$j]
	# 					$agtagr($i,$j) set_PCarrival_process [expr $lambda * ($S-1)] $flow_cdf [expr $i * $seed1 + $j * $seed2]  [expr $i * $seed2 + $j * $seed1]
	#
	# 					#$agtagr($i,$j) set_PCarrival_process [expr $lambda / ($S-1) ] $flow_cdf [expr 17*$i+1244*$j] [expr 33*$i+4369*$j]
	# 					#$agtagr($i,$j) set_PCarrival_process [expr $lambda ] $flow_cdf [expr 17*$i+1244*$j] [expr 33*$i+4369*$j]
	#
# 				} else {
# 					$agtagr($i,$j) set_PEarrival_process [expr $lambda/($S - 1) ] [expr $meanFlowSize] [expr $i * $seed1 + $j * $seed2]  [expr $i * $seed2 + $j * $seed1]
# 				}
# 				#set testpair($i,$j) [new TCP_pair]
# 				#$testpair($i,$j) setup $s($i) $s($j) ;
#
# 				#puts "going to WARM up after 0.2"
#                 $ns at 0.1 "$agtagr($i,$j) warmup 0.5 5"
#                 $ns at 1.0 "$agtagr($i,$j) init_schedule"
#
#                 set init_fid [expr $init_fid + $connections_per_pair];
#             }
#         }
#     }
# }

proc testnet {}  {
global ns init_fid S testpair myAgent s backg
set test_fid [expr $init_fid + 1]

#for {set j 0} {$j < $S } {incr j} {
#	for {set i 0} {$i < $S } {incr i} {
#		if {$i != $j} {
#				$testpair($i,$j) setgid "$i$i $j$j"
#				$testpair($i,$j) setpairid [expr $i * $j]     ;
#				$testpair($i,$j) setfid $test_fid  ;
#				$testpair($i,$j) start  100000000000;
#				incr test_fid
#				puts "TEST: TCP_pair $testpair($i,$j) of flow $test_fid started "
#
#		}
#	}
#}
	puts " --------------WARNING---------------"
	puts "Background flows has been Enabled"
	puts " " 
	
	set backg 1
	for {set i 0} {$i < $S } {incr i} {
		
		for {set j 0} {$j < $S } {incr j} {
			
			if {$i != $j} {
				
				set tcp_($i) [new $myAgent]
				set tcps_($j) [new $myAgent]
				$tcps_($j) listen

				$ns attach-agent $s($i) $tcp_($i)
				$ns attach-agent $s($j) $tcps_($j)
				
				$tcp_($i) set fid_ [expr $test_fid]
				$tcps_($j) set fid_ [expr $test_fid]

				$ns connect  $tcp_($i)  $tcps_($j)
				
				$ns at 0.99 "$tcp_($i) sendmsg -1 MSG_EOF" 
				$ns at 3 "$tcp_($i) close" 
				$ns at 3 "$tcps_($i) close" 
				#puts "connecting server $i to server $j"
				
				set test_fid [expr $test_fid + 1]
				
				
				
				#set ftp_($i) [new Application/FTP]
				#$ftp_($i) attach-agent $tcp_($i)

				#$ns at 0.9 "$ftp_($i) start"
				#$ns at 3.0 "$ftp_($i) stop"
				#$ns at 0.99 "$ftp_($i) send 10000000000"
			}
		}
		
	}
}

proc tcpTrace {} {
    global ns S agtagr mean_rtt cwndfile wndfile

    set now [$ns now]

    for {set i 0} {$i < $S} {incr i} {
		for {set j 0} {$j < $S} {incr j} {
			 if {$i != $j} {
				set tcppair [$agtagr($i,$j) set apair(0)]
				set tcp [$tcppair set tcps]
				set cwnd($i,$j) [$tcp set cwnd_]
				set wnd($i,$j) [$tcp set window_]
			 }
		}
    }

    puts -nonewline $cwndfile "$now "
	puts -nonewline $wndfile "$now "
	for {set i 0} {$i < $S} {incr i} {
		for {set j 0} {$j < $S} {incr j} {
			 if {$i != $j} {
				puts -nonewline $cwndfile " $cwnd($i,$j)"
				puts -nonewline $wndfile " $wnd($i,$j)"
			 }
		}
	}
	puts  $cwndfile " -1"
	puts  $wndfile " -1"

    $ns at [expr $now+ ($mean_rtt/8)] "tcpTrace"
}

proc flushtrace {}  {
	global ns sim_end enabletr enableNAM namfile trfile debug_state

	set tnow [$ns now]
	$ns flush-trace
	if { $debug_state >= 1} {
		puts "In FlushTrace -> Time: $tnow"
	}

	#if {$tnow > $sim_end} {
	#	if {$enableNAM != 0} {
	#    close $namfile
	#	}
	#	if {$enabletr != 0} {
	#		close $trfile
	#	}
	#
	#	exit 0;
	#}

	$ns at [expr $tnow + 0.1 ] "flushtrace"
}

proc check_unfinished {}  {
	global ns agtagr S

	set tnow [ns now]

	set allfinish 1
	if { $tnow < 10 } {
		for {set j 0} {$j < $S } {incr j} {
			for {set i 0} {$i < $S } {incr i} {
				if { $i != $j } {
						if { [$agtagr($i,$j) set finished] == 0 } {
							set allfinish  0
						}
				}
			}
		}
	}	else {
		set unfinf [open "$maindir/unfinflow.tr" w]
		for {set j 0} {$j < $S } {incr j} {
			for {set i 0} {$i < $S } {incr i} {
				if {$i != $j } {
					if { [$agtagr($i,$j) set finished] ==0 } {
						set apair [$agtagr($i,$j) set apair(0)]
						set fid [$apair set fid]
						set bytes [$apair set bytes]
						set fldur [expr $tnow - [$apair set start_time]]
						set rtnum [[$apair set tcps] set nrexmit_]
						puts "flow_stats: UNFIN:$flow_fin %tnow fid $fin_fid bytes $bytes rttimes $rtnum fldur $fldur"; flush stdout
						set tmp_pkts [expr $bytes / 1460.0]

						puts $unfinf "$tmp_pkts $fldur $rtnum $fid $tnow"; flush stdout
					}
				}
			}
		}
		puts "check_unfinished: calling finish now at time [ns now]"
		$ns at [expr [ns now] + 0.00000001] "finish"
		return
	}

	if { $allfinish == 0} {
        puts "Finish: did not reach 10 sec limit returning until called again  [ns now] [ expr [ns now] + 1.0 ] "
		$ns at [ expr [ns now] + 1.0 ] "check_unfinished"
        return
    }


}

proc endsim {}  {
	global ns

	set tnow [ns now]
	#if {$enableNAM != 0} {
	#    close $namfile
	#}
	#if {$enabletr != 0} {
	#	close $trfile
	#}
	puts "endsim: Ending now at time "

	exit 0;
}

proc finish {} {
    global ns flowlog flow_fin backg tcp_ tcps_
    global sim_start sim_end maindir
    global enableNAM namfile enabletr trfile tracedir
    
    if { $backg > 0 } {
	    for {set i 0} {$i < $S } {incr i} {		
		for {set j 0} {$j < $S } {incr j} {			
			if {$i != $j} {
    				$tcp_($i) close
					$tcps_($j) close
				}
			}
		}
	}
	
	set tnow [ns now]

    if { $flow_fin < [expr $sim_end * .97]} {
        puts "Finish: Did not finish 97% of flows returning until called again"
		$ns at [expr $tnow + $sim_end] "finish"
        return
    }

    $ns flush-trace
    close $flowlog

    puts "Ending now at time [ns now]"

    if {$enableNAM != 0} {
	    close $namfile
	}
	if {$enabletr != 0} {
		close $trfile
		puts "End of trace-all, file closed"
    }

    set t [clock seconds]
    puts "Simulation Finished!"; flush stdout
    puts "Time [expr $t - $sim_start] sec"; flush stdout

	#exec python result.py -a -i $maindir/flow.tr

    exit 0;
}


puts "Initial agent creation done"; flush stdout
puts "Simulation started!"

#$ns at 0.1 "flushtrace"
#$ns at 0.5 "testnet"
if { $enabletcptr == 1} {
	$ns at 1.1 "tcpTrace"
}

#$ns at 0.5 "check_unfinished"
$ns at $sim_end "finish"
$ns at [expr $sim_end * 10 + 0.5] "endsim"


#$ns at 0.0 "testnet"

#$ns at 1.5 "finish"

$ns run
