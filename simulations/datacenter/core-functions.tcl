#
# TCP pair's have
# - group_id = "src->dst"
# - pair_id = index of connection among the group
# - fid = unique flow identifier for this connection (group_id, pair_id)
#
set next_fid 0

Class TCP_pair

#Variables:
#tcps tcpr:  Sender TCP, Receiver TCP
#sn   dn  :  source/dest node which TCP sender/receiver exist
#:  (only for setup_wnode)
#delay    :  delay between sn and san (dn and dan)
#:  (only for setup_wnode)
#san  dan :  nodes to which sn/dn are attached
#aggr_ctrl:  Agent_Aggr_pair for callback
#start_cbfunc:  callback at start
#fin_cbfunc:  callback at fin
#group_id :  group id
#pair_id  :  group id
#fid       :  flow id
#Public Functions:
#setup{snode dnode}       <- either of them
#setup_wnode{snode dnode} <- must be called
#setgid {gid}             <- if applicable (default 0)
#setpairid {pid}          <- if applicable (default 0)
#setfid {fid}             <- if applicable (default 0)
#start { nr_bytes } ;# let start sending nr_bytes
#set_debug_mode { mode }    ;# change to debug_mode
#setcallback { controller } #; only Agent_Aggr_pair uses to
##; registor itself
#fin_notify {}  #; Callback .. this is called
##; by agent when it finished
#Private Function
#flow_finished {} {

#Agent/TCP/FullTcp set dynamic_dupack_ 100000.0

TCP_pair instproc init {args} {
    $self instvar pair_id group_id id debug_mode rttimes frtimes racktimes debug_mode
    $self instvar tcps tcpr;# Sender TCP,  Receiver TCP
    global myAgent debug_state
    eval $self next $args

    $self set tcps [new $myAgent]  ;# Sender TCP
    $self set tcpr [new $myAgent]  ;# Receiver TCP
    
    #$tcps set [$tcps set dynamic_dupack_] 100000.0
    #$tcpr set [$tcpr set dynamic_dupack_] 100000.0

    $tcps set_callback $self
    #$tcpr set_callback $self

    $self set pair_id  0
    $self set group_id 0
    $self set id       0
    $self set debug_mode $debug_state
    $self set rttimes 0
    $self set frtimes 0
	$self set racktimes 0
    
	if { $debug_mode >= 2 } {
        puts "TCP_Pair: Init successfully using $myAgent s_dynamic_dup [$tcps set dynamic_dupack_] r_dynamic_dup [$tcpr set dynamic_dupack_]"; flush stdout
	}
}

TCP_pair instproc set_debug_mode { mode } {
    $self instvar debug_mode
    $self set debug_mode $mode
}


TCP_pair instproc setup {snode dnode} {
#Directly connect agents to snode, dnode.
#For faster simulation.
    global ns link_rate enablerack eleph eleph_thresh mean_rtt rackrttnum
    $self instvar tcps tcpr;# Sender TCP,  Receiver TCP
    $self instvar san dan  ;# memorize dumbell node (to attach)
    $self instvar debug_mode
    
    $self set san $snode
    $self set dan $dnode

    $ns attach-agent $snode $tcps;
    $ns attach-agent $dnode $tcpr;
    
    if { $enablerack == 1 } {
    		$tcps set-debug  0;
	    	$tcps set-rack $enablerack
	    	$tcps set-eleph $eleph
	    	$tcps set-elephthresh $eleph_thresh
			$tcps set-vmdelay 0.0; #[expr $host_delay + $mean_link_delay];
			$tcps set-RTT  $mean_rtt
			if {$rackrttnum > 0} {
				#puts "RACK RTTNUM has been changed to $rackrttnum"
				$tcps set-RTTNum $rackrttnum
			}	
	}

    ### Connect in start or warm up before start sending
    $tcpr listen
    $ns connect $tcps $tcpr
    
    if { $debug_mode >= 2 } {
        #puts "TCP_Pair: Connect successfully using between $tcps $tcpr"; flush stdout
    }

}

