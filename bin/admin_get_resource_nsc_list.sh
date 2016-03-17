#!/usr/bin/ksh
#
# (c) Peter Krauspe 10/2015
#
# This script should run on admin machine
# creates a list of all resource NSC's (resource_nsc.list) from each resource domain including  MAC adresses
#
# <2step>
. /etc/2step/2step.vars
#
# Changes:
#
# 14.01.2016: sort output lists by hn

#dbg=echo
dbg=""
dev=eth0
# ggfs spaeter aus config file
basedir=/opt/dfs/tsctl2
bindir=${basedir}/bin
confdir=${basedir}/config
vardir=${basedir}/var
arg1=$1

source ${confdir}/remote_nsc.cfg # providing:  subtype, ResourceDomainServers, RemoteDomainServers
[[ -f ${confdir}/remote_nsc.${dn}.cfg ]] && source ${confdir}/remote_nsc.${dn}.cfg # read domain specific cfg

resource_nsc_list_file=${vardir}/resource_nsc.list
target_config_list_file=${vardir}/target_config.list
remote_nsc_list_file=${vardir}/remote_nsc.list

[[ -f $resource_nsc_list_file ]] && rm $resource_nsc_list_file

for resource_domain_server in $ResourceDomainServers
do
   resource_dn=${resource_domain_server#*.}
   RESOURCE_FQDNS=$(ssh $resource_domain_server 'cd /srv/inst/xchg/client/config; ls -d '$subtype'*' | sort -V)

   [[ -d ${vardir}/$resource_dn ]] || mkdir -p ${vardir}/$resource_dn


   for resource_fqdn in $RESOURCE_FQDNS
   do
     resource_hn=${resource_fqdn%%.*}
     resource_nsc_mac=$(ssh ${resource_domain_server} grep ^dm /srv/inst/xchg/client/config/${resource_fqdn}/2step.vars)
     resource_nsc_mac=${resource_nsc_mac#dm=}
     resource_nsc_mac=${resource_nsc_mac#\"}
     resource_nsc_mac=${resource_nsc_mac%\"}
     
     #echo "$resource_fqdn: $resource_hn $resource_nsc_mac"
     echo "$resource_fqdn $resource_nsc_mac" >> $resource_nsc_list_file     
   done
   #echo "----------------------------------"
done

if [[ ! -f $target_config_list_file && $arg1 != "--no-target-config-list" ]]; then
  echo "No $target_config_list_file. "
  echo "Creating new without assignments"
  echo "# place "force_reconfigure" at end of line to reconfigure when occpied" >  $target_config_list_file
  if [[ -f $remote_nsc_list_file ]] ; then
   echo "#"                           >> $target_config_list_file
   echo "# Possible remote nsc fqdns" >> $target_config_list_file
   echo "#"                           >> $target_config_list_file
   awk '{print "#", $1}' $remote_nsc_list_file >> $target_config_list_file
   echo "#"                           >> $target_config_list_file
   echo "# Assign just by adding a remote nsc after the resource nsc" >> $target_config_list_file
   echo "#"                           >> $target_config_list_file
   echo "# RESOURCE-NSC (the physical machine)\tREMOTE-NSC (the hostname in the remote system)" >> $target_config_list_file
   echo "#"                           >> $target_config_list_file
  fi
  awk '{print $1}' $resource_nsc_list_file >> $target_config_list_file
fi
