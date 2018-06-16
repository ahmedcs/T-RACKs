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


#ifndef	TRACKS_H
#define	TRACKS_H

#include <asm/unaligned.h>
#include <linux/skbuff.h>
#include <linux/time.h>
#include <linux/etherdevice.h>
#include <net/xfrm.h>

#define MAX(a,b) ({ __typeof__ (a) _a = (a);  __typeof__ (b) _b = (b);  _a > _b ? _a : _b; })

//-----------------------------Ahmed---------------------------
#define SIZE (1<<13) //(HASH_RANGE * QUEUE_SIZE)
#define FILESIZE 11500
#define RACK_CHECK_INTERVAL_MS 1 // every 1 ms
#define  FLOW_TIMEOUT_INTERVAL_MS 1 //(1<<3) //8ms

#define DROP_ARRAY_SIZE 10


#define RETRANS_SIZE 100
#define MAX_ACK_SIZE 120 //60 bytes for IP and 60 bytes for TCP

#define MIN_RTO 199000 //((1<<8) - (1<<6))
#define RTT8 11

#define OPEN_TOS 240
#define CLOSE_TOS 248

#define MIN_RTT 300
#define DELAY_IN_US 500 //200000
#define MAX_INT ((1<<32)-1)

#define TCP_HDSIZE 20
#define TCP_OPT_SIZE 24

#define OUR_TTL 127

//microsecond to nanosecond
#define US_TO_NS(x)	(x * 1E3L)
//millisecond to nanosecond
#define MS_TO_NS(x)	(x * 1E6L)

/** Print format for a mac address. */
#define MACFMT "%02x:%02x:%02x:%02x:%02x:%02x"

#define MAC6TUPLE(_mac) (_mac)[0], (_mac)[1], (_mac)[2], (_mac)[3], (_mac)[4], (_mac)[5]
//-----------------------------Ahmed---------------------------

//Lock for global information (e.g. tokens)
static spinlock_t globalLock;

static int debug=0;
static int enable=0;
static int drops=3;
static int dropsize=10;
static int rtoinms=1;
static int burst=0;
//---------------------------------------------RACK---------------------------------------

//Define structure of a TCP flow
//Flow is defined by 4-tuple <local_ip,remote_ip,local_port,remote_port> and its related information
struct Flow
{
    unsigned int local_ip;           //Local IP address
    unsigned int remote_ip;		 //Remote IP address
    unsigned short int local_port;  //Local TCP port
    unsigned short int remote_port;	//Remote TCP port
    unsigned char   local_eth[ETH_ALEN];       /* local eth addr */
    unsigned char   remote_eth[ETH_ALEN];     /* remote ether addr    */
};

struct Rack
{
    //----------------------Ahmed----------------------------
    //Store the ACK and the OK Function to resend it
    struct net_device *dev, *out, *in;
    unsigned char p_type;

    unsigned long last_retrans, last_update, conntime;
    bool  retrans, active, eleph, init, sack, tstamp, dropped, recovered;
    unsigned int dupack, backoff, resent, scount;

    int init_ack, last_ack;
    int relastack;
    unsigned int fin_ack;
    unsigned int init_seqb, last_seqb;
    int relastseqb;
    unsigned int init_seq, last_seq;
    int relastseq;
    
    bool fin, psh;

    unsigned int avg_rtt;
    unsigned int init_tsval, init_tsecr, init_jiffies;
    unsigned short  last_window, last_id, last_bid;
    unsigned short cwnd;
    struct Flow f;
    int dlen, randnum;

    struct sk_buff * skbuff;

};

static unsigned int hook_func_out(unsigned int hooknum, struct sk_buff *skb, const struct net_device *in, const struct net_device *out, int (*okfn)(struct sk_buff *));
static unsigned int hook_func_in(unsigned int hooknum, struct sk_buff *skb, const struct net_device *in, const struct net_device *out, int (*okfn)(struct sk_buff *));
//void my_timer_callback(struct work_struct *ws);
void my_timer_callback(unsigned  long  data);