TCP_pair instproc create_agent {} {
    $self instvar tcps tcpr;# Sender TCP,  Receiver TCP
    $self set tcps [new Agent/TCP/FullTcp/Sack]  ;# Sender TCP
    $self set tcpr [new Agent/TCP/FullTcp/Sack]  ;# Receiver TCP
}

TCP_pair instproc setup_wnode {snode dnode link_dly} {

#New nodes are allocated for sender/receiver agents.
#They are connected to snode/dnode with link having delay of link_dly.
#Caution: If the number of pairs is large, simulation gets way too slow,
#and memory consumption gets very very large..
#Use "setup" if possible in such cases.

    global ns link_rate enablerack eleph eleph_thresh mean_rtt rackrttnum
    $self instvar sn dn    ;# Source Node, Dest Node
    $self instvar tcps tcpr;# Sender TCP,  Receiver TCP
    $self instvar san dan  ;# memorize dumbell node (to attach)
    $self instvar delay    ;# local link delay

    $self set delay link_dly

    $self set sn [$ns node]
    $self set dn [$ns node]

    $self set san $snode
    $self set dan $dnode

    $ns duplex-link $snode $sn  [set link_rate]Gb $delay  DropTail
    $ns duplex-link $dn $dnode  [set link_rate]Gb $delay  DropTail

    $ns attach-agent $sn $tcps;
    $ns attach-agent $dn $tcpr;
    
    # if { $enablerack == 1 } {
# 	    $tcps set-rack $enablerack
# 	    $tcps set-eleph $eleph
# 	    $tcps set-elephthresh $eleph_thresh
# 	    $tcps set-vmdelay 0.0; #[expr $host_delay + $mean_link_delay];
# 	    $tcps set-RTT  $mean_rtt	    		
# 		#$tcps set-debug  1;
# 		if {$RTTNum > 0} {
# 			$tcps set-RTTNum $rackrttnum
# 		}
# 	}

    $tcpr listen
    $ns connect $tcps $tcpr
}

TCP_pair instproc set_fincallback { controller func} {
    $self instvar aggr_ctrl fin_cbfunc
    $self set aggr_ctrl  $controller
    $self set fin_cbfunc  $func
}

TCP_pair instproc set_startcallback { controller func} {
    $self instvar aggr_ctrl start_cbfunc
    $self set aggr_ctrl $controller
    $self set start_cbfunc $func
}

TCP_pair instproc setgid { gid } {
    $self instvar group_id
    $self set group_id $gid
}

TCP_pair instproc setpairid { pid } {
    $self instvar pair_id
    $self set pair_id $pid
}

TCP_pair instproc setfid { fid } {
    $self instvar tcps tcpr
    $self instvar id
    $self set id $fid
    $tcps set fid_ $fid;
    $tcpr set fid_ $fid;
    
    #puts "flow id: $id TCPs [$tcps set fid_] TCPr:  [$tcpr set fid_] "; flush stdout;

}

TCP_pair instproc settbf { tbf } {
    global ns
    $self instvar tcps tcpr
    $self instvar san
    $self instvar tbfs

    $self set tbfs $tbf
    $ns attach-tbf-agent $san $tcps $tbf
}


