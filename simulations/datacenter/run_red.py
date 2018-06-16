import threading
import os
import Queue
import subprocess
import pprint
import argparse

def worker():
	while True:
		try:
			j = q.get(block = 0)
		except Queue.Empty:
			return
		#Make directory to save results
		os.system('mkdir '+j[1])
		os.system(j[0])

q = Queue.Queue()
parser = argparse.ArgumentParser()
parser.add_argument("-f", "--file", help="CDF file or NONE if not used(required)")
parser.add_argument("-s", "--script", help="TCL Script file(required)")
parser.add_argument("-p", "--prefix", help="Prefix used for naming(required)")
parser.add_argument("-n", "--fnum", help="Number of flows for simulation(required, default=100000)", type=int, default=100000)
parser.add_argument("-c", "--capacity", help="capacity of edge link(required, default=10G)", type=int, default=10)
parser.add_argument("-o", "--over", help="over-subscription (optional, default=1)", type=float,default=1 )
parser.add_argument("-l", "--load", help="load in the network (optional)", type=float)
parser.add_argument("-t", "--npersist", help="persistent or non (required, default=0 (persistent))", type=int, default=0)
parser.add_argument("-x", "--spacing", help="TCP spacing  (required, default=0 (no pacing))", type=int, default=0)
parser.add_argument("-r", "--rack", help="Enable RACK module (optional, default=-1 (no rack components is added))", type=int, default=-1)
parser.add_argument("-m", "--minrto", help="Minimum RTO used in TCP (optional, default=0.002)", type=float, default=0.002)
parser.add_argument("-D", "--directory", help="change to directory (optional, default=.(current directory))", default='.')
parser.add_argument("-rn", "--racknumrtt", help="RACK number of RTT as Timeout (optional, default=10 (no rack components is added))", type=int, default=10)

args = parser.parse_args()

os.system('mkdir -p %s' % args.directory)


sim_end = args.fnum #100000
link_rate = args.capacity #10
mean_link_delay = 0.000040 #0.000010 #0.0000002
host_delay = 0.000010 #0.000020 #0.000020
queueSize = 100 #240
load_arr = [0.9, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3]
if args.load > 0.0:
	load_arr = [args.load]
connections_per_pair = 1
meanFlowSize = 138*1460 #1138*1460
paretoShape = 1.05
flow_cdf = args.file #'CDF_vl2.tcl'

if flow_cdf != "NONE":
	f = open(flow_cdf)
	val1 = []
	val2 = []
	for line in f.readlines():
		x = line.split()
		if len(x) < 2:
			continue
		print x[0] + '\t' + x[2]
		val1.append(float(x[0]))
		val2.append(float(x[2]))
	
	avg = 0
	for i in range(0, len(val1)):
			if i == 0:
				value = val1[i] / 2
				prob = val2[i]
			else:
				value = (val1[i] + val1[i-1]) / 2
				prob = val2[i] - val2[i-1]
			avg += (value * prob);
	print "CDF average flow size is %d" % avg
	meanFlowSize = avg  

enableMultiPath = 1
perflowMP = 0

sourceAlg = "TCP"
initWindow = 10
ackRatio = 1
slowstartrestart = 'true'
DCTCP_g = 0.0625
min_rto = args.minrto

switchAlg = "RED"
if link_rate == 10:
	DCTCP_K = 65.0
elif link_rate == 1:
	DCTCP_K = 15.0

ECN_scheme_ = 2 #Per-port ECN marking

topology_spt = 16
topology_tors = 9 #3 
topology_spines = 4 #2
topology_x = args.over

debug=0 ### 0 no debugging output, 1 for level-1 debugging, 2 for level 2 debugging
trace=0 ### 0 no tracing, 1 for trace TCP, 2 for trace-all, 3 for trace-all and queue monitor, 4 previous and NAM
npersist=args.npersist #### 0 for persistent, 1 for non-persistent (just reset), 2 for non-persistent close then open

spacing=args.spacing
if spacing:
	ns_source = 'source ~/pacing-ns-2.35.sh && env'
else:
	ns_source = 'source ~/ns-2.35.sh && env'
	
command = ['bash', '-c', ns_source]
proc = subprocess.Popen(command, stdout = subprocess.PIPE)
for line in proc.stdout:
  (key, _, value) = line.partition("=")
  os.environ[key] = value
proc.communicate()
pprint.pprint(dict(os.environ))
sim_script = args.script #'spine_empirical.tcl'

for i in range(len(load_arr)):
	
	scheme = 'unknown'
	if switchAlg == 'RED':
		scheme = 'red'
	if switchAlg == 'DropTail':
		scheme = 'droptail'

	if scheme == 'unknown':
		print 'Unknown scheme'
		sys.exit(0)	

	#Directory name: workload_scheme_load_[load]
	directory_name = '%s_%s_%d_%d_%d_%d_%d_%d' % (args.prefix, scheme, int(load_arr[i]*100), sim_end, link_rate, topology_x, npersist, args.rack)
	directory_name = directory_name.lower()
	directory_name = args.directory + "/" + directory_name
	os.system('rm -rf %s' % directory_name)

	#Simulation command
	#cmd = ns_path+' '\
	cmd = "( ns "+' '\
		+sim_script+' '\
		+str(sim_end)+' '\
		+str(link_rate)+' '\
		+str(mean_link_delay)+' '\
		+str(host_delay)+' '\
		+str(queueSize)+' '\
		+str(load_arr[i])+' '\
		+str(connections_per_pair)+' '\
		+str(meanFlowSize)+' '\
		+str(paretoShape)+' '\
		+str(flow_cdf)+' '\
		+str(enableMultiPath)+' '\
		+str(perflowMP)+' '\
		+str(sourceAlg)+' '\
		+str(initWindow)+' '\
		+str(ackRatio)+' '\
		+str(slowstartrestart)+' '\
		+str(DCTCP_g)+' '\
		+str(min_rto)+' '\
		+str(switchAlg)+' '\
		+str(DCTCP_K)+' '\
		+str(ECN_scheme_)+' '\
		+str(topology_spt)+' '\
		+str(topology_tors)+' '\
		+str(topology_spines)+' '\
		+str(topology_x)+' '\
		+str('./'+directory_name+'/flow.tr')+' '\
		+str(args.rack)+' '\
		+str(debug)+' '\
		+str(trace)+' '\
		+str(npersist)+' '\
		+str(spacing)+' '\
		+str(args.racknumrtt)+' '\
		+str('./'+directory_name)\
		+str(' ./'+directory_name)\
		+' > '\
		+str('./'+directory_name+'/logFile.tr )')\
		+' >& '\
		+str('./'+directory_name+'/errFile.tr')
		
	print cmd

	q.put([cmd, directory_name])

#Create all worker threads
threads = []
number_worker_threads = 20

#Start threads to process jobs
for i in range(number_worker_threads):
	t = threading.Thread(target = worker)
	threads.append(t)
	t.start()

#Join all completed threads
for t in threads:
	t.join()