static inline void reset_rack_soft(struct Rack* r)
{
    r->active = r->retrans =r->eleph = r->init = r->dropped = r->recovered =false;
    r->last_update = r->last_retrans = 0;
    r->backoff = r->dupack = r->resent = r->scount = 0;
    r->last_window=0;
    r->last_id = r->last_bid =0;
    r->f.local_port = r->f.remote_port = 0;
    r->f.local_ip = r->f.remote_ip = 0;
    strcpy(r->f.local_eth, "");
    strcpy(r->f.remote_eth, "");
    r->dlen = r->randnum=0;
    r->dev = r->in = r->out =NULL;
    r->skbuff=NULL;
    r->conntime=0;
    r->avg_rtt=0;
    r->fin=0; r->psh=0;

}

static inline void reset_rack(struct Rack* r)
{
    r->active = r->retrans =r->eleph = r->init = r->sack = r->tstamp = r->dropped = r->recovered =false;
    r->last_update = r->last_retrans = 0;
    r->last_ack = r->init_ack = r->fin_ack = r->relastack= 0;
    r->last_seq = r->init_seq = r->relastseq = 0;
    r->last_seqb = r->init_seqb = r->relastseqb = 0;
    r->backoff = r->dupack = r->resent = r->scount = 0;
    r->last_window=0;
    r->last_id = r->last_bid =0;
    r->init_jiffies = r->init_tsval = r->init_tsecr = 0;
    r->f.local_port = r->f.remote_port = 0;
    r->f.local_ip = r->f.remote_ip = 0;
    strcpy(r->f.local_eth, "");
    strcpy(r->f.remote_eth, "");
    r->dlen = r->randnum=0;
    r->dev = r->in = r->out =NULL;
    r->skbuff=NULL;
    r->conntime=0;
    r->fin=0; r->psh=0;

}

static unsigned int hashstr(unsigned char *str)
{
    unsigned int hash = 5381;
    int c;

    while (c = *(str++))
    {
        hash = ((hash << 5) + hash) + c; /* hash * 33 + c */
    }

    return hash;
}

void tcp_option(struct sk_buff *skb, struct tcp_options_received *opt_rx, int estab)
{
    const unsigned char *ptr;
    const struct tcphdr *th = tcp_hdr(skb);
    int length = (th->doff<<2) - sizeof(struct tcphdr);

    ptr = (const unsigned char *)(th + 1);
    opt_rx->saw_tstamp = 0;

    while (length > 0)
    {
        int opcode = *ptr++;
        int opsize;

        switch (opcode)
        {
        case TCPOPT_EOL:
            return;
        case TCPOPT_NOP:	/* Ref: RFC 793 section 3.1 */
            length--;
            continue;
        default:
            opsize = *ptr++;
            if (opsize < 2) /* "silly options" */
                return;
            if (opsize > length)
                return;	/* don't parse partial options */
            switch (opcode)
            {
            case TCPOPT_MSS:
                if (opsize == TCPOLEN_MSS && th->syn && !estab)
                {
                    u16 in_mss = get_unaligned_be16(ptr);
                    if (in_mss)
                    {
                        if (opt_rx->user_mss &&
                                opt_rx->user_mss < in_mss)
                            in_mss = opt_rx->user_mss;
                        opt_rx->mss_clamp = in_mss;
                    }
                }
                break;
            case TCPOPT_WINDOW:
                if (opsize == TCPOLEN_WINDOW && th->syn &&  !estab)
                {
                    __u8 snd_wscale = *(__u8 *)ptr;
                    opt_rx->wscale_ok = 1;
                    if (snd_wscale > 14)
                    {
                        net_info_ratelimited("%s: Illegal window scaling value %d >14 received\n",
                                             __func__,
                                             snd_wscale);
                        snd_wscale = 14;
                    }
                    opt_rx->snd_wscale = snd_wscale;
                }
                break;
            case TCPOPT_TIMESTAMP:
                if ((opsize == TCPOLEN_TIMESTAMP) && ( (estab && opt_rx->tstamp_ok) || (!estab) ) )
                {
                    opt_rx->saw_tstamp = 1;
                    opt_rx->rcv_tsval = get_unaligned_be32(ptr);
                    opt_rx->rcv_tsecr = get_unaligned_be32(ptr + 4);
                }
                break;
            case TCPOPT_SACK_PERM:
                if (opsize == TCPOLEN_SACK_PERM && th->syn &&  !estab)
                {
                    opt_rx->sack_ok = TCP_SACK_SEEN;
                    //tcp_sack_reset(opt_rx);
                }
                break;

            case TCPOPT_SACK:
                if ((opsize >= (TCPOLEN_SACK_BASE + TCPOLEN_SACK_PERBLOCK)) && !((opsize - TCPOLEN_SACK_BASE) % TCPOLEN_SACK_PERBLOCK) &&   opt_rx->sack_ok)
                {
                    TCP_SKB_CB(skb)->sacked = (ptr - 2) - (unsigned char *)th;
                }
                break;

            }
            ptr += opsize-2;
            length -= opsize;
        }
    }
}