TCP_pair instproc set_debug_mode { mode } {
    $self instvar debug_mode
    $self set debug_mode $mode
}
TCP_pair instproc start { nr_bytes } {
    global ns sim_end flow_gen npersist
    $self instvar tcps tcpr id group_id
    $self instvar start_time bytes
    $self instvar aggr_ctrl start_cbfunc

    $self instvar debug_mode

    $self set start_time [$ns now] ;# memorize
    $self set bytes       $nr_bytes  ;# memorize
    
    ##################RACK######################   
    #set [$tcps set cwnd_] 10
	#set [$tcpr set cwnd_] 10
	
	#puts "TCP_Pair: Start successfully s_dynamic_dup [$tcps set dynamic_dupack_] r_dynamic_dup [$tcpr set dynamic_dupack_]"; flush stdout

     ##################RACK######################


    if { $flow_gen >= $sim_end } {
        if { $debug_mode >= 2 } {
            puts "TCPpair: start but returning because $flow_gen > $sim_end"; flush stdout
       }
       return
    }
    
    if { $start_time >= 0.2 } {
        if { $debug_mode >= 2 } {
            puts "TCPPair: Advancing $flow_gen by 1"; flush stdout
        }
        set flow_gen [expr $flow_gen + 1]   
    }

    if { $debug_mode >= 1 } {
        puts "TCPPair: in start, [$ns now] grp $group_id fid $id $nr_bytes bytes"; flush stdout
    }
    
    ##################Non-Persistent Connect#####################
    if { $npersist == 2 } {
        $tcpr listen
        $ns connect $tcps $tcpr
        if { $debug_mode >= 1 } {
            puts "TCPPair:in start,  Non-Persistent mode connect pairs of flow $id"; flush stdout
        }
    }
    ##################Non-Persistent Connect#####################
    
    if { [info exists aggr_ctrl] } {
        $aggr_ctrl $start_cbfunc
    }

    $tcpr set flow_remaining_ [expr $nr_bytes]
    $tcps set signal_on_empty_ TRUE   

    $tcps advance-bytes $nr_bytes
    
    if { $debug_mode >= 1 } {
        puts "TCPPair: flow $id will advanced by $nr_bytes bytes"; flush stdout
    } 
}

TCP_pair instproc warmup { nr_pkts } {
    global ns npersist
    $self instvar tcps tcpr id group_id

    $self instvar debug_mode

    set pktsize [$tcps set packetSize_]

    if { $debug_mode >= 1 } {
        puts "TCPPair: in warm-up, [$ns now] start grp $group_id fid $id $nr_pkts pkts ($pktsize +40)"; flush stdout
    }
    
    if { $debug_mode >= 2 } {
        puts "TCPPair: warm up Sender will advance by $nr_pkts bytes"; flush stdout
    }
    
    ##################Non-Persistent Connect#####################
    if { $npersist == 2 } {
        $tcpr listen
        $ns connect $tcps $tcpr
    }
    ##################Non-Persistent Connect#####################
    
    $tcps advanceby $nr_pkts
}


TCP_pair instproc stop {} {
    $self instvar tcps tcpr

    $tcps reset
    $tcpr reset
}

TCP_pair instproc fin_notify {} {
    global ns npersist
    $self instvar sn dn san dan rttimes frtimes racktimes
    $self instvar tcps tcpr
    $self instvar aggr_ctrl fin_cbfunc
    $self instvar pair_id
    $self instvar bytes
    $self instvar id
    $self instvar debug_mode

    $self instvar dt
    $self instvar bps
    
    ####call flow finished to process this event
    $self flow_finished

    #Shuang
    set old_rttimes $rttimes
    set old_frtimes $frtimes
    set old_racktimes $racktimes
    $self set rttimes [$tcps set nrexmit_]
    $self set frtimes [$tcps set nfrexmitpack_]
    $self set racktimes [$tcps set rack_fr_]
    
    if { $debug_mode >= 2 } {
    	puts "AGGR-RACK: fin_notify TCP pairs id:$id time:$dt rate:$bps RACKFR: $racktimes \n"; flush stdout;
	}
    
    #
    # Mohammad commenting these
    # for persistent connections
    #
    ################# Ahmed  ####################
    if { $npersist } {
        if { $debug_mode >= 1 } {
            puts "NON-Persistent: In fin_notify Resetting the TCP pairs id:$id time:$dt rate:$bps\n"; flush stdout;
        }
        ### Reset the end-points for later possible connections
        if { $npersist == 1 } {
            $tcps reset
            $tcpr reset
        } elseif { $npersist == 2 } {
            ### call TCP close for end-points
            $tcps close
            $tcpr close
        }        
    }
    #################### Ahmed ######################
    if { [info exists aggr_ctrl] } {
	      $aggr_ctrl $fin_cbfunc $pair_id $bytes $dt $bps [expr $rttimes - $old_rttimes] [expr $frtimes - $old_frtimes] $racktimes ; #[expr $racktimes - $old_racktimes]
    }
}

