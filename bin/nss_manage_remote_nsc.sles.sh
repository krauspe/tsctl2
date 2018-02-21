#!/usr/bin/ksh
#
# (c) Peter Krauspe 10/2015
#
# This script runs on an NSS of a Remote Domain (e.g. mu1.muc.dfs,de or ka1.krl.dfs.de) 
# Remote Domains are those who want to use a remote NSC (e.g. PSP) from a Resource Domain (e.g. ak3.lgn.dfs.de )
#
# It does 3 jobs:
#
# 1. Create a list (remote_nsc.list) of the local remote NSCs which may be determined by the DNS txt record "rnsc=1"
#    This list will be collected from an admin machine which controls the remote NSC configuration
#
# 3. Create 2step.vars files for each host of the above list to create it's network configuration
# 2. Checks Status of all hosts  from the list by pinging them  
#
# All 2step.vars files musst be collected from admin machine and distributed on any NSC in any Resource Domain
# With theese files it is possible to configure every resource NSC from any Resource Domain to run in any Remote Domain 
#
# Changes:
#
# 14.01.2016: - added option "clean_hostlists"
#             - improved output for option "list": lists resource_fqdn and mac for each remote_fqdn (from rnsc.all.hosts)
# 24.10.2017: - get_remote_nsc_status(): use fqdn_default instaed of fqdn 
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
typeset remote_fqdn
arg1=$1
arg2=$2
arg3=$3
typeset force_search=0

[[ -n $arg3 && $arg3 == "--force_search" ]] && force_search=1

source ${confdir}/remote_nsc.cfg # providing:  subtype, ResourceDomainServers, RemoteDomainServers
[[ -f ${confdir}/remote_nsc.${dn}.cfg ]] && source ${confdir}/remote_nsc.${dn}.cfg # read domain specific cfg

function check_host_alive
{
  typeset host=$1
  ping -c 1 $host > /dev/null
  if (( $? > 0 )) ; then
    echo "unreachable" 
  else
    echo "alive"
  fi
}

function check_ssh
{
  typeset fqdn=$1
  ssh $fqdn uptime  > /dev/null 2>&1 
  if (( $? > 0 )) ; then
    echo "ssh-failed"
  else
    echo "ssh-ok"
  fi
}

