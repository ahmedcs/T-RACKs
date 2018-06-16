/*
 *  T-RACKs - The linux kernel module implementation of Timely ACKs Retransmission for Data Center
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
 */

#include <net/pkt_sched.h>
#include <linux/openvswitch.h>
#include <net/dsfield.h>
#include <net/inet_ecn.h>

#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/types.h>
#include <linux/netfilter.h>
#include <linux/skbuff.h>
#include <linux/ip.h>
#include <linux/netdevice.h>
#include <linux/if_ether.h>
#include <linux/if_packet.h>
#include <linux/inet.h>
#include <net/tcp.h>
#include <net/udp.h>
#include <net/icmp.h>
#include <net/checksum.h>
#include <linux/netfilter_ipv4.h>
#include <linux/string.h>
#include <linux/time.h>
#include <linux/ktime.h>
#include <linux/fs.h>
#include <linux/errno.h>
#include <linux/timer.h>
#include <linux/jhash.h>

#include "tracks.h"

//MODULE_LICENSE("CRAPL");
MODULE_AUTHOR("Ahmed Sayed => ahmedcs982@gmail.com");
MODULE_VERSION("1.0");
MODULE_DESCRIPTION("Kernel module of Retransmit DUPACKs (T-RACKs)");

static int port=80;
static int maxackno=0;

MODULE_PARM_DESC(debug, "DEBUG Enable, default  is disabled");
module_param(debug, int, 0644);

MODULE_PARM_DESC(enable, "RACK retransmission Enable, default  is disabled");
module_param(enable, int, 0644);

MODULE_PARM_DESC(rtoinms, "RACK RTO suited for data centers, default is 1 ms, max is 100ms");
module_param(rtoinms, int, 0644);

MODULE_PARM_DESC(port, "Port Number to perform ACK signaling on, default is 80");
module_param(port, int, 0644);

MODULE_PARM_DESC(maxackno, "MAX ACK sequence number to track as mice, default is 0");
module_param(maxackno, int, 0644);

//--------Optional --------------
MODULE_PARM_DESC(drops, "RACK total packets drop count, default is random 3 packets");
module_param(drops, int, 0644);

MODULE_PARM_DESC(dropsize, "RACK total packet size ( of the flow), default is 10 packets");
module_param(dropsize, int, 0644);

MODULE_PARM_DESC(burst, "DROP packets randomly vs burst, default is random");
module_param(burst, int, 0644);

static struct Rack rlist[SIZE];
//static struct Racklist head;
static unsigned int count = 0;

//Load module into kernel
int init_module(void);
//Unload module from kernel
void cleanup_module(void);
//Hook for outgoing packets at POSTROUTING
static struct nf_hook_ops nfho_outgoing;
//Hook for incoming packets at PREROUTING
static struct nf_hook_ops nfho_incoming;

//High resolution timer
static struct delayed_work timerwork;
static struct timer_list my_timer;
static bool timerrun;
static bool droparray[DROP_ARRAY_SIZE];
static int dropcount=0;

static u32 hash_seed;

/*
 * The next routines deal with comparing 32 bit unsigned ints
 * and worry about wraparound (automatic with unsigned arithmetic).
 */

/*static inline bool before(__u32 seq1, __u32 seq2)
{
        return (__s32)(seq1-seq2) < 0;
}
#define after(seq2, seq1) 	before(seq1, seq2)*/

static inline unsigned int hash(struct Flow* f)
{
     static u32 flow[4];
     flow[0] = f->local_ip;
     flow[1] = f->local_port;
     flow[2] = f->remote_ip;
     flow[3] = f->remote_port;
     u32 temp_hash, temp_hash1, temp_hash2;

    temp_hash = jhash2(flow, 4, 0); //hash_seed);
    u32 hashval =  jhash_1word(temp_hash, hash_seed); //jhash_2words(temp_hash1, temp_hash2, hash_seed);
    int index = hashval & (SIZE-1);

    if(index>=SIZE || index<0)
    {
        printk("INFO: %pI4 %d %pI4 %d, Log entry hash %u %u index %d\n", &f->local_ip, ntohs(f->local_port), &f->remote_ip, ntohs(f->remote_port), temp_hash, hashval, index);
    }
    else
         return index;
}

/*static inline unsigned int hash(struct Flow* f)
{
    if(!f->local_eth || !f->remote_eth  )
        return -1;
    //return a value in [0,SIZE-1]=1
    return ( (f->local_ip%SIZE+1) * (f->remote_ip%SIZE+1) * ( f->local_port%SIZE+1) * (f->remote_port%SIZE+1) )%SIZE;
    //return ( (f->local_ip%SIZE+1) * (f->remote_ip%SIZE+1) * ( f->local_port%SIZE+1) * (f->remote_port%SIZE+1) * (hash(f->local_eth)%SIZE+1) * (hash(f->remote_eth)%SIZE)  )%SIZE;
}*/