TCP_pair instproc flow_finished {} {
    global ns
    $self instvar start_time bytes id group_id
    $self instvar dt bps
    $self instvar debug_mode

    set ct [$ns now]
    #Shuang commenting these
    $self set dt  [expr $ct - $start_time]
    if { $dt == 0 } {
		puts "TCPPair: something is wrong, flow finished in dt = 0"; flush stdout
        return
	}
    $self set bps [expr $bytes * 8.0 / $dt ]

    if { $debug_mode >= 1 } {
	    puts "stats: $ct fin grp $group_id fid $id fldur $dt sec $bps bps"; flush stdout
    }
}

Agent/TCP/FullTcp instproc set_callback {tcp_pair} {
    $self instvar ctrl
    $self set ctrl $tcp_pair
}

Agent/TCP/FullTcp instproc done_data {} {
    global ns sink
    $self instvar ctrl    
    
	#puts "[$ns now] $self fin-ack received"; flush stdout
	if { [info exists ctrl] } {
			$ctrl fin_notify
	}
	
}

Class Agent_Aggr_pair
#Note:
#Contoller and placeholder of Agent_pairs
#Let Agent_pairs to arrives according to
#random process.
#Currently, the following two processes are defined
#- PParrival:
#flow arrival is poissson and
#each flow contains pareto
#distributed number of packets.
#- PEarrival
#flow arrival is poissson and
#each flow contains pareto
#distributed number of packets.
#- PBarrival
#flow arrival is poissson and
#each flow contains bimodal
#distributed number of packets.

#Variables:#
#apair:    array of Agent_pair
#nr_pairs: the number of pairs
#rv_flow_intval: (r.v.) flow interval
#rv_nbytes: (r.v.) the number of bytes within a flow
#last_arrival_time: the last flow starting time
#logfile: log file (should have been opend)
#stat_nr_finflow ;# statistics nr  of finished flows
#stat_sum_fldur  ;# statistics sum of finished flow durations
#last_arrival_time ;# last flow arrival time
#actfl             ;# nr of current active flow

#Public functions:
#attach-logfile {logf}  <- call if want logfile
#setup {snode dnode gid nr} <- must
#set_PParrival_process {lambda mean_nbytes shape rands1 rands2}  <- call either
#set_PEarrival_process {lambda mean_nbytes rands1 rands2}        <-
#set_PBarrival_process {lambda mean_nbytes S1 S2 rands1 rands2}  <- of them
#init_schedule {}       <- must

#fin_notify { pid bytes fldur bps } ;# Callback
#start_notify {}                   ;# Callback

#Private functions:
#init {args}
#resetvars {}


Agent_Aggr_pair instproc init {args} {
    global debug_state
    eval $self next $args
    $self instvar debug_mode
    
    set debug_mode $debug_state
    if { $debug_mode >= 2 } {
        puts "AGGR_Pair: Init successfully using $args"; flush stdout
    }
}


Agent_Aggr_pair instproc attach-logfile { logf } {
#Public
    $self instvar logfile
    $self set logfile $logf
}

Agent_Aggr_pair instproc setup {snode dnode gid nr init_fid agent_pair_type} {
#Public
#Note:
#Create nr pairs of Agent_pair
#and connect them to snode-dnode bottleneck.
#We may refer this pair by group_id gid.
#All Agent_pairs have the same gid,
#and each of them has its own flow id: init_fid + [0 .. nr-1]
    #global next_fid
    
    $self instvar apair     ;# array of Agent_pair
    $self instvar group_id  ;# group id of this group (given)
    $self instvar nr_pairs  ;# nr of pairs in this group (given)
    $self instvar s_node d_node apair_type ;
    $self instvar debug_mode
    $self instvar fid
    $self instvar finished; #boolean if the pair has finished or not
    
    $self set finished 0
    $self set group_id $gid
    $self set nr_pairs $nr
    $self set s_node $snode
    $self set d_node $dnode
    $self set apair_type $agent_pair_type
    
    $self set fid $init_fid        
 
    for {set i 0} {$i < $nr_pairs} {incr i} {
 	      $self set apair($i) [new $agent_pair_type]
 	      #puts "AGGR_Pair: Setup using $nr $init_fid $agent_pair_type"; flush stdout
          $apair($i) setup $snode $dnode
          $apair($i) setgid $group_id  ;# let each pair know our group id
          $apair($i) setpairid $i      ;# let each pair know his pair id
          $apair($i) setfid $init_fid  ;# Mohammad: assign next fid
          incr init_fid
    }
    $self resetvars                  ;# other initialization

    if { $debug_mode >= 2 } {
        puts "AGGR_Pair: Setup successfully using $nr $init_fid $agent_pair_type"; flush stdout
    }

}


