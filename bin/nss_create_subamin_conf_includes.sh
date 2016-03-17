#!/usr/bin/ksh
#
# (c) Peter Krauspe 11/2015
#
# This script runs on remote nss or resource nss and is normaly called from admin_reconfigure_nscs.sh
# It cretes an include File for SubAdmin_PSP.conf which containes 
# the available psps on a resource or remote domain
# In case of a resource domain, theese are the remaining psps which are not configured into other domains
# In case of a remote domain theese are the configured remote psp's coming from a resource domain
#
# TODO: erzeugt muelll !!!
# <2step>
. /etc/2step/2step.vars
#
basedir=/opt/dfs/tsctl2
bindir=${basedir}/bin
confdir=${basedir}/config
vardir=${basedir}/var

source ${confdir}/remote_nsc.cfg # providing:  subtype, ResourceDomainServers, RemoteDomainServers
[[ -f ${confdir}/remote_nsc.${dn}.cfg ]] && source ${confdir}/remote_nsc.${dn}.cfg # read domain specific cfg

#typeset include_dir=~spv/newsim_rel1/active_release/system
typeset include_dir=$vardir
typeset include_file=${include_dir}/SubAdmin_PSP.conf

typeset mode
typeset include_file_head_tmp=/tmp/subadmin_conf_include_file_head.tmp

cat <<-EOF > $include_file_head_tmp
 #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 #          REMOTE PSEUDO PILOT POSITIONS
 #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

EOF

FQDNS=$(nsc_adm -q nsc | grep psp)

# write header

cp $include_file_head_tmp  $include_file 

# write entrys

for fqdn in $FQDNS
do
  hn=${fqdn%%.*}
  hn_base=${hn%-s1}
  echo "GROUP_DEF Pseudo_Pilot $hn_base  $hn/psp_smap" >> $include_file
done

