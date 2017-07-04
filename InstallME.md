# Makefile update
If the source file has been changed, you need to update the name of the object file to match the new source file containing the module init_module and exit_module macros and the definition functions. SEE Makefile for more information.

Notice, you can include other source and header files but under the condition that there are a single source file containing the neccessary init_module and exit_module macros and their function.

# Installation steps

change your current directory to to where the source and Makefile is located then issue:

```
git clone https://github.com/ahmedcs/T-RACKs.git
cd Kernel_Module
make
```

Now the output files is as follows:
```
tracks.o and racks.ko
```
The file ending with .o is the object file while the one ending in .ko is the module file


# Run
To install the module into the kernel
```
sudo insmode tracks.ko 
```

Note that the parameters of the module are:  

--Main arguments  
 
1. debug: 0 to disable and > 0 to enable various level of debugging
2. enable: Enable the core functions T-RACKs module  
3. rtoinms: The T-RACKs specific RTO which suits the network based on measurements (10 times the RTT should be enough)  
4. maxackno: The maximum number of bytes (ack number) to use as an elephant threshold when exceeded the flow is identified as elephant
5. port: The TCP port number of applications that needs to be tracked, 0 is the default which tracks all ports.  
 
----Optional 
 
6. drops: If set the module at the end-hosts will drop number of the packets equal to this parameter
7. dropsize: If drops is set, then this is the number of packets to drop starting from the position defined by drops 
8. burst: If drops is set, then this is if set will drop the packets defined by size in burst, otherwise a total dropsize packets will be dropped in a random positions. 
 
However to call the module with different parameters issue the following: 
```
sudo insmod tracks.ko port=80 enable=1 rtoinms=1 maxacno=0 debug=0;
```
 
To set the parameters after installing the module, set the value in the parameters section of the module in kernel. 
For instance, to enable the module by setting the enable parameter, call the following 
```
sudo echo 1 > /sys/module/tracks/parameters/enable;
```

# Stop

To stop the tracks module and free the resources issue the following command:

```
sudo rmmod -f tracks;
```