function get_remote_nsc_status
{
  typeset fqdn=$1
  typeset resource_fqdn
  typeset fqdn_live_status
  typeset fqdn_ssh_status
  typeset ret
  typeset status

  fqdn_live_status=$(check_host_alive $fqdn)

  if [[ $fqdn_live_status == "alive" ]] ; then
    fqdn_ssh_status=$(check_ssh $fqdn)
    if [[ $fqdn_ssh_status == "ssh-ok" ]] ; then
      resource_fqdn=$(ssh ${fqdn} grep ^fqdn_default /etc/2step/2step.vars)
      resource_fqdn=${resource_fqdn#fqdn_default=}
      resource_fqdn=${resource_fqdn#\"}
      resource_fqdn=${resource_fqdn%\"}
      [[ -z $resource_fqdn ]] && resource_fqdn="not_found"
      status="occupied"
    else
      resource_fqdn="unknown"
      status=$fqdn_ssh_status
    fi
  else
    resource_fqdn="unknown"
    status=$fqdn_live_status
  fi
  echo "$resource_fqdn $status"
}

function clean_hostlists
{
  typeset fqdn=$1
  echo $REGISTERD_REMOTE_NSCS | grep $fqdn > /dev/null
  if (( $? == 0 )); then
    echo "clean hostlist from $fqdn for type rnsc"  
    nsc_adm del $remote_fqdn rnsc  > /dev/null 2>&1
  fi
  echo $NSCS | grep $fqdn > /dev/null
  if (( $? == 0 )); then
    echo "clean hostlist from $fqdn for type nsc"  
    nsc_adm del $remote_fqdn nsc  > /dev/null 2>&1
  fi
}

# create a list beginning with registered remote_nscs 
# for faster getting the status below 

REMOTE_NSC_FQDNS_ALL=$(host -l -t txt $dn | awk '/rnsc=1/{print $1}')  # get all (possible) remote nsc fqdns
REGISTERD_REMOTE_NSCS=$(nsc_adm -q rnsc)  # get all entrys from rnsc.all.hosts if any 
NSCS=$(nsc_adm -q nsc)  # get all entrys from rnsc.all.hosts if any 

#echo "REMOTE_NSC_FQDNS_ALL=$REMOTE_NSC_FQDNS_ALL"
#echo "REGISTERD_REMOTE_NSCS=$REGISTERD_REMOTE_NSCS"

REMOTE_NSC_FQDNS=$REGISTERD_REMOTE_NSCS

if (( $force_search == 1 )) ; then
  if [[ -n $REGISTERD_REMOTE_NSCS ]] ; then
    for remote_fqdn in $REMOTE_NSC_FQDNS_ALL
    do
      echo $REGISTERD_REMOTE_NSCS | grep $remote_fqdn > /dev/null 2>&1
      #if (( $? > 0 )); then
      if (( $? == 0 )); then
        REMOTE_NSC_FQDNS="$REMOTE_NSC_FQDNS $remote_fqdn"
      fi
    done
  else
    REMOTE_NSC_FQDNS=$REMOTE_NSC_FQDNS_ALL
  fi
fi

#echo "REMOTE_NSC_FQDNS=$REMOTE_NSC_FQDNS"

case $arg1 in 

  # CREATE CONFIGS

  create_configs) 

    echo "\n<< Creating network config for alle remote nsc's defined in this domain ($dn)>>\n"
  
   [[ -d ${vardir}/$dn ]] || mkdir -p ${vardir}/$dn
   [[ -f ${vardir}/${dn}.remote_nsc.list ]] && rm ${vardir}/${dn}.remote_nsc.list
  
   for remote_nsc_fqdn in $REMOTE_NSC_FQDNS_ALL
   do
     remote_hn=${remote_nsc_fqdn%%.*}
     ${bindir}/2step-get-infos-local --no-bootargs --no-dhcp hn=$remote_nsc_fqdn  > ${vardir}/${dn}/${remote_hn}.2step.vars
     echo "${remote_hn}.${dn} >> ${vardir}/${dn}.remote_nsc.list"
     echo ${remote_hn}.${dn} >> ${vardir}/${dn}.remote_nsc.list
   done
   ;;

  # GET STATUS

  status)
    found=0
    for remote_fqdn in $REMOTE_NSC_FQDNS
    do
      remote_nsc_status=$(get_remote_nsc_status $remote_fqdn)
      resource_fqdn=${remote_nsc_status% *}
      status=${remote_nsc_status#* }

      if [[ -n $arg2 ]] ;then
         if [[ $resource_fqdn == $arg2 ]]; then
           echo "$remote_fqdn $status"
           break
         fi
      else
        echo "$remote_fqdn $status"
      fi
    done 
    ;;

  clean_hostlists)

    found=0
    if [[ -n $arg2 ]] ;then
      remote_fqdn=$arg2
      clean_hostlists $remote_fqdn >2&
    else
      for remote_fqdn in $REMOTE_NSC_FQDNS
      do
        echo "checking: $remote_fqdn"
        remote_nsc_status=$(get_remote_nsc_status $remote_fqdn)
        resource_fqdn=${remote_nsc_status% *}
        status=${remote_nsc_status#* }
  
        if [[ $status == "unreachable" ]]; then
          echo "removing $remote_fqdn from hostlists..."
          clean_hostlists $remote_fqdn >2&
        fi
  
      done 
    fi
    ;;


  list) 

   #for remote_fqdn in $REMOTE_NSC_FQDNS_ALL
   #do
   #  echo $remote_fqdn
   #done

   nsc_adm -q rnsc "resource_fqdn mac"

   ;;

  *)
    echo "\nusage: $(basename $0) [ create_configs | status | list | clean_hostlists] [<remote_fqdn>]|[<resource_fqdn>] [--force_search]"
    echo "    create_configs: create configs for remote nsc's (e.g. remote psp's)"
    echo "            status: without arguments: get status on remote nsc's"
    echo "            status: with argument <resource_fqdn>: get status on remote nsc's"
    echo "            list: list remote nsc's , with their mac and resource nsc's "
    echo " clean_hostlists: without arguments: delete all remote_fqdns from hostslists whih are not reachable"
    echo " clean_hostlists: with argument <remote_fqdn>: delete given remote_fqdn from hostlists"
    echo " --force_search:  check all possible remote_fqdn's, not only those from rnsc.all.hosts\n"
   ;;

    
esac