set warmupRNG [new RNG]
$warmupRNG seed 5251

Agent_Aggr_pair instproc warmup {jitter_period npkts} {
    global ns warmupRNG
    $self instvar nr_pairs apair debug_mode

    if { $debug_mode >= 2 } {
        puts "AGGRWARM: going to call warm on TCP_Pairs $nr_pairs"; flush stdout
    }
    for {set i 0} {$i < $nr_pairs} {incr i} {
        set wtime [$warmupRNG uniform 0.0 $jitter_period]
        #set pairid [$apair($i) set id]
	    $ns at [expr [$ns now] + $wtime ] "$apair($i) warmup $npkts"
        if { $debug_mode >= 2 } {
            puts "WARMUPCALLED: numpkts $npkts time $wtime"; flush stdout
        }
    }
}

Agent_Aggr_pair instproc init_schedule {} {
#Public
#Note:
#Initially schedule flows for all pairs
#according to the arrival process.
    global ns
    $self instvar nr_pairs apair debug_mode

    # Mohammad: initializing last_arrival_time
    #$self instvar last_arrival_time
    #$self set last_arrival_time [$ns now]
    $self instvar tnext rv_flow_intval

    set dt [$rv_flow_intval value]

    $self set tnext [expr [$ns now] + $dt ]

    if { $debug_mode >= 2 } {
        puts "AGGR: in init_schedule, going to call schedule on TCP_Pairs $nr_pairs at time $tnext"; flush stdout
    }
    for {set i 0} {$i < $nr_pairs} {incr i} {

        #### Callback Setting ########################
        $apair($i) set_fincallback $self   fin_notify
        $apair($i) set_startcallback $self start_notify
        ###############################################
    
        $self schedule $i
        if { $debug_mode >= 2 } {
            puts "AGGR: in init_schedule, schedule called on TCP_Pairs $i at time [ns now]"; flush stdout
        }

    }
}


Agent_Aggr_pair instproc resetvars {} {
#Private
#Reset variables
    global npersist
    $self instvar fid             ;# current flow id of this group
    $self instvar tnext           ;# last flow arrival time
    $self instvar actfl           ;# nr of current active flow
    $self instvar debug_mode

    $self set tnext 0.0
    $self set actfl 0
    if { $npersist } {
        #$self set fid 0 ;#  flow id starts from 0
        if { $debug_mode >= 2 } {
            puts "NON-Persistent: In Reset_Vars Resetting the TCP pairs $fid"; flush stdout
        }
    }
}

