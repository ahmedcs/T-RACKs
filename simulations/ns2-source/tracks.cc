/*
 *  T-RACKs - The ns2 simulator implementation of Timely ACKs Retransmission for Data Center
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

#include <fstream>
#include "scheduler.h"
#include "packet.h"
#include<iostream>
#include "random.h"
#include "tcp-full.h"

#include "tracks.h"


static class RACKTclClass : public TclClass
{
public:
    RACKTclClass() : TclClass("RACK") {}
    TclObject* create(int, const char*const*)
    {
        return (new RACK);
    }
} class_rack ;

RACK::RACK() : Connector(),  logging(0),  alpha_update_timer_(NULL)

{
    init_variables();
    setupTimers();
}

/*************************Ahmed********************************************/
inline void RACK::reset_state()
{
	last_pkt = NULL;
    last_ack = -1;
    last_seq = -1;
    sent_bytes = 0;
    dup_ack = 0	;
    dup_retrans = false;
    last_arrive = last_dupack = last_sent = dup_retrans_time =0.0;
    recv_pkts = recv_bytes = 0;
    waittime = 0.0;
    backoff = 1;
    uidcnt_=0;
    sentout=3;
}

inline void RACK::soft_reset()
{
	//last_pkt = NULL;
    dup_ack = 0	;
    dup_retrans = false;
    dup_retrans_time = -1.0;
    last_arrive = last_dupack = last_sent = 0.0;
    backoff = 1;
    sentout=3;
}

void RACK::init_variables()
{
    eleph_thresh_=0;
    eleph_=0;
    vmdelay = 0.005;
    packetdelay = 0.000012;
    Te_=0.00005;
    RTT = 0.0001;
    flows=0;
    debug_=0;
    rev_rack_ = NULL;
    enabled=false;


    reset_state();
}

void RACK::setupTimers()
{
    alpha_update_timer_ = new RACKTimer(this, &RACK::Te_timeout);
    //queue_timer_ = new RWNDTimer(this, &RWNDQueue::Tq_timeout);
    // Scheduling timers randomly so routers are not synchronized
    double T;

    T= Random::normal(Te_, 0.2 * Te_);
    alpha_update_timer_->sched(T);

}

void RACKTimer::expire(Event *)
{
    (*a_.*call_back_)();
}

void RACK::senddupacks(Packet* pkt, int times, bool data)
{
	if(!pkt)
		return;

    double now = Scheduler::instance().clock();
    Packet* temp;
    double delay = Random::normal(RTT, 0.2 * RTT);

    for(int i=0; i<times; i++)
    {
	    if(target_)
	    {
            temp = copypkt(pkt);
            hdr_cmn* hc = hdr_cmn::access(temp);
            if(data)
                hc->size() += 1;
    		hdr_tcp *tcph = hdr_tcp::access(temp);
            struct hdr_ip *iph = HDR_IP(temp);
	        int fid=iph->fid_;
		   
		    if(debug_ >= 1)
                //cout<<"RACK"<<name()<<": "<<now  + delay + i * packetdelay<<" RETRANS FID : "<<fid<<" seq: "<<tcph->seqno()<<" ack: "<<tcph->ackno()<<" sent pkt: "<<(i+1)<<" TTL: "<<iph->ttl()<<endl;
	        Scheduler::instance().schedule(target_, temp, delay + i * packetdelay);  //i * packetdelay);
	    }
	    else
            cout<<"target is null can not send"<<endl;
    }

}

