#!/usr/bin/ksh
#
# (c) Peter Krauspe 10/2015
#
#
# <2step>
. /etc/2step/2step.vars
#
#dbg=echo
dbg=""
dev=eth0
# ggfs spaeter aus config file
bindir=${0%/*}
basedir=${bindir%/*}
confdir=${basedir}/config
vardir=${basedir}/var

source ${confdir}/remote_nsc.cfg # providing:  subtype, ResourceDomainServers, RemoteDomainServers
echo "basedir=$basedir"
echo "bindir=$bindir"
echo "confdir=$confdir"
echo "vardir=$vardir"
