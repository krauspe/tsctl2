#! /usr/bin/ksh
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

typeset -u FQDN
typeset -u MY_TYPE

DomainServers=$(echo $RemoteDomainServers $ResourceDomainServers | sed 's/\s/\n/g' | sort -u)

#for my_type in rnsc
for my_type in rnsc nsc
do
  MY_TYPE=$my_type

  for fqdn in $DomainServers
  do
    FQDN=$fqdn
    echo "\n$FQDN ${MY_TYPE}-LIST:\n"
    ssh $fqdn nsc_adm -q $my_type
  done
done