//Function to calculate microsecond-granularity TCP timestamp value
static inline unsigned int get_now(void)
{
    //return (unsigned int)(ktime_to_ns(ktime_get())>>10);
    return (unsigned int)(ktime_to_us(ktime_get()));
}

//Pre-Routing for incoming packets
static unsigned int hook_func_in(unsigned int hooknum, struct sk_buff *skb, const struct net_device *in, const struct net_device *out, int (*okfn)(struct sk_buff *))
{
    struct iphdr *ip_header;             //IP header structure
    struct tcphdr *tcp_header;        //TCP header structure
    struct ethhdr *eth_header;  //Ethernet Header
    struct Flow f;//, rf;
    unsigned long flags;
    //unsigned int rtt=0;		                //Sample RTT value
    unsigned int payload_len, opt_len;        //TCP payload length
    unsigned char * tcp_opt;
    unsigned int time;
    unsigned int seq;
    int relseq, relastseq;
    int k, i, ret=0;
    struct tcp_options_received opt;
    struct Rack *r;
    int randi=0 , randcount=0;

    if(!in) //|| !skb || (skb->dev && strcmp(skb->dev->name,"ovsbr2")!=0 && strcmp(skb->dev->name,"ovsbr3")!=0 && strcmp(skb->dev->name,"ovsbr4")!=0 && strcmp(skb->dev->name,"ovsbr5")!=0))
    {
        return NF_ACCEPT;
    }

    eth_header = (struct ethhdr *)skb_mac_header(skb); //eth_hdr(skb);
    if(!eth_header || (eth_header && eth_header->h_proto != __constant_htons(ETH_P_IP)))
        return NF_ACCEPT;

    ip_header=(struct iphdr *)skb_network_header(skb);

    //The packet is not ip packet (e.g. ARP or others)
    if (!ip_header)
        return NF_ACCEPT;

    //TCP packets
    if(ip_header->protocol==IPPROTO_TCP)
    {
        tcp_header = (struct tcphdr *)((__u32 *)ip_header+ ip_header->ihl); //tcp_hdr(skb);
        //if(ntohs(tcp_header->dest) != 5001 && ntohs(tcp_header->source)!=5001) //if(d_port != 80 &&  d_port != 5001 && s_port!=80 && s_port!=5001)
        if(ntohs(tcp_header->source) != port && ntohs(tcp_header->dest) != port)
            return NF_ACCEPT;

        payload_len= (unsigned int)ntohs(ip_header->tot_len)-(ip_header->ihl<<2)-(tcp_header->doff<<2);

        opt_len= (unsigned int)(tcp_header->doff<<2) - 20;
        tcp_opt=(unsigned char*)tcp_header + 20;

        //Note that: source and destination should be changed !!!
        f.local_ip=ip_header->daddr;
        f.remote_ip=ip_header->saddr;
        f.local_port= tcp_header->dest;
        f.remote_port= tcp_header->source;
        memcpy(f.local_eth, eth_header->h_dest, ETH_ALEN);
        memcpy(f.remote_eth, eth_header->h_source, ETH_ALEN);

        k=hash(&f);
        r=&rlist[k];

        //If this is SYN packet, a new Flow record should be inserted into Flow table
        if(tcp_header->syn || ntohs(ip_header->tos) == OPEN_TOS)
        {
            if(k<0 || k>SIZE)
            {
                if(debug>=2)
                    printk(KERN_INFO " Flow: Insert fails, choosen index:%d out of range\n", k);
                return NF_ACCEPT;
            }
            else if (r->active)
            {
                if(debug>=1)
                     printk(KERN_INFO " Flow: Insert fails RESETING, active flow already index:%d %s:%pM:%pI4 to %pM:%pI4 \n", k, in->name, eth_header->h_source, &ip_header->saddr, eth_header->h_dest, &ip_header->daddr);
                reset_rack(r);
            }
            reset_rack(r);

            //else
            //{
            /* Get original SYNACK MSS value if user MSS sets mss_clamp */
            tcp_clear_options(&opt);
            opt.user_mss = opt.mss_clamp = 0;
            tcp_option(skb, &opt, 0);


            spin_lock_irqsave(&globalLock, flags);
            if(opt.sack_ok)
                r->sack =true;
            if(opt.saw_tstamp)
            {
                r->init_tsval = opt.rcv_tsecr;
                r->init_tsecr = opt.rcv_tsval;
                r->init_jiffies = jiffies;
                r->tstamp = true;
            }
            r->active = true;
            r->eleph = false;
            r->f = f;
            memcpy(r->f.remote_eth, f.remote_eth, ETH_ALEN);
            memcpy(r->f.local_eth, f.local_eth, ETH_ALEN);
            r->in= in;
            r->out =out;
            count++;
            spin_unlock_irqrestore(&globalLock, flags);

            if(debug>=2 && &opt && opt.saw_tstamp)
                printk(KERN_INFO " Init %d [%pI4:%d->%pI4:%d] ack: %u issyn: %d tsval:%u:%u:%x tsecr:%u:%u:%x jiffies:%u\n", k,  &r->f.local_ip, ntohs(r->f.local_port), &r->f.remote_ip, ntohs(r->f.remote_port), r->init_ack, tcp_header->syn, opt.rcv_tsval,  r->init_tsval, htonl(r->init_tsval), opt.rcv_tsecr,  r->init_tsecr, htonl( r->init_tsecr), r->init_jiffies );

            if(debug>=1 && ntohs(ip_header->tos) == OPEN_TOS)
                printk(KERN_INFO " OPENTOS a Flow record %d: %s:%pM:%pI4 to %pM:%pI4 index:%d SACK:%d randnum:%d\n", k,in->name, eth_header->h_source, &ip_header->saddr, eth_header->h_dest, &ip_header->daddr, k, r->sack, r->randnum);
            else if(debug>=1)
                printk(KERN_INFO " Insert a Flow record %d: %s:%pM:%pI4 to %pM:%pI4 index:%d SACK:%d randnum:%d\n", k,in->name, eth_header->h_source, &ip_header->saddr, eth_header->h_dest, &ip_header->daddr, k, r->sack, r->randnum);

            //}
        }

        if(ntohs(ip_header->tos) == CLOSE_TOS || tcp_header->rst)
        {
            if(k<0 || k>SIZE)
            {
                if(debug>=2)
                    printk(KERN_INFO " Delete fails\n");
                return NF_ACCEPT;
            }

            if(r->active)
            {
                spin_lock_irqsave(&globalLock,flags);
                reset_rack_soft(r);
                count--;
                /*if(count==0)
                    timerrun=false;*/
                spin_unlock_irqrestore(&globalLock,flags);
                if(debug>=2 && !timerrun)
                    printk(KERN_INFO " Timer Stopped for No active flows\n");

            }
            if(debug>=1 && ntohs(ip_header->tos) == CLOSE_TOS)
            {
                printk(KERN_INFO " CLOSETOS a Flow record %d: %pI4 to %pI4 \n", k , &ip_header->saddr, &ip_header->daddr);
                return NF_DROP;
            }
            else if(debug>=1)
                printk(KERN_INFO " RST: Delete a Flow record %d: %pI4:%d to %pI4:%d \n", k , &ip_header->saddr, ntohs(tcp_header->source), &ip_header->daddr, ntohs(tcp_header->dest));
        }

        if(payload_len>0 && ntohs(tcp_header->source)==port)
        {
            seq=ntohl(tcp_header->seq);
            if(r->init_seq == 0)
            {
                //generate random interger to pick up which seq no to drop

                dropcount=0;
                for(i=0; i<dropsize; i++)
                    droparray[i]=false;
                //generate burst packet frops starting from the sequential number
                if(burst)
                {
                    for(i=burst; i<burst+drops && i<dropsize; i++)
                    {
                        droparray[i]=true;
                        dropcount++;
                    }
                }
                else
                {
                    for(i=0; i<dropsize; i++)
                    {
                        if(dropcount>=drops)
                            break;
                        while(randi<=0 && randcount<=100)
                        {
                            randcount++;
                            get_random_bytes(&randi, sizeof(randi));
                        }
                        if(randi<0)
                            randi=-1 * randi;
                        randi = randi % dropsize;
                        if(!droparray[randi])
                            dropcount++;
                        droparray[randi] = true;
                        randi=0;
                        randcount=0;

                    }
                }
                spin_lock_irqsave(&globalLock, flags);
                r->randnum = 0;
                r->init_seq =  seq; //r->last_seq = seq;
                spin_unlock_irqrestore(&globalLock, flags);
                if(debug>=1)
                    printk(KERN_INFO " DROPARRAY count:%d 0:%d 1:%d 2:%d 3:%d 4:%d 5:%d 6:%d 7:%d 8:%d\n", dropcount, droparray[0], droparray[1], droparray[2], droparray[3], droparray[4], droparray[5], droparray[6], droparray[7], droparray[8]);
            }

            if((signed) (seq - r->init_seq) >= 0)
                relseq = seq - r->init_seq;
            else
                relseq = MAX_INT - (seq -  r->init_seq);

            if(relseq >= 1)
            {
                if((signed)(r->last_seq - r->init_seq) > 0)
                    relastseq = r->last_seq - r->init_seq  ;
                else
                    relastseq = MAX_INT - (r->last_seq - r->init_seq);

                if(r->last_seq ==0 || relseq > relastseq )
                {

                    spin_lock_irqsave(&globalLock,flags);
                    r->last_seq = seq;
                    r->relastseq = relseq;
                    r->last_id = ip_header->id;
                    spin_unlock_irqrestore(&globalLock,flags);
                    if(debug>=1)
                        printk(KERN_INFO " NEWSEQ %d: [%pI4:%d->%pI4:%d] seqno:%u relseqno:%d resent:%d dupack:%d ttl:%d payload:%d\n", k, &f.local_ip, ntohs(f.local_port), &f.remote_ip, ntohs(f.remote_port), seq, relseq, r->resent, r->dupack,ip_header->ttl, payload_len);

                    if(r->randnum<dropsize && droparray[r->randnum])
                    {
                        if(debug>=1)
                            printk(KERN_INFO " FORCEDROP %d: [%pI4:%d->%pI4:%d] seqno:%u relseqno:%d lastack:%d resent:%d dupack:%d ttl:%d payload:%d\n", k, &f.local_ip, ntohs(f.local_port), &f.remote_ip, ntohs(f.remote_port), seq, relseq, r->relastack, r->resent, r->dupack, ip_header->ttl, payload_len);
                        droparray[r->randnum]=false;
                        r->randnum++;
                        return NF_DROP;
                    }
                    r->randnum++;
                }
            }
        }

    }
    return NF_ACCEPT;
}

