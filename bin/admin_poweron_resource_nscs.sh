#!/usr/bin/ksh
#
# (c) Peter Krauspe 7/2015
#
# This script should run on an admin machine. 
# It wakes up all resource NSC's of all resource domains 
# it should be run BEVORE admin_deploy_configs.sh as necessary 
#
#
# <2step>
. /etc/2step/2step.vars
#
dbg=echo
dbg=""
dev=eth0
# ggfs spaeter aus config file
basedir=/opt/dfs/tsctl2
bindir=${basedir}/bin
confdir=${basedir}/config
vardir=${basedir}/var

source ${confdir}/remote_nsc.cfg # providing:  subtype, ResourceDomainServers, RemoteDomainServers

echo "<< Poweron all Resource NSC's >>"

for resource_domain_server in $ResourceDomainServers
do
  if [[ $resource_domain_server != $(dnsdomainname) ]]; then
    ssh $resource_domain_server nsc_poweron $subtype
  fi
done

