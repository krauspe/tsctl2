#!/usr/bin/ksh
#
# (c) Peter Krauspe 10/2015
#
# This script should run on an admin machine. It syncs cached configs to given Remote NSC or all Remote's of all 
# Remote domians
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
instdir=${vardir}/install
remote_nsc_list_file=${vardir}/remote_nsc.list
typeset -A ResDomServer

source ${confdir}/remote_nsc.cfg # providing:  subtype, ResourceDomainServers, RemoteDomainServers
[[ -f ${confdir}/remote_nsc.${dn}.cfg ]] && source ${confdir}/remote_nsc.${dn}.cfg # read domain specific cfg

arg1=$1
arg2=$2

if [[ $# < 2 ]]; then
   echo "usage: $(basename $0) <action>  <RemoteNSC|all>"
   echo "   eg: $(basename $0) deploy:all       all   # create , collect  and deploy configs , and scripts (NO public keys) to all Servers and ResourceNSCs"
   echo "   eg: $(basename $0) deploy:all       psp1-s1.ak3.lgn.dfs.de  # as above, only for this host"
   echo "   eg: $(basename $0) deploy:keys      psp1-s1.ak3.lgn.dfs.de  # as above, but only ssh public"
   echo "   eg: $(basename $0) deploy:config    psp1-s1.ak3.lgn.dfs.de  # as above, but only tsctl2 and network config"
   echo "   eg: $(basename $0) deploy:scripts   psp1-s1.ak3.lgn.dfs.de  # as above, but only scripts"
   echo "   eg: $(basename $0) all|config|scripts|keys   all   # make everything due to action keyword but don't deploy to NSCs (PSPs) !!"
   exit 1
fi


function check_host_alive
{
  typeset host=$1
  ping -c 1 $host > /dev/null
  if (( $? == 0 )) ; then
    echo 1
  else 
    echo 0
  fi
}


for resource_domain_server in $ResourceDomainServers
do
  resource_dn=${resource_domain_server#*.}
  resource_hn=${resource_domain_server%%.*}
  ResDomServer[$resource_dn]=$resource_hn  
done

# set ResourceDomainServers as target list for default
TargetResourceDomainServers=$ResourceDomainServers

# check command line args and process dn and hn for single nsc deployment

typeset -i single_nsc_deployment=0
typeset target=$subtype

if [[ $arg2 != "all" ]]; then
  arg_dn=${arg2#*.}
  arg_hn=${arg2%%.*}
  echo "arg_dn=$arg_dn"
  echo "arg_hn=$arg_hn"
  if [[ $arg_dn != $arg_hn  ]] ; then
     resdom_server_dn=$arg_dn
     resdom_server_hn=${ResDomServer[$arg_dn]}
    if [[ -n $resdom_server_hn ]] ; then
       resdom_server_fqdn=${resdom_server_hn}.${resdom_server_dn} 
      if [[ $(check_host_alive ${resdom_server_fqdn}) == 1 ]]; then
        TargetResourceDomainServers=$resdom_server_fqdn
        single_nsc_deployment=1
        target=${arg_hn}.${arg_dn}
        echo
        echo "OK found and reached $resource_domain_server "
        echo "Will deploy stuff ONLY to following NSC: $target "
        echo "Existence and reachability of $target is not checked at this point ! "
        echo "------------------------------------------------"
      else
        echo "can't reach $resource_domain_server, exiting"
        exit 1
      fi  
    else
      echo "No resource domain server found for $arg2, exiting"
      exit 1
    fi
  else
    echo "arg2 needs to be full qualified domin name of a Resource NSC !"
    exit 1
  fi
fi


for resource_domain_server in $TargetResourceDomainServers
do
    # sync all configd to nsc's
    echo "  syncing $resource_domain_server clients"
    echo "    syncing tsctl2 stuff"

    if [[ $arg1 == *keys* || $arg1 == *all* ]] ; then
      echo "    syncing authorized_keys"
      ssh $resource_domain_server "nsc_rsync ${vardir}/aks /root/.ssh $target"   > /dev/null 2>&1
      ssh $resource_domain_server "nsc_rsync /root/.ssh/id_dsa.pub /root/.ssh/id_dsa.pub.nss $target" > /dev/null 2>&1
      ssh $resource_domain_server "nsc_sh 'cd /root/.ssh; cat id_dsa.pub.nss aks > authorized_keys' $target"  > /dev/null 2>&1
    fi

    if [[ $arg1 == *config* || $arg1 == *all* ]] ; then
      echo "    syncing vardir and confdir"
      ssh $resource_domain_server "nsc_sh \"mkdir -p $bindir\" $target" > /dev/null 2>&1
      ssh $resource_domain_server "nsc_rsync $vardir $basedir $target "  > /dev/null 2>&1
      ssh $resource_domain_server "nsc_rsync $confdir $basedir $target " > /dev/null 2>&1
    fi

    if [[ $arg1 == *scripts* || $arg1 == *all* ]] ; then
      echo "    syncing scripts"
      ssh $resource_domain_server "nsc_rsync ${bindir}/nsc_reconfigure.sh ${bindir} $target"   > /dev/null 2>&1
      ssh $resource_domain_server "nsc_rsync ${bindir}/2step-get-infos-local ${bindir} $target" > /dev/null 2>&1
      ssh $resource_domain_server "nsc_rsync ${bindir}/2step-netconfig-local ${bindir} $target" > /dev/null 2>&1
    fi

    if [[ $arg1 == *xinitrc*  || $arg1 == *all* ]] ; then
      echo "    syncing xinitrc"
      ssh $resource_domain_server "nsc_sh '[ -f /etc/X11/xinit/xinitrc ] && mv /etc/X11/xinit/xinitrc /etc/X11/xinit/xinitrc.$$' $target" > /dev/null 2>&1
      ssh $resource_domain_server "nsc_rsync ${confdir}/xinitrc.${subtype} /etc/X11/xinit/xinitrc $target" > /dev/null 2>&1
    fi
    if [[ $arg1 == *wall_msg*  || $arg1 == *all* ]]; then
      echo "    syncing wall_msg script"
      ssh $resource_domain_server "nsc_rsync ${confdir}/set_wall_msg.sh /usr/local/share/wall_msg/bin $target" > /dev/null 2>&1
    fi

    if [[ $arg1 == *java*  || $arg1 == *all* ]] ; then
      echo "    syncing java ..."
      ufa_dir=/opt/ufa
      cmd="mkdir -p ${ufa_dir}"
      # ufa_dir auf allen resource_domain_server anlegen
      
      if [[ $resource_domain_server != $(dnsdomainname) ]]; then
          ssh $resource_domain_server $cmd  > /dev/null 2>&1
          # java auf alle resource_domain_server kopieren
	  rsync -ahH ${ufa_dir}/java ${resource_domain_server}:${ufa_dir} > /dev/null 2>&1
      fi
      # ufa dir auf allen nscs anlegen
      ssh $resource_domain_server "nsc_sh \"mkdir -p $ufa_dir\" $target" > /dev/null 2>&1
      # javadir auf alle nscs kopieren
      ssh $resource_domain_server "nsc_rsync ${ufa_dir}/java ${ufa_dir} $target"    > /dev/null 2>&1
    fi
done

echo "\nDone.\n"