void RACK::Te_timeout()
{
    double now = Scheduler::instance().clock();
    double totRTT = RTT; //(2 * vmdelay + RTT);
    int fid, ackno, seqno;

   //if((sent_bytes <= 111000 || eleph) && enabled)
    if(enabled && last_pkt && (eleph_ || sent_bytes <= eleph_thresh_ ))
    {
		fid = HDR_IP(last_pkt)->flowid();
		ackno = hdr_tcp::access(last_pkt)->ackno();
		seqno = hdr_tcp::access(last_pkt)->seqno();
		
		if(ackno >= 1 && rev_rack_ && rev_rack_->last_seq>=1 && ackno <= rev_rack_->last_seq)
		 {
			//RACK timeout expired
			if(!dup_retrans)
			{
				double t = max(rev_rack_->last_sent, last_arrive);
				if ( t > 0 && now - t > 10 * backoff * totRTT)
				{
					if(debug_ >= 2)
						cout<<"RACK"<<name()<<": "<<Scheduler::instance().clock()<<" TIMEOUT FID : "<<fid<<": Last ACK: "<<ackno<<" sent times: "<<sentout - dup_ack<<" last arrive: "<<last_arrive<<" last dup trans: "<<dup_retrans_time<<endl;

					senddupacks(last_pkt, sentout, false);
					dup_retrans = true;
					dup_retrans_time = now;
				}
			}
			//Perform Exponential BACKOFF
			else 
			{
				double t = max(last_arrive, dup_retrans_time);
				if(t > 0 && now - t > 10 * (backoff) * totRTT)
				{
					senddupacks(last_pkt, 1, true);
					backoff*=2;
					dup_retrans = true;
					dup_retrans_time = now;
					//sentout+=1;
					if(debug_ >= 2 )
						cout<<"RACK"<<name()<<": "<<Scheduler::instance().clock()<<" BACKOFF FID : "<<fid<<": Last ACK: "<<ackno<<" sent times: "<<sentout - dup_ack<<" last arrive: "<<last_arrive<<" last dup trans: "<<dup_retrans_time<<endl;
				}
			}	

		}
		//reset if we are almost reaching timeout
		if(last_arrive > 0 && now - last_arrive >= 0.15)
		{
			soft_reset();
		}
    }
    alpha_update_timer_->resched(Te_);
}

Packet* RACK::copypkt(Packet* p2)
{
    double now = Scheduler::instance().clock();
	Packet* p1 = Packet::alloc();

	hdr_cmn* ch1 = hdr_cmn::access(p1);
	hdr_cmn* ch2 = hdr_cmn::access(p2);
	ch1->uid() = uidcnt_++;
	ch1->ptype() = ch2->ptype();
	ch1->size() = ch2->size();
	//ch1->timestamp() = Scheduler::instance().clock() + RTT + vmdelay;
	ch1->iface() = ch2->iface();//UNKN_IFACE.value(); // from packet.h (agent is local)
	ch1->direction() = ch2->direction();

	ch1->error() = 0 ;	/* pkt not corrupt to start with */

	hdr_ip* iph1 = hdr_ip::access(p1);
	hdr_ip* iph2 = hdr_ip::access(p2);
	iph1->saddr() = iph2->saddr();
	iph1->sport() = iph2->sport();
	iph1->daddr() = iph2->daddr();
	iph1->dport() = iph2->dport();

	iph1->flowid() = iph2->flowid();
	iph1->prio() = iph2->prio();

	//USE TTL of 127 for RACK to distinguish it from other DUPACKs
	iph1->ttl() = 127; //iph2->ttl();

	hdr_flags* hf1 = hdr_flags::access(p1);
	hdr_flags* hf2 = hdr_flags::access(p2);
	hf1->ecn_capable_ = hf2->ecn_capable_;
	hf1->ecn_ = hf2->ecn_;
	hf1->ect() = hf2->ect();
	hf1->ecnecho() = 0; //hf2->ecnecho();
	hf1->eln_ = hf2->eln_;
	hf1->ecn_to_echo_ = hf2->ecn_to_echo_;
	hf1->fs_ = hf2->fs_;
	hf1->no_ts_ = hf2->no_ts_;
	hf1->pri_ = hf2->pri_;
	hf1->cong_action_ = hf2->cong_action_;
	hf1->qs_ = hf2->qs_;

	hdr_tcp *tcph1 = hdr_tcp::access(p1);
	hdr_tcp *tcph2 = hdr_tcp::access(p2);

	/* build basic header w/options */

  tcph1->seqno() = tcph2->seqno();
  tcph1->ackno() = tcph2->ackno();

        //Set only the ACK flag on the outgoing packet
        tcph1->flags() = 0;//tcph2->flags();
        tcph1->flags() = TH_ACK;

        tcph1->reason() = tcph2->reason(); // make tcph->reason look like ns1 pkt->flags?
		tcph1->sa_length() = tcph2->sa_length() ;    // may be increased by build_options()
        tcph1->hlen() = tcph2->hlen();

	return p1;
}