//Pre-Routing for outgoing packets, enqueue packets
static unsigned int hook_func_out(unsigned int hooknum, struct sk_buff *skb, const struct net_device *in, const struct net_device *out, int (*okfn)(struct sk_buff *))
{
    struct iphdr *ip_header;       //IP header structure
    struct tcphdr *tcp_header;  //TCP header structure
    struct ethhdr *eth_header;  //Ethernet Header
    struct Flow f;
    unsigned long flags;         //variable for save current states of irq
    unsigned int  ack=0;
    int relack=0, relastack=0;
    unsigned int seqb=0;
    int relseqb=0, relastseqb=0;
    int k, i, ret=0;
    unsigned int payload_len;        //TCP payload length
    unsigned int time;
    struct tcp_options_received opt;
    struct Rack *r;

    if(!out) //|| !skb || (skb->dev && strcmp(skb->dev->name,"ovsbr2")!=0 && strcmp(skb->dev->name,"ovsbr3")!=0 && strcmp(skb->dev->name,"ovsbr4")!=0 && strcmp(skb->dev->name,"ovsbr5")!=0))
        return NF_ACCEPT;

    /*if(strncmp(skb->dev->name,"test", 4)!=0)
         return NF_ACCEPT;*/

    eth_header = (struct ethhdr *)skb_mac_header(skb);
    /*if(eth_header->h_proto != __constant_htons(ETH_P_IP))
    		return NF_ACCEPT;*/

    ip_header= (struct iphdr *)skb_network_header(skb);
    //The packet is not ip packet (e.g. ARP or others)
    if (!ip_header || (ip_header && ip_header->ttl ==128))
        return NF_ACCEPT;


    if(ip_header->protocol==IPPROTO_TCP)
    {

        tcp_header = (struct tcphdr *)((__u32 *)ip_header+ ip_header->ihl);

        //if(ntohs(tcp_header->dest) != 5001 && ntohs(tcp_header->source) != 5001 && ntohs(tcp_header->dest)!=80 && ntohs(tcp_header->source)!=80)
        if( ntohs(tcp_header->dest)!=port && ntohs(tcp_header->source)!=port)// && ntohs(tcp_header->source)!=80)
            return NF_ACCEPT;

        payload_len= (unsigned int)ntohs(ip_header->tot_len)-(ip_header->ihl<<2)-(tcp_header->doff<<2);

        f.local_ip=ip_header->saddr;
        f.remote_ip=ip_header->daddr;
        f.local_port=tcp_header->source;
        f.remote_port=tcp_header->dest;

        k=hash(&f);
        r=&rlist[k];

         if(ntohs(ip_header->tos) == OPEN_TOS)
        {
            if(k<0 || k>SIZE)
            {
                if(debug>=2)
                    printk(KERN_INFO " Flow: Insert fails, choosen index:%d out of range\n", k);
                return NF_ACCEPT;
            }
            else if (r->active)
            {
                if(debug>=1)
                    printk(KERN_INFO " Flow: OPENTOS fails RESETING, active flow already index:%d %s:%pM:%pI4 to %pM:%pI4 \n", k, in->name, eth_header->h_source, &ip_header->saddr, eth_header->h_dest, &ip_header->daddr);
                reset_rack_soft(r);
            }
            r->active = true;
            r->eleph = false;
            r->f = f;
            memcpy(r->f.remote_eth, f.remote_eth, ETH_ALEN);
            memcpy(r->f.local_eth, f.local_eth, ETH_ALEN);
            r->in= in;
            r->out =out;
            count++;
            spin_unlock_irqrestore(&globalLock, flags);

            if(debug>=2 && &opt && opt.saw_tstamp)
                printk(KERN_INFO " Init %d [%pI4:%d->%pI4:%d] ack: %u issyn: %d tsval:%u:%u:%x tsecr:%u:%u:%x jiffies:%u\n", k,  &r->f.local_ip, ntohs(r->f.local_port), &r->f.remote_ip, ntohs(r->f.remote_port), r->init_ack, tcp_header->syn, opt.rcv_tsval,  r->init_tsval, htonl(r->init_tsval), opt.rcv_tsecr,  r->init_tsecr, htonl( r->init_tsecr), r->init_jiffies );

            if(debug>=1)
                printk(KERN_INFO " OPENTOS a Flow record %d: %s:%pM:%pI4 to %pM:%pI4 index:%d SACK:%d randnum:%d\n", k,in->name, eth_header->h_source, &ip_header->saddr, eth_header->h_dest, &ip_header->daddr, k, r->sack, r->randnum);
            //}
        }
        /*if(tcp_header->syn || tcp_header->fin)
        {
            if(r->skbuff)
                kfree_skb(r->skbuff);
            r->skbuff=skb_copy(skb, GFP_ATOMIC);
            if(debug && !r->skbuff)
                printk(KERN_INFO " SYN/FIN PACKET COPY FAILED %d: %s:%pM:%pI4 to %pM:%pI4 SYN:%d FIN:%d\n", k,in->name, eth_header->h_source, &ip_header->saddr, eth_header->h_dest, &ip_header->daddr, tcp_header->syn, tcp_header->fin);
            else if(debug)
                printk(KERN_INFO " SYN/FIN PACKET COPY Successful %d: %s:%pM:%pI4 to %pM:%pI4 SYN:%d FIN:%d\n", k,in->name, eth_header->h_source, &ip_header->saddr, eth_header->h_dest, &ip_header->daddr, tcp_header->syn, tcp_header->fin);
            r->conntime = jiffies;
        }*/

        if(!r->active || (r->relastack >= maxackno && r->eleph))
            return NF_ACCEPT;

        if(tcp_header->ack && ntohs(tcp_header->dest)==port)
        {        		
            seqb=ntohl(tcp_header->seq);
            ack=ntohl(tcp_header->ack_seq);

            //Update per-flow information
            if(k>=0 && k<SIZE)
            {
                if(r->init_seqb == 0)
                {
                    r->init_seqb  = seqb; r->last_seqb = seqb;
                    if(debug>=1)
                        printk(KERN_INFO " Init back seq: %u issyn: %d \n", r->init_seqb , tcp_header->syn );
                }
                else
                {
                    if((signed) (seqb - r->init_seqb) >= 0)
                        relseqb = seqb - r->init_seqb;
                    else
                        relseqb = MAX_INT - (seqb -  r->init_seqb);
                }

                if(r->init_ack == 0)
                {
                    r->init_ack = ack; r->last_ack = ack;
                    if(debug>=1)
                        printk(KERN_INFO " Init ack: %u issyn: %d\n", r->init_ack, tcp_header->syn );
                    r->init=true;
                }
                else
                {
                    if((signed) (ack - r->init_ack) >= 0)
                        relack = ack - r->init_ack + 1;
                    else
                        relack = MAX_INT - (ack -  r->init_ack) + 1;
                }

                if(debug>=1)
                    printk(KERN_INFO " ACK %d: [%pI4:%d->%pI4:%d] ackno:%d rellastack:%d dupack:%d retrans:%d ttl:%d resent:%d\n", k, &r->f.remote_ip, ntohs(r->f.remote_port), &r->f.local_ip, ntohs(r->f.local_port),  relack, r->relastack,  r->dupack,  r->retrans,  ip_header->ttl, r->resent);

                if(relack>1 && (maxackno==0 || relack <= maxackno))
                {
                    if(r->last_seqb)
                    {
                        if((signed) (r->last_seqb - r->init_seqb) >= 0)
                            relastseqb = r->last_seqb - r->init_seqb + 1;
                        else
                            relastseqb = MAX_INT - (r->last_seqb - r->init_seqb) ;
                    }
                    else
                        relastseqb=0;
                    if(r->last_ack)
                    {
                        if((signed) (r->last_ack - r->init_ack) >= 0)
                            relastack = r->last_ack - r->init_ack + 1;
                        else
                            relastack = MAX_INT - (r->last_ack - r->init_ack) + 1;
                    }
                    else
                        relastack = 0;

                    spin_lock_irqsave(&globalLock,flags);
                    if(tcp_header->fin)
        				r->fin = 1;
        			if(tcp_header->psh)
        				r->psh = 1;
                    r->eleph = false;
                    r->last_window = tcp_header->window;
                    r->last_bid = ip_header->id;
                    r->dev = skb->dev;
                    r->p_type = skb->pkt_type;
                    r->last_update = jiffies;
                    if(r->tstamp)
                    {
                        tcp_option(skb, &opt, 1);
                        int val = jiffies_to_msecs((__u32) jiffies - opt.rcv_tsecr); //jiffies_to_usecs((__u32) jiffies - opt.rcv_tsecr);
                        if(r->avg_rtt && val>0)
                            r->avg_rtt = 3 * (r->avg_rtt>>2) + val>>2;
                        else if(val>0)
                            r->avg_rtt = val;
                    }
                    spin_unlock_irqrestore(&globalLock,flags);

                    //memcpy(r->data,  ip_header, (unsigned int)(ip_header->ihl<<2));
                    //memcpy((r->data + (unsigned int)(ip_header->ihl<<2)) , tcp_header, (unsigned int)(tcp_header->doff<<2));

                    if(relack >  relastack)
                    {
                        if(debug>=1 && !r->resent)
                            printk(KERN_INFO " NEW ACK %d: [%pI4:%d->%pI4:%d] seqno:%d ackno:%d lastack:%d resent:%d\n", k, &r->f.remote_ip, ntohs(r->f.remote_port), &r->f.local_ip, ntohs(r->f.local_port),  relseqb, relack, relastack, r->resent);
                        if(debug>=2 && r->resent)
                            printk(KERN_INFO " RECOVER ACK %d: [%pI4:%d->%pI4:%d] seqno:%d ackno:%d lastack:%d resent:%d\n", k, &r->f.remote_ip, ntohs(r->f.remote_port), &r->f.local_ip, ntohs(r->f.local_port),  relseqb, relack, relastack, r->resent);

                        spin_lock_irqsave(&globalLock,flags);
                        r->last_seqb = seqb;
                        r->last_ack = ack;
                        r->relastseqb = relseqb; //relastseqb;
                        r->relastack = relack; //relastack;
                        r->dupack=0;
                        r->resent=0;
                        r->backoff =1;
                        if(r->retrans)
                            r->scount = 0;
                        r->retrans = false;
                        r->last_retrans=0;
                        spin_unlock_irqrestore(&globalLock,flags);
                    }
                    else
                    {
                        spin_lock_irqsave(&globalLock,flags);
                        r->dupack++;
                        spin_unlock_irqrestore(&globalLock,flags);
                        if(debug>=1)
                            printk(KERN_INFO " DUP ACK %d: [%pI4:%d->%pI4:%d] seqno:%d dupackno:%d lastack:%d resent:%d dupack:%d\n", k, &r->f.remote_ip, ntohs(r->f.remote_port), &r->f.local_ip, ntohs(r->f.local_port),  relseqb, relack, relastack, r->resent, r->dupack);
                    }

                    if(!enable)
                        return NF_ACCEPT;

                    //RESET TCP options and Update the incoming ACK with new options
                    if(r->sack)
                    {
                        ret = tcp_opt_update(skb, r);
                        if(ret)
                        {
                            spin_lock_irqsave(&globalLock,flags);
                            r->scount++;
                            spin_unlock_irqrestore(&globalLock,flags);
                            if(debug>=2)
                                printk(KERN_INFO " ACK Update %d:  ackno:%u relackno:%d resent:%u dupack:%d \n", k, r->last_ack, r->relastack, r->resent, r->dupack);
                            //return NF_ACCEPT;
                        }
                        else if(debug>=2)
                            printk(KERN_INFO " ACK Update Failed  NO ROOM %d:  ackno:%u relackno:%d resent:%u dupack:%d  \n", k, r->last_ack, r->relastack, r->resent,  r->dupack);
                    }

                }
                else if(r->last_update)
                {
                    r->eleph=true;
                    r->last_ack=ack;
                    if(debug>=1)
                        printk(KERN_INFO " FLOW became Elephant %d: lastackno:%d relackno:%d resent:%u dupack:%d  \n", k, r->relastack, relack, r->resent, r->dupack);
                    r->relastack=relack;
                }
            }
            //Do not process FIN_ACKs, we still need to handle if last ACK (usually piggybacked with FIN)
			return NF_ACCEPT;
        }
        //Delete flow entry when we receive pure FIN not(FIN_ACK) or RST packets 
        if(tcp_header->fin || tcp_header->rst || ntohs(ip_header->tos) == CLOSE_TOS)
        {
            if(k<0 || k>SIZE)
            {
                if(debug>=2)
                 printk(KERN_INFO " Delete fails\n");
                return NF_ACCEPT;
            }

            if(r->active)
            {
                spin_lock_irqsave(&globalLock,flags);
                if(ntohs(ip_header->tos) == CLOSE_TOS)
                     reset_rack_soft(r);
                else
                     reset_rack(r);
                count--;
                /*if(count==0)
                    timerrun=false;*/
                spin_unlock_irqrestore(&globalLock,flags);
                if(debug>=2 && !timerrun)
                    printk(KERN_INFO " Timer Stopped for No active flows\n");

            }
            if(debug>=1 && ntohs(ip_header->tos) == CLOSE_TOS)
            {
                printk(KERN_INFO " CLOSETOS a Flow record %d: %pI4 to %pI4 \n", k , &ip_header->saddr, &ip_header->daddr);
                return NF_DROP;
            }
            else if(debug>=1 && tcp_header->fin)
                printk(KERN_INFO " CLOSE: Delete a Flow record %d: %pI4:%d to %pI4:%d \n", k , &ip_header->saddr, ntohs(tcp_header->source), &ip_header->daddr, ntohs(tcp_header->dest));
            else if(debug>=1 && tcp_header->rst)
                printk(KERN_INFO " RST: Delete a Flow record %d: %pI4:%d to %pI4:%d \n", k , &ip_header->saddr, ntohs(tcp_header->source), &ip_header->daddr, ntohs(tcp_header->dest));
        }

    }
    return NF_ACCEPT;
}

