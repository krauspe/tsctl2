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
basedir=/opt/dfs/tsctl2
bindir=${basedir}/bin
confdir=${basedir}/config
vardir=${basedir}/var

source ${confdir}/remote_nsc.cfg # providing:  subtype, ResourceDomainServers, RemoteDomainServers

for fqdn in $RemoteDomainServers
do
  ssh $fqdn '[ -f /nss/home/remote_adm/config/rnsc.all.hosts ] && > /nss/home/remote_adm/config/rnsc.all.hosts'
done