Agent_Aggr_pair instproc schedule { pid } {
#Private
#Note:
#Schedule  pair (having pid) next flow time
#according to the flow arrival process.

    global ns flow_gen sim_end npersist
    $self instvar apair
    $self instvar fid
    $self instvar tnext
    $self instvar rv_flow_intval rv_nbytes
    $self instvar debug_mode
    
    if { $debug_mode >= 2 } {
    	puts "AGGR: in schdeule, $flow_gen $sim_end"; flush stdout
    }

    if {$flow_gen >= $sim_end} {
        puts "AGGR: in schdeule, exceeded target sim flows already $flow_gen $sim_end"; flush stdout
        flush stdout
        #$ns finish
        return
    }

    set t [$ns now]

    if { $t > $tnext } {
        puts "AGGR: in schedule, Not enough flows ! Aborting! pair id $pid t: $t tnex: $tnext fg: $flow_gen se: $sim_end"; flush stdout
        #$ns at [$ns now] "finish"
        #exit 0;
    }

    # Mohammad: persistent connection.. don't
    # need to set fid each time
    if { $npersist } {
        #$apair($pid) setfid $fid
        if { $debug_mode >= 1 } {
            set pairfid [$apair($pid) set id]
            puts "AGGR: in schedule Non-persistent mode, setting the TCP pairs id:$pairfid"; flush stdout
            #$self set fid 0 ;#  flow id starts from 0
        }
        #incr fid
    }
    
    set tmp_ [expr ceil([$rv_nbytes value])]
    if { $debug_mode >= 2 } {
    	puts "AGGR: in schedule, calling pair:$apair($pid) start sending $tmp_ at $tnext"; flush stdout
    }
    #set tmp_ [expr $tmp_ * 1460]
    $ns at $tnext "$apair($pid) start $tmp_"

    set dt [$rv_flow_intval value]
    $self set tnext [expr $tnext + $dt]
    
    ### Check_if_behind checks if a request is slow and needs more connections to finish 
    if { $debug_mode >= 2 } {
    	puts "AGGR: in Schedule, calling check_if_behind at [expr $tnext - 0.0000000001]"; flush stdout
    }
    #$ns at [expr $tnext - 0.0000000001] "$self check_if_behind"
}

Agent_Aggr_pair instproc check_if_behind {} {
    global ns
    global flow_gen sim_end
    $self instvar apair
    $self instvar nr_pairs
    $self instvar apair_type s_node d_node group_id
    $self instvar tnext
    $self instvar debug_mode

    set t [$ns now]
    if { $flow_gen < $sim_end && $tnext < [expr $t + 0.0000002] } {
        ###if $flow_fin < $sim_end && $tnext < [expr $t + 0.0000002]
        #create new flow
        if { $debug_mode >= 2 } {
        	puts "[$ns now]: creating new connection $nr_pairs $s_node -> $d_node" ; flush stdout
		}
        $self set apair($nr_pairs) [new $apair_type]
        $apair($nr_pairs) setup $s_node $d_node
        $apair($nr_pairs) setgid $group_id
    
        #### Callback Setting #################
        $apair($nr_pairs) set_fincallback $self fin_notify
        $apair($nr_pairs) set_startcallback $self start_notify
        #######################################
        $self schedule $nr_pairs
        incr nr_pairs
	}

}


Agent_Aggr_pair instproc fin_notify { pid bytes fldur bps rttimes frtimes racktimes } {
#Callback Function
#pid  : pair_id
#bytes : nr of bytes of the flow which has just finished
#fldur: duration of the flow which has just finished
#bps  : avg bits/sec of the flow which has just finished
#Note:
#If we registor $self as "setcallback" of
#$apair($id), $apair($i) will callback this
#function with argument id when the flow between the pair finishes.
#i.e.
#If we set:  "$apair(13) setcallback $self" somewhere,
#"fin_notify 13 $bytes $fldur $bps" is called when the $apair(13)'s flow is finished.
#
    global ns flow_gen flow_fin sim_end
    $self instvar logfile
    $self instvar group_id
    $self instvar actfl
    $self instvar apair
    $self instvar debug_mode
    $self instvar finished
    
    #Here, we re-schedule $apair($pid).
    #according to the arrival process.

    $self set actfl [expr $actfl - 1]
    $self set finished 1
    
    set fin_fid [$apair($pid) set id]

    ###### OUPUT STATISTICS #################
    if { [info exists logfile] } {
        
        #puts $logfile "flow_stats: [$ns now] gid $group_id pid $pid fid $fin_fid bytes $bytes fldur $fldur actfl $actfl bps $bps"
        puts "flow_stats: FIN:$flow_fin [$ns now] gid $group_id pid $pid fid $fin_fid bytes $bytes fldur $fldur actfl $actfl bps $bps TO $rttimes FR $frtimes RACK: $racktimes"; flush stdout
        set tmp_pkts [expr $bytes / 1460.0]

		#puts $logfile "$tmp_pkts $fldur $rttimes"
		puts $logfile "$tmp_pkts $fldur $rttimes $group_id $bps $fin_fid [$ns now] $frtimes $racktimes"; flush stdout
    }
    set flow_fin [expr $flow_fin + 1]
    if { $flow_fin >= $sim_end } {
        puts "AGGR: in fin_notify, active: $actfl not rescheduling -> $flow_fin > $sim_end, calling finish procedure now"; flush stdout
        $ns at [$ns now] "finish"
        #exit 0;
    }
    if {$flow_gen < $sim_end } {
    	if { $debug_mode >= 1 } {
        	puts "AGGR: FIN->Reschedule flow $fin_fid, active:$actfl ->  $flow_gen < $sim_end"; flush stdout
        }
        #$self schedule $pid ;# re-schedule a pair having pair_id $pid.
    }
}