void my_timer_callback(unsigned  long  data)
{
    unsigned long flags;         //variable for save current states of irqunsigned int len;
    unsigned int ack_time=0;
    unsigned int retrans_time=0;       //Time interval to measure throughput
    struct Rack *r;
    int i,k;
    //printk(KERN_INFO " in Timer %d: will check racks\n", jiffies);
    /*if(debug)
           printk(KERN_INFO " Timer call back is called \n" , jiffies);*/
    if(!enable)
    {
        mod_timer(&my_timer, jiffies + msecs_to_jiffies(RACK_CHECK_INTERVAL_MS));
        return;
    }

    for(i=0; i<SIZE; i++)
    {
        r = &rlist[i];
        /*if(r->conntime && time_after(jiffies, r->conntime + 10) )
        {
            eth_rebuild_header(r->skbuff);
            if(dev_queue_xmit(r->skbuff) >= 0)
            {
                if(debug)
                    printk(KERN_INFO " SYN/FIN Retrans Success %d:  ackno:%u relackno:%d resent:%u dupack:%d \n", i);
            }
            else if(debug)
                    printk(KERN_INFO " SYN/FIN Retrans FAIL %d:  ackno:%u relackno:%d resent:%u dupack:%d \n", i);
            r->conntime = 0;
        }*/

        if(!r || !r->active || r->eleph || r->resent>100 || !r->last_update || r->relastack<=1) //|| r->relastack>14000)
            continue;
        //Per-flow  control interval: RTT

        //printk(KERN_INFO " in Timer %d: will check racks\n", jiffies);
        if(!r->retrans && time_after(jiffies, r->last_update + rtoinms)) //MAX(rtoinms, r->avg_rtt)) )
        {
            if(generate_ack(r))
            {
                if(debug>=1)
                    printk(KERN_INFO " LOST ACK Retrans %d: [%pI4:%d->%pI4:%d] ackno:%u relackno:%d resent:%u dupack:%d timeout:%u\n", i, &r->f.remote_ip, ntohs(r->f.remote_port), &r->f.local_ip, ntohs(r->f.local_port), r->last_ack, r->relastack, r->resent, r->dupack, MAX(rtoinms, r->avg_rtt));
            }
            else if(debug>=1)
                printk(KERN_INFO " LOST ACK Retrans FAIL %d:  ackno:%u relackno:%d resent:%u dupack:%d  timeout:%u\n", i, r->last_ack, r->relastack, r->resent,  r->dupack, MAX(rtoinms, r->avg_rtt));

            spin_lock_irqsave(&globalLock,flags);
            r->dupack++;
            r->resent++;
            r->scount++;
            if( r->resent > 3)
            {
                r->retrans = true;
                r->last_retrans = jiffies;
                r->backoff = 1;
            }
            spin_unlock_irqrestore(&globalLock,flags);
        }
        else if(r->retrans && time_after(jiffies, r->last_retrans + rtoinms)) // MAX(rtoinms<<r->backoff, r->avg_rtt) ))
        {
            if(generate_ack(r))//recv_ack(r))
            {
                if(debug>=1)
                    printk(KERN_INFO " ACK Backoff %d: [%pI4:%d->%pI4:%d] ackno:%u relackno:%d resent:%u timeout:%u\n", i, &r->f.remote_ip, ntohs(r->f.remote_port), &r->f.local_ip, ntohs(r->f.local_port), r->last_ack, r->relastack, r->resent, MAX(rtoinms<<r->backoff, r->avg_rtt));
            }
            else if(debug>=1)
                printk(KERN_INFO " ACK Backoff FAIL %d:  ackno:%u relackno:%d resent:%u timeout:%u\n", i, r->last_ack, r->relastack, r->resent, MAX(rtoinms<<r->backoff, r->avg_rtt));

            spin_lock_irqsave(&globalLock,flags);
            r->last_retrans = jiffies;
            r->resent++;
            if(!(r->resent%10))
                r->backoff++;
            r->scount++;
            spin_unlock_irqrestore(&globalLock,flags);

        }
        if(time_after(jiffies, r->last_update + MIN_RTO))//wait up to close to timeout
        {
            spin_lock_irqsave(&globalLock,flags);
            r->retrans = false;
            r->last_retrans = r->last_update = jiffies;
            r->backoff = 1;
            spin_unlock_irqrestore(&globalLock,flags);
        }

    }
    //schedule_delayed_work(&timerwork, RACK_CHECK_INTERVAL_MS);
    mod_timer(&my_timer, jiffies + msecs_to_jiffies(RACK_CHECK_INTERVAL_MS));


}