void RACK::recv(Packet *p, Handler *h)
{
    double now = Scheduler::instance().clock();
    double totRTT = (2 * vmdelay + RTT);
    struct hdr_ip *iph = HDR_IP(p) ;
    int fid=iph->fid_;
    recv_pkts++;

    if(enabled)
    {
            hdr_flags* hf = hdr_flags::access(p);
            hdr_cmn* hc = hdr_cmn::access(p);
            if(hc->ptype()==PT_TCP || hc->ptype()==PT_ACK)
            {
                hdr_tcp *tcph = hdr_tcp::access(p);
                if(!tcph)
                {
                     target_->recv(p,h);
                     return;
                }

                int datalen = hc->size() - tcph->hlen(); // # payload bytes
                recv_bytes += datalen;
                int tiflags = tcph->flags() ; 		 // tcp flags from packet
                int ackno=tcph->ackno();		 // ack # from packet


                //Reset in case of SYN, FIN
                if((tcph->flags() & TH_SYN) || (tcph->flags() & TH_FIN))
                {
                	reset_state();
                	if(rev_rack_)
                		rev_rack_->reset_state();
                         if((tcph->flags() & TH_FIN))
                		cout<<"RACK-FIN"<<name()<<": "<<now<<" FID : "<<fid<<" seqno : "<<tcph->seqno()<<" old seq: "<<last_seq<<" last ACK: "<<rev_rack_->last_ack<<" last sent: "<<last_sent<<" data len: "<<datalen<<endl;
                    target_->recv(p,h);
                    return;
                }

                //If in persistent mode, Reset on CWR along with a data packet when operating in persistent mode
                if((!(tcph->flags() & TH_ACK) && hf->cong_action_))
                {
                	reset_state();
                	rev_rack_->reset_state();
                	cout<<"RACK-CWR"<<name()<<": "<<now<<" DATA FID : "<<fid<<" seqno : "<<tcph->seqno()<<" old seq: "<<last_seq<<" last ACK: "<<rev_rack_->last_ack<<" last sent: "<<last_sent<<" data len: "<<datalen<<endl;
                }


                if(debug_ >= 2 && datalen > 0 && rev_rack_)
                	cout<<"RACK"<<name()<<": "<<now<<" DATA FID : "<<fid<<" seqno : "<<tcph->seqno()<<" old seq: "<<last_seq<<" last ACK: "<<rev_rack_->last_ack<<" last sent: "<<last_sent<<" data len: "<<datalen<<endl;

                if(datalen > 0 && rev_rack_ && tcph->seqno() == rev_rack_->last_ack)
                        cout<<"RACK"<<rev_rack_->name()<<": "<<now<<" RACK RECOVERY FID : "<<fid<<" RACK: "<<rev_rack_->last_ack<<" TRNSTIME:  "<<rev_rack_->dup_retrans_time<<" last sent: "<<last_sent<<" highest seq: "<<last_seq<<" data len: "<<datalen<<endl;

            	//Data Packet store the seq number if it is higher than the last_seq
               if(datalen > 0 && tcph->seqno() > last_seq) //&& (eleph_ || tcph->seqno() <= eleph_thresh_))
                {
                    last_seq = tcph->seqno();
                    last_sent = now; // = rev_rack_->last_arrive = now;
                }

     			//ACK packet store the packet and count dupacks, drop dupacks if you are in state of dup_trans
                if( datalen==0 && (tiflags & TH_ACK) && tcph->ackno() > 0 && ackno >= 1 ) //&& (eleph_ || sent_bytes <= eleph_thresh_))
                {
                    if (ackno > last_ack)
                    {
                        if(last_pkt != NULL)
                        {
                            Packet::free(last_pkt);
                            last_pkt = NULL;
                        }
                        if(debug_ >= 2 && rev_rack_)
                            cout<<"RACK"<<name()<<": "<<now<<" COPY PACKET FID : "<<fid<<" old ACK: "<<last_ack<<" new ack: "<<ackno<<" last seq: "<<rev_rack_->last_seq<<" last data time: "<<rev_rack_->last_arrive<<endl;
                        last_pkt = copypkt(p);

                        dup_ack = 0;
                        sentout = 3;
                        backoff = 1;
                        dup_retrans = false;
                        dup_retrans_time = -1.0;
                        last_arrive = now;
                        if(debug_ >= 2 && rev_rack_ && last_pkt)
                            cout<<"RACK"<<name()<<": "<<now<<" NEW ACK FID : "<<fid<<" old ACK: "<<last_ack<<" new ack: "<<ackno<<" stored ack: "<<hdr_tcp::access(last_pkt)->ackno()<<" last sent: "<<rev_rack_->last_seq<<" last data time: "<<rev_rack_->last_arrive<<endl;
                    	  last_ack = sent_bytes = ackno;

                    }
                    else if(ackno==last_ack && ackno > 1)
                    {
                        
                          last_dupack=now;
                           dup_ack++;
                     }
                    else
                     dup_ack=0;
                }
            }

    }

    target_->recv(p,h);
    //Scheduler::instance().schedule(target_, p, now + vmdelay);
    return;

}