// Look tcp_options_write in file tcp_output.c

static inline int tcp_opt_write(__be32 *ptr, struct Rack *rack)
{
    unsigned int size = 0;

    if (likely(rack->tstamp))
    {
        *ptr++ = htonl((TCPOPT_NOP << 24) |
                       (TCPOPT_NOP << 16) |
                       (TCPOPT_TIMESTAMP << 8) |
                       TCPOLEN_TIMESTAMP);
        *ptr++ = htonl(rack->init_tsval + jiffies - rack->init_jiffies);//htonl(opts->tsval);
        *ptr++ = htonl(rack->init_tsecr + jiffies - rack->init_jiffies);//htonl(opts->tsecr);
        //unsigned long delay = max(usecs_to_jiffies(tp->srtt_us >> 4),  msecs_to_jiffies(10));
        size += TCPOLEN_TSTAMP_ALIGNED;
    }



    if (likely(rack->sack))
    {
        *ptr++ = htonl( (TCPOPT_NOP  << 24) |
                        (TCPOPT_NOP  << 16) |
                        (TCPOPT_SACK <<  8) |
                        (TCPOLEN_SACK_BASE +  TCPOLEN_SACK_PERBLOCK) );
        *ptr++ = htonl(rack->last_ack + 30);
        *ptr++ = htonl(rack->last_ack + 30 + 1448 * (rack->scount+1) );

        int ack = rack->last_ack  - rack->init_ack;
        if(debug>=2)
            trace_printk(KERN_INFO " WRITE: ack:%d left:%d right:%d \n", ack, ack + 30, ack + 30 + 1448 * (rack->scount+1));

        //*ptr++ = htonl(rack->last_ack + 150000);
        //*ptr++ = htonl(rack->last_ack + 151488);

        size += TCPOLEN_SACK_BASE_ALIGNED + TCPOLEN_SACK_PERBLOCK;

        //*ptr++ = htonl(rack->last_ack+1);
        //*ptr++ = htonl(rack->last_ack+1+(i+1));
    }
    return size;
}

