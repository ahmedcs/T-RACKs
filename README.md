# T-RACKs
T-RACKs is a Timely ACKs Retransmission mechanism designed to resolve the inadequacy problem of TCP Retransmission Timeout in data centre networks. 
Specifically, it aims at building a hypervisor based (end-to-end) scheme to accurately estimate the actual RTT measured at the hypervisor level and leverage the Fast Retransmit and Recovery mechanism by sending FAKE DUPACKs to the senders. 

It is implemented as a hardware prototype in Linux Kernel as a Load-able Kernel Module and NetFilter framework is used for packet interception.

# Installation Guide
Please Refer to the \[[InstallME](InstallME.md)\] file for more information about installation and possible usage scenarios.

# Running experiments

To run an experiment of T-RACKs, install T-RACKs on the end-hosts, download and install the traffic generator \[[Here](http://github.com/ahmedcs/Traffic_Generator)\] then issue the following:

```
cd experiments
./run_tracks.sh one 1110 1 7000 1000 conf/client_config_oneWEB.txt 172.16.0.1:8001 XMLRPC 1 28 0 0 0 1 0
```
Or to an experiment involving various parameters for the RTO and the elephant threshold
```
cd experiments
./run_tracks_varparam.sh one 1110 10 7000 1000 conf/client_config_oneWEB.txt 172.16.0.1:8001 XMLRPC 1 28 0 0 0 1 10 10000 10000000
```
For more details on the experiments, refer to the traffic generator installation at \[[Doc](http://github.com/ahmedcs/Traffic_Generator/InstallME.md)\]

#Feedback
I always welcome and love to have feedback on the program or any possible improvements, please do not hesitate to contact me by commenting on the code [Here](https://ahmedcs.github.io/HSCC-post/) or dropping me an email at [ahmedcs982@gmail.com](mailto:ahmedcs982@gmail.com). **PS: this is one of the reasons for me to share the software.**  

**This software will be constantly updated as soon as bugs, fixes and/or optimization tricks have been identified.**


# License
This software including (source code, scripts, .., etc) within this repository and its subfolders are licensed under CRAPL license.

**Please refer to the LICENSE file \[[CRAPL LICENCE](LICENSE)\] for more information**


# CopyRight Notice
The Copyright of this repository and its subfolders are held exclusively by "Ahmed Mohamed Abdelmoniem Sayed", for any inquiries contact me at ([ahmedcs982@gmail.com](mailto:ahmedcs982@gmail.com)).

Any USE or Modification to the (source code, scripts, .., etc) included in this repository has to cite the following PAPERS:  

```bibtex
@inproceedings{Ahmed-INFOCOM-2018,
	Author = {Ahmed {M. Abdelmoniem} and Brahim Bensaou},
	Booktitle = {IEEE INFOCOM},
	Title = {{Curbing Timeouts for TCP-Incast in Data Centers via A Cross-Layer Faster Recovery Mechanism}},
	Year = 2017}

@ARTICLE{TRACKS_TON_2021,
  author={Abdelmoniem, Ahmed M. and Bensaou, Brahim},
  journal={IEEE/ACM Transactions on Networking}, 
  title={{T-RACKs: A Faster Recovery Mechanism for TCP in Data Center Networks}}, 
  year={2021},
  volume={29},
  number={3},
}
```

**Notice, the COPYRIGHT and/or Author Information notice at the header of the (source, header and script) files can not be removed or modified.**


# Published Paper
To understand the framework and proposed solution, please read the paper \[[T-RACKs INFOCOM paper PDF](download/TRACKs-Paper.pdf)\] and technical report \[[T-RACKs Tech-Repo PDF](download/TRACKs-Report.pdf)\]