init_module(void)
{
    int i;

    for(i=0; i<SIZE; i++)
    {
        reset_rack(&rlist[i]);
    }
    for(i=0; i<DROP_ARRAY_SIZE; i++)
        droparray[i]=true;
    count=0;

    //Initialize lock for global information
    spin_lock_init(&globalLock);

    get_random_bytes(&hash_seed, sizeof(u32));

    //INIT_DELAYED_WORK(&timerwork, my_timer_callback);
    //schedule_delayed_work(&timerwork, RACK_CHECK_INTERVAL_MS);

    init_timer(&my_timer);
    setup_timer(&my_timer, my_timer_callback, 0);
    mod_timer(&my_timer, jiffies + msecs_to_jiffies(RACK_CHECK_INTERVAL_MS));

    //POSTROUTING
    nfho_outgoing.hook = hook_func_out;                   	//function to call when conditions below met
    nfho_outgoing.hooknum =   NF_INET_POST_ROUTING; //  NF_INET_LOCAL_OUT;          	//called in post_routing
    nfho_outgoing.pf = PF_INET;     						//IPV4 packets
    nfho_outgoing.priority = NF_IP_PRI_FIRST;             	//set to highest priority over all other hook functions
    nf_register_hook(&nfho_outgoing);                     	//register hook

    //PREROUTING
    nfho_incoming.hook=hook_func_in;						//function to call when conditions below met
    nfho_incoming.hooknum= NF_INET_PRE_ROUTING; //NF_INET_LOCAL_IN;  //NF_INET_PRE_ROUTING;   	//called in pre_routing
    nfho_incoming.pf = PF_INET;								//IPV4 packets
    nfho_incoming.priority = NF_IP_PRI_FIRST;		//set to highest priority over all other hook functions
    nf_register_hook(&nfho_incoming);						//register hook*/

    printk(KERN_INFO " T-RACKs kernel module, all set, enable %d, debug %d, rtoinms %d, maxackno %d, burst %d, drops %d, dropsize %d\n", 
    					enable, debug, rtoinms, maxackno, burst, drops, dropsize);
    return 0;
}

void cleanup_module(void)
{
    //cancel_delayed_work(&timerwork);
    del_timer(&my_timer);

    nf_unregister_hook(&nfho_outgoing);
    nf_unregister_hook(&nfho_incoming);

    printk(KERN_INFO " T-RACKs kernel module, exiting\n");

}