int RACK::command(int argc, const char* const*argv)
{
    if (argc==3)
    {
        /**************************Ahmed**************************/
        if (strcmp("set-enabled", argv[1])==0)
        {
            enabled = atoi(argv[2]);
	    cout<<"RACK: enabled is set to "<<enabled<<endl;
            return TCL_OK ;
        }

	if (strcmp("set-eleph", argv[1])==0)
        {
            eleph_ = atoi(argv[2]);
	    	cout<<"RACK: eleph is set to "<<eleph_<<endl;
            return TCL_OK ;
        }

	if (strcmp("set-vmdelay", argv[1])==0)
        {
            vmdelay = atof(argv[2]);
	    cout<<"RACK: vmdelay is set to "<<vmdelay<<endl;
            return TCL_OK ;
        }

	if (strcmp("set-RTT", argv[1])==0)
        {
            RTT = atof(argv[2]);
	    cout<<"RACK: RTT is set to "<<RTT<<endl;
            return TCL_OK ;
        }

    if (strcmp("set-debug", argv[1])==0)
    {
        debug_ = atoi(argv[2]);
	    cout<<"RACK: Debug is set to "<<debug_<<endl;
        return TCL_OK ;
    }


 	if (strcmp(argv[1], "reverse-rack") == 0)
        {
            if (*argv[2] == '0')
            {
                rev_rack_ = 0;
                return (TCL_OK);
            }
            rev_rack_ = (RACK*)TclObject::lookup(argv[2]);
            if (rev_rack_ == 0)
            {
                Tcl& tcl = Tcl::instance();
                tcl.resultf("no such object %s", argv[2]);
                return (TCL_ERROR);
            }
            cout << "RACK: reverse rack has been set to :"<<rev_rack_->name()<<endl;
            return (TCL_OK);
        }

	   if (strcmp("set-elephthresh", argv[1])==0)
        {
            eleph_thresh_ = atoi(argv[2]);
            cout<<"Elephant threshold is set to "<<eleph_thresh_<<endl;
            return TCL_OK ;
        }
        return Connector::command(argc,argv) ;
        /**************************Ahmed**************************/
    }

    return Connector::command(argc, argv) ;
}


void RACK::logto(string logfilename)
{
    if(logging)
        return;
    logging=1;
    logfile.open(logfilename.c_str());
}