Agent_Aggr_pair instproc start_notify {} {
#Callback Function
#Note:
#If we registor $self as "setcallback" of
#$apair($id), $apair($i) will callback this
#function with argument id when the flow between the pair finishes.
#i.e.
#If we set:  "$apair(13) setcallback $self" somewhere,
#"start_notyf 13" is called when the $apair(13)'s flow is started.
    $self instvar actfl;
    incr actfl;
}




Agent_Aggr_pair instproc set_PParrival_process {lambda mean_nbytes shape rands1 rands2} {
#Public
#setup random variable rv_flow_intval and rv_nbytes.
#To get the r.v.  call "value" function.
#ex)  $rv_flow_intval  value

#- PParrival:
#flow arrival: poissson with rate $lambda
#flow length : pareto with mean $mean_nbytes bytes and shape parameter $shape.

    $self instvar rv_flow_intval rv_nbytes

    set pareto_shape $shape
    set rng1 [new RNG]

    $rng1 seed $rands1
    $self set rv_flow_intval [new RandomVariable/Exponential]
    $rv_flow_intval use-rng $rng1
    $rv_flow_intval set avg_ [expr 1.0/$lambda]

    set rng2 [new RNG]
    $rng2 seed $rands2
    $self set rv_nbytes [new RandomVariable/Pareto]
    $rv_nbytes use-rng $rng2
    #$rv_nbytes set avg_ $mean_nbytes
    #Shuang: hack for pkt oriented
    $rv_nbytes set avg_ [expr $mean_nbytes]
    $rv_nbytes set shape_ $pareto_shape
}

Agent_Aggr_pair instproc set_PEarrival_process {lambda mean_nbytes rands1 rands2} {

#setup random variable rv_flow_intval and rv_nbytes.
#To get the r.v.  call "value" function.
#ex)  $rv_flow_intval  value

#- PEarrival
#flow arrival: poissson with rate lambda
#flow length : exp with mean mean_nbytes bytes.

    $self instvar rv_flow_intval rv_nbytes

    set rng1 [new RNG]
    $rng1 seed $rands1

    $self set rv_flow_intval [new RandomVariable/Exponential]
    $rv_flow_intval use-rng $rng1
    $rv_flow_intval set avg_ [expr 1.0/$lambda]


    set rng2 [new RNG]
    $rng2 seed $rands2
    $self set rv_nbytes [new RandomVariable/Exponential]
    $rv_nbytes use-rng $rng2
    $rv_nbytes set avg_ $mean_nbytes
}
Agent_Aggr_pair instproc set_PCarrival_process {lambda cdffile rands1 rands2} {
#public
##setup random variable rv_flow_intval and rv_npkts.
#
#- PCarrival:
#flow arrival: poisson with rate $lambda
#flow length: custom defined expirical cdf

    $self instvar rv_flow_intval rv_nbytes debug_mode

    set rng1 [new RNG]
    $rng1 seed $rands1

    $self set rv_flow_intval [new RandomVariable/Exponential]
    $rv_flow_intval use-rng $rng1
    $rv_flow_intval set avg_ [expr 1.0/$lambda]

    set rng2 [new RNG]
    $rng2 seed $rands2

    $self set rv_nbytes [new RandomVariable/Empirical]
    $rv_nbytes use-rng $rng2
    $rv_nbytes set interpolation_ 2
    $rv_nbytes loadCDF $cdffile
    
    if { $debug_mode >= 2 } {
        puts "PCarrival Setup up successfully inter=$lambda size=$cdffile"; flush stdout
    }
    
}