static int tcp_opt_update(struct sk_buff* skb, struct Rack *rack)
{

    struct sk_buff* sb = skb;
    struct iphdr *ip_header = (struct iphdr *)skb_network_header(sb);
    struct tcphdr *tcp_header = (struct tcphdr *)((__u32 *)ip_header+ ip_header->ihl);
    int i, ret =0;
    int optlen = (signed)((unsigned int)(tcp_header->doff<<2) - TCP_HDSIZE);
    int optdiff = optlen - TCP_OPT_SIZE;
    if(optdiff >= 0 )
    {
        memset((tcp_header+TCP_HDSIZE), 0 , optlen);
        tcp_opt_write((tcp_header+1), rack);
        __be16 *ptr = (tcp_header+TCP_OPT_SIZE);
        if(optdiff >= 2)
        {
            for(i=0; i<optdiff>>1; i++)
            {
                *(ptr+i) = htons((TCPOPT_NOP << 8) | TCPOPT_NOP);
            }
        }
        else if(optdiff==1)
            *(ptr) = TCPOPT_NOP;
        if(debug>=2)
            trace_printk(KERN_INFO " optlen:%d optdiff: %d \n", optlen, optdiff);

    }
    else if(optdiff + skb_tailroom(sb) >= 0 )
    {
        if(debug>=2)
            trace_printk(KERN_INFO " optlen:%d optdiff: %d room:%d len:%d skb:%p data:%p ip:%p tcp:%p tail:%p\n", optlen, optdiff, skb_tailroom(sb), sb->len, sb, sb->data, ip_header, tcp_header, skb_tail_pointer(sb));

        optdiff = -1 * optdiff;

        //---------------Reset the old options and put the new space--------------
        __be32 *ptr = (tcp_header+1);
        if(optlen > 0)
            memset(ptr, 0 , TCP_OPT_SIZE);
        skb_put(sb,  optdiff );
        //---------------Trim old options and Put the space for new options--------------
        //skb_trim(sb,  optlen);
        // __be32 *ptr = skb_put(sb, TCP_OPT_SIZE);
        // if(debug)
        //   trace_printk(KERN_INFO " skb:%p tcp:%p ptr:%p tail:%p\n", sb, tcp_header, ptr, skb_tail_pointer(sb));

        if(rack->sack || rack->tstamp)
        {
            tcp_opt_write(ptr, rack);
            if(debug>=2)
                trace_printk(KERN_INFO " optlen:%d optdiff: %d room:%d len:%d tcp:%p  ptr:%p tail:%p\n", optlen, optdiff, skb_tailroom(sb), skb->len, tcp_header, ptr, skb_tail_pointer(sb));
        }

    }
    else
    {
        if(debug>=2)
            trace_printk(KERN_INFO " No TAILROOM: optlen:%d optdiff: %d room:%d len:%d skb:%p data:%p ip:%p tcp:%p tail:%p\n", optlen, optdiff, skb_tailroom(sb), sb->len, sb, sb->data, ip_header, tcp_header, skb_tail_pointer(sb));
        //return 0;
        //-------------------Try to expand SKB---------------------
        if (pskb_expand_head(sb, 0, optdiff + skb_tailroom(sb), GFP_ATOMIC))
        {
            // allocation failed. Do whatever you need to do
            if(debug>=2)
                trace_printk(KERN_INFO " EXPAND FAIL: skb:%p head:%p end:%p data:%p tail:%p\n", sb, sb->head, sb->end, sb->data, sb->tail);
            return 0;

        }
        //------------Expand successeds proceed to push at headroom or put at tail rooms-------------
        if(optdiff + skb_tailroom(sb) < 0)
            return 0;

        char* pos = skb_put(sb, TCP_OPT_SIZE - optlen);
        if(debug>=2)
            trace_printk(KERN_INFO " Before Push and Update: optlen:%d optdiff: %d room:%d len:%d tcp:%p  ptr:%p tail:%p\n", optlen, optdiff, skb_tailroom(sb), sb->len, tcp_header, pos, skb_tail_pointer(sb));
        ip_header = (struct iphdr *)skb_network_header(sb);
        tcp_header = (struct tcphdr *)((__u32 *)ip_header+ ip_header->ihl);
        __be32 *ptr =  (__be32*) (tcp_header+1);
        memset(ptr, 0 , TCP_OPT_SIZE);

        if(rack->sack || rack->tstamp)
        {
            tcp_opt_write(ptr, rack);
            if(debug>=2)
                trace_printk(KERN_INFO " After Push and Update: optlen:%d optdiff: %d room:%d len:%d tcp:%p  ptr:%p tail:%p\n", optlen, optdiff, skb_tailroom(sb), sb->len, tcp_header, ptr, skb_tail_pointer(sb));
        }

        //return 0;
    }

    //update IP header total length
    __be16 old_tot = ip_header->tot_len;
    ip_header->tot_len = __constant_htons(sizeof(struct iphdr) + TCP_HDSIZE  + TCP_OPT_SIZE);
    //calculate IP checksum Info
    //ip_header->check = 0;
    //ip_send_check(ip_header);
    csum_replace2(&ip_header->check, old_tot, ip_header->tot_len);

    //TCP data offset update
    if(optdiff<=0)
        tcp_header->doff = (TCP_HDSIZE  + TCP_OPT_SIZE)>>2;
    else
        tcp_header->doff = (TCP_HDSIZE  + TCP_OPT_SIZE + optdiff)>>2;
    //if(debug)
    //  trace_printk(KERN_INFO " old check:%d\n", ntohs(tcp_header->check));
    tcp_header->check=0;
    tcp_header->check = csum_tcpudp_magic(ip_header->saddr, ip_header->daddr, TCP_HDSIZE  + TCP_OPT_SIZE, ip_header->protocol, csum_partial((char *)tcp_header, TCP_HDSIZE  + TCP_OPT_SIZE, 0));
    // if(debug)
    //    trace_printk(KERN_INFO " new check:%d\n", ntohs(tcp_header->check));

    return 1;
}
// tcp_established_options from tcp_output.c

