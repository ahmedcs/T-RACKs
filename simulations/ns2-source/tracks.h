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

#ifndef NS_TRACKS_H
#define NS_TRACKS_H
#include <map>
#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <fstream>

#include "drop-tail.h"
#include "packet.h"
#include "tcp.h"
#include "ip.h"
#include "flags.h"
#include "packet.h"
#include "connector.h"
#include "queue.h"
#include "node.h"

using namespace std;

class RACK;

class RACKTimer : public TimerHandler
{
public:
    RACKTimer(RACK *a, void (RACK::*call_back)() )
        : a_(a), call_back_(call_back) {};
protected:
    virtual void expire (Event *e);
    RACK *a_;
    void (RACK::*call_back_)();
};


class RACK: public Connector
{
    friend class RACKTimer;
protected:

    // Utility Functions
    double max(double d1, double d2) { return (d1 > d2) ? d1 : d2; }
    double min(double d1, double d2) { return (d1 < d2) ? d1 : d2; }
    int max(int i1, int i2) { return (i1 > i2) ? i1 : i2; }
    int min(int i1, int i2) { return (i1 < i2) ? i1 : i2; }
    double abs(double d) { return (d < 0) ? -d : d; }
    /*************************Ahmed********************************************/
    double Te_;
    double vmdelay;
    double packetdelay;
    int debug_;
    RACKTimer* alpha_update_timer_;
    int flows;
    bool enabled, eleph_;
    int eleph_thresh_;
    double last_arrive, last_dupack;
    Packet* last_pkt;   
    int last_ack;
    int dup_ack;
    int backoff;
    double waittime;
    double RTT;
    bool dup_retrans;
    double dup_retrans_time;
    int recv_pkts;
    int recv_bytes;
    int sent_bytes;
    long int uidcnt_;
    int sentout, retrans;
    /*************************Ahmed********************************************/
    int logging;
    ofstream logfile;

public:


    RACK();
    inline void reset_state();
    inline void soft_reset();
    Packet* copypkt(Packet *p2);
    void recv(Packet *p, Handler *h);
    void logto(string logfile);
    int command(int argc, const char*const* argv) ;
    /*************************Ahmed********************************************/
    //bool debug_;
    //Node* rev_target_;
    RACK* rev_rack_;
    int last_seq;
    double last_sent;
    //Scheduler& sched;
    void senddupacks(Packet*, int, bool);
    void init_variables();
    void setupTimers();
    void Te_timeout();
    /*************************Ahmed********************************************/
} ;

#endif