Agent_Aggr_pair instproc set_LCarrival_process {lambda cdffile rands1 rands2} {
#public
##setup random variable rv_flow_intval and rv_npkts.
#
#- PCarrival:
#flow arrival: lognormal with rate $lambda
#flow length: custom defined expirical cdf

    $self instvar rv_flow_intval rv_nbytes debug_mode

    set rng1 [new RNG]
    $rng1 seed $rands1

    $self set rv_flow_intval [new RandomVariable/LogNormal]
    $rv_flow_intval use-rng $rng1
    $rv_flow_intval set avg_ [expr 0.5 * log(1.0/($lambda*$lambda) / 5.0)]
    $rv_flow_intval set std_ [expr sqrt(log(5.0))]

    set rng2 [new RNG]
    $rng2 seed $rands2

    $self set rv_nbytes [new RandomVariable/Empirical]
    $rv_nbytes use-rng $rng2
    $rv_nbytes set interpolation_ 2
    $rv_nbytes loadCDF $cdffile
    
    if { $debug_mode >= 1 } {
        puts "LCarrival Setup up successfully inter=[$rv_flow_intval set avg_] size=$cdffile"; flush stdout
    }
}

Agent_Aggr_pair instproc set_PBarrival_process {lambda mean_nbytes S1 S2 rands1 rands2} {
#Public
#setup random variable rv_flow_intval and rv_nbytes.
#To get the r.v.  call "value" function.
#ex)  $rv_flow_intval  value

#- PParrival:
#flow arrival: poissson with rate $lambda
#flow length : Binomial with mean $mean_nbytes bytes and shape parameter $shape.

    $self instvar rv_flow_intval rv_nbytes debug_mode

    set rng1 [new RNG]

    $rng1 seed $rands1
    $self set rv_flow_intval [new RandomVariable/Exponential]
    $rv_flow_intval use-rng $rng1
    $rv_flow_intval set avg_ [expr 1.0/$lambda]

    set rng2 [new RNG]

    $rng2 seed $rands2
    $self set rv_nbytes [new RandomVariable/Binomial]
    $rv_nbytes use-rng $rng2

    $rv_nbytes set p1_ [expr  (1.0*$mean_nbytes - $S2)/($S1-$S2)]
    $rv_nbytes set s1_ $S1
    $rv_nbytes set s2_ $S2

    set p [expr  (1.0*$mean_nbytes - $S2)/($S1-$S2)]
    if { $p < 0 } {
        puts "In PBarrival, prob for bimodal p_ is negative %p_ exiting.. "; flush stdout
        flush stdout
        exit 0
    }
    else {
    	puts "# PBarrival S1: $S1 S2: $S2 p_: $p mean $mean_nbytes"
    }
    
    if { $debug_mode >= 1 } {
        puts "PBarrival Setup up successfully inter=[$rv_flow_intval set avg_] size=[$rv_nbytes set p1_]"; flush stdout
    }
}

Agent_Aggr_pair instproc set_PFarrival_process {lambda mean_nbytes rand1 rand2} {
#public
#fixed interval
#fixed flow size

  $self instvar rv_flow_intval rv_nbytes debug_mode

  set rng1 [new RNG]
  $rng1 seed $rand1
  $self set rv_flow_intval [new RandomVariable/Exponential]
  $rv_flow_intval use-rng $rng1
  $rv_flow_intval set avg_ [expr 1.0/$lambda]

  set rng2 [new RNG]
  $rng2 seed $rand2
  $self set rv_nbytes [new RandomVariable/Uniform]
  $rv_nbytes use-rng $rng2
  $rv_nbytes set min_ [expr $mean_nbytes / 10.0]
  $rv_nbytes set max_ [expr $mean_nbytes * 10.0]

 if { $debug_mode >= 1 } {
        puts "PFarrival Setup up successfully inter=[$rv_flow_intval set avg_] size=[$rv_nbytes set min_] [$rv_nbytes set max_]"; flush stdout
    }

}