static inline unsigned int tcp_options_size(struct Rack *rack)
{
    unsigned int size = 0;


    if (likely(rack->tstamp))
    {
        size += TCPOLEN_TSTAMP_ALIGNED;
    }

    if (unlikely(rack->sack))
    {
        size += TCPOLEN_SACK_BASE_ALIGNED + TCPOLEN_SACK_PERBLOCK;
    }

    return size;
}
//---------- Create a feebdack packet and prepare for transmission.  Returns 1 if successful.
static int generate_ack(struct Rack *rack)
{
    //struct net_device *ndev = dev_get_by_name(&init_net, "p1p2");
    if(unlikely(!rack) || unlikely(!rack->dev))
        return 0;
    struct sk_buff *skb;
    struct ethhdr *eth_to;
    struct iphdr *iph_to;
    struct tcphdr *tcp_to;
    int length, tcplen, ret;
    unsigned long flags;         //variable for save current states of irq

    int tcpsize=sizeof(struct tcphdr) + tcp_options_size(rack);  // rack->h.optsize+ tcp_options_size(rack);
    int iphsize=sizeof(struct iphdr);
    int ethsize = ETH_HLEN;

    int size = ethsize + iphsize + tcpsize;
    if(size < ETH_ZLEN)
        size = ETH_ZLEN;

    skb = netdev_alloc_skb(rack->dev, size);
    if(likely(skb))
    {
        skb_set_queue_mapping(skb, 0);
        skb->len = size; //pkt->len;
        skb->protocol = __constant_htons(ETH_P_IP);
        skb->pkt_type =  rack->p_type; //PACKET_OUTGOING; //rack->p_type; //PACKET_HOST; //PACKET_USER;
        skb_set_tail_pointer(skb, size);

        //----------------MAC HEADER---------------------
        skb_reset_mac_header(skb);
        eth_to = eth_hdr(skb);

        //spin_lock_irqsave(&globalLock,flags);
        memcpy(eth_to->h_source, rack->f.local_eth, ETH_ALEN);
        memcpy(eth_to->h_dest, rack->f.remote_eth, ETH_ALEN);
        //spin_unlock_irqrestore(&globalLock,flags);

        //No lock is needed
        eth_to->h_proto =  __constant_htons(ETH_P_IP);//eth_from->h_proto;

        skb_pull(skb, ethsize);
        //skb_reserve(skb, ETH_ALEN);

        //-----------------------IP header------------------------------------
        skb_reset_network_header(skb);
        //iph_to = (void *)skb_put(skb, sizeof(struct iphdr));
        iph_to = ip_hdr(skb);

        //spin_lock_irqsave(&globalLock,flags);
        iph_to->saddr = rack->f.local_ip;
        iph_to->daddr = rack->f.remote_ip;
        iph_to->id = rack->last_bid + 1; //htons(atomic_inc_return(&ip_ident)); //rack->last_bid + 1;
        //rack->last_bid = rack->last_bid +1;
        //spin_unlock_irqrestore(&globalLock,flags);

        //No Lock is needed
        iph_to->ihl = iphsize>>2;
        iph_to->version = 4;
        iph_to->tot_len = __constant_htons(iphsize + tcpsize);
        iph_to->tos = 0;
        iph_to->frag_off =  0; //htons(0x4000);
        iph_to->frag_off |= ntohs(IP_DF);
        iph_to->ttl = OUR_TTL; //64;
        iph_to->protocol = IPPROTO_TCP;

        //calculate IP checksum Info and the IP header
        ip_send_check(iph_to);
        skb_pull(skb, iphsize);

        //------------------------TCP Header---------------------------------
        //skb_push(skb, tcpsize);
        skb_reset_transport_header(skb);
        //tcp_to = (void *)skb_put(skb, sizeof(struct tcphdr));
        tcp_to = tcp_hdr(skb);
        /*if(rack->h.optsize > 0)
        {
            tcp_opt=(unsigned char*)tcp_to + 20;
            memcpy(tcp_opt, rack->h.opt, rack->h.optsize);
        }*/

        //spin_lock_irqsave(&globalLock,flags);
        tcp_to->source    = rack->f.local_port;
        tcp_to->dest    = rack->f.remote_port;
        tcp_to->seq     = htonl(rack->last_seqb);
        tcp_to->ack_seq  = htonl(rack->last_ack);
        tcp_to->window  = rack->last_window;
        //spin_unlock_irqrestore(&globalLock,flags);

        // No Lock is needed
        tcp_to->doff    = tcpsize>>2;
        tcp_to->res1=0;
        tcp_to->syn=0;
        tcp_to->rst=0;
        tcp_to->urg=0;
        tcp_to->urg_ptr = 0;
        tcp_to->ece=0; //rack->ece;
        tcp_to->cwr=0; //ack->cwr;
        tcp_to->fin=0; //ack->fin;
        tcp_to->psh=0;//rack->psh;
        if(rack->psh)
        	tcp_to->psh = 1;
        if(rack->fin)
        	tcp_to->fin = 1;
        tcp_to->ack = 1;

        if(unlikely(rack->sack) || likely(rack->tstamp))
            tcp_opt_write((__be32 *)(tcp_to+1), rack);
        //calculate TCP checksum information
        tcp_to->check=0;
        tcp_to->check = csum_tcpudp_magic(iph_to->saddr, iph_to->daddr, tcpsize, iph_to->protocol, csum_partial((char *)tcp_to, tcpsize, 0));
        skb->ip_summed = CHECKSUM_UNNECESSARY;
        //------------------PUSH ETHERNET AND IP-------------------------

        skb_push(skb, iphsize);
        skb_push(skb, ethsize);

        //------------------Padding-------------------------
        if (skb->len < ETH_ZLEN)
            skb_pad(skb, ETH_ZLEN - skb->len);

        /*if (skb->len < ETH_ZLEN) {
        length = ETH_ZLEN;
        memset(&skb->data + skb->len, 0, length - skb->len);
        } else {
        length = skb->len;
        }
        skb->len = length;*/

        /*if(padsize > 0)
        {
        	//add padding
        	padding = skb_put(skb, padsize);
        	memcpy(padding, junk, padsize);
        }*/

        /*if(debug)
        {
            dev_hold(skb->dev);
            trace_printk("%s:%pI4:%pI4 SKB dev is OK, ack:%u relack:%u \n", skb->dev->name, &iph_to->saddr, &iph_to->daddr, ntohl(tcp_to->ack_seq), rack->relastack);
            dev_put(skb->dev);
        }*/
        //ret = ip_local_out(skb);
        //ret = dev_loopback_xmit(skb);

        ret = dev_queue_xmit(skb);
        if(ret<0)
        {
            if(debug>=1)
                trace_printk(KERN_INFO " Dev Queue XMIT failed: %d \n", ret);
            return 0;
        }
        /*else
        	trace_printk(KERN_INFO " Dev Queue XMIT success: %d %d %d %d %d\n", ret, size, ethsize, iphsize, tcpsize);*/

        return 1;
    }

    return 0;
}

#endif
