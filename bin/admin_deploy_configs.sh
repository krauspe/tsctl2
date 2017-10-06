#!/usr/bin/ksh
#
# (c) Peter Krauspe 10/2015
#
# This script should run on an admin machine. It collects network configurations for
# all Resource NSC's of all resource domains and syncs theese to all Remote NSC's of all Remote Domains
#
# So we can do an offline network reconfiguration on all resource NSC's fron all resource doamins
#
# changes:
# 01.12.2015: - added java deployment for atcoach
# 10.12.2015: - deploy ssh keys (aks) to ALL domain servers (not only remote) , because otherwise the "home nss" has no pwdless root acess on psp's
#             - fixed bug on mkdir commmands for bindir and java deployment
#
# 05.01.2016: - scripts NEEDS options now, otherwise usage output only !!
#             - create deploy options for selective deployments (more than java and wall_msg)
#               example: deploy:all or deploy:config
#             - add option to deploy to a single NSC rather than to all NSCs of a resource domain
#             - save ssh key deployment (backup old authorized keys)
#             - changed option for ssh keys from "aks" to "keys"
# 15.01.2016: - changed ssh key handling: deployment nss script ensures authorized key file with root public key and keys from all other nss'es
#               (without backup, which is no longer necessary)
# 17.03.2016: - deploy all nsc_* scripts to NSCs (bevor only the reconfigure script)
#             - new option: --update-resources:
#               forces update of resource nsc list even if it exists, without this option an existing list will not be overwritten
#             - added calling script "admin_get_rpms_from_repo.sh" which copies rpms to var/install from Repo for local install on NSC's
#             - changed cmdline handling: missing "deploy" string in first argumemt disables deploment to NSCs (independent of :<option>)
# 14.04.2016: - minor bugfix in print out
# 21.11.2016: - new option '--cached': use cached data on resource nss(ses), don't collect anything (useful for reinstalled KNOWN clients only !!)

#
#TODO: check changed cmdline handling for certain cases
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
   echo "usage: $(basename $0) <action>  <all|RemoteNSC> [--update-resources]"
   echo "   eg: $(basename $0) deploy:all       all   # create , collect  and deploy configs , and scripts (NO public keys) to all Servers and ResourceNSCs"
   echo "   eg: $(basename $0) deploy:all       psp1-s1.ak3.lgn.dfs.de  # as above, only for this host"
   echo "   eg: $(basename $0) deploy:keys      psp1-s1.ak3.lgn.dfs.de  # as above, but only ssh public"
   echo "   eg: $(basename $0) deploy:config    psp1-s1.ak3.lgn.dfs.de  # as above, but only tsctl2 and network config"
   echo "   eg: $(basename $0) deploy:scripts   psp1-s1.ak3.lgn.dfs.de  # as above, but only scripts"
   echo "   eg: $(basename $0) all|config|scripts|keys   all   # make everything due to action keyword but don't deploy to NSCs (PSPs) !!"
	 echo
	 echo "  --update-resources :  forces update of resource nsc list even if it exists, without this option an existing list will not be overwritten"
	 echo "  --cached           :  uses cached data on nss of resource domain(s) for deployment"
   exit 1
fi

if [[ "$*" != *cached* && "$*" == *update-resources* ]]; then
    echo "options '--cached' and '--update-resource' are mutual exclusive, exiting !!"
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

function create_remote_nsc_configs # create files on remote NSSes
{
  typeset remote_domain_server=$1
  # create <fqdn>.2step.vars and  remote_hn.list (Possibly add NO remote_hn.list at that point
  cmd="ssh ${remote_domain_server} ${bindir}/nss_manage_remote_nsc.sh create_configs"
  $cmd
}

function get_remote_nsc_list  # returns the list.
{
  typeset remote_domain_server=$1
  typeset remote_dn=${remote_domain_server#*.}
  typeset remote_nsc_list=$(ssh $remote_domain_server cat ${vardir}/${remote_dn}.remote_nsc.list)
  # delete original list
  ssh $remote_domain_server rm ${vardir}/${remote_dn}.remote_nsc.list > /dev/null 2>&1
  echo $remote_nsc_list
}


function copy_remote_nsc_config # copys files
{
  typeset remote_domain_server=$1
  typeset remote_nsc=$2
  typeset remote_hn=${remote_nsc%%.*}
  typeset remote_dn=${remote_nsc#*.}
  if [[ -n $remote_domain_server && -n $remote_hn ]]; then
    cmd="scp ${remote_domain_server}:${vardir}/$remote_dn/${remote_hn}.2step.vars ${vardir}/$remote_dn/"
    $cmd > /dev/null
    #cmd="scp ${remote_domain_server}:${vardir}/${remote_dn}.remote_nsc.list ${vardir}"
    #$cmd > /dev/null
  else
    echo "remote_domain_server OR remote_hn NOT given, ignoring"
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

echo "\n<< Create nsc list from all ResourceDomainServers if not disabled via option >>\n"

if [[ "$*" == *update-resources* ]];then
  echo "updating resource nsc list due to comdline option !"
	${bindir}/admin_get_resource_nsc_list.sh --no-target-config-list
fi

echo "\n<< Get rpm(s) from repository  >>\n"
#${bindir}/admin_get_rpms_from_repo.sh

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
        echo "OK found and reached $resdom_server_fqdn "
        #echo "Will create and deploy configs to all servers, "
        echo "Deploy stuff ONLY to following NSC: $target "
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

##############


if [[ "$*" == *cached* ]];then
  echo "Use CACHED data for deployment due to comdline option !"
else

    echo "\n<< Collect nsc configs from all RemoteDomainServers >>\n"

    [[ -f $remote_nsc_list_file     ]] && rm $remote_nsc_list_file
    [[ -f  ${vardir}/aks ]] && rm  ${vardir}/aks

    # get uniq list of ALL servers

    AlleDomainServers=$(echo $ResourceDomainServers $RemoteDomainServers | sed 's/\s/\n/g' | sort -u)

    echo "\n<< Deploy scripts to all Servers >>\n"

    for domain_server in $AlleDomainServers
    do
      if [[ $domain_server != $(dnsdomainname) ]]; then
        echo "  Deploy all scripts and configs to $domain_server"
        ssh $domain_server "[[ -d $bindir ]] || mkdir -p $bindir " > /dev/null 2>&1
        rsync -ahH ${confdir} ${domain_server}:$basedir > /dev/null
        rsync -ahH ${bindir}/nss* ${domain_server}:$bindir > /dev/null
        rsync -ahH ${bindir}/nsc* ${domain_server}:$bindir > /dev/null
        rsync -ahH ${bindir}/2step* ${domain_server}:$bindir > /dev/null
        #rsync -ahH ${basedir} ${domain_server}:/opt/dfs > /dev/null
      fi
    done

    echo "\n<< Create configs on RemoteDomainServers and collect on admin server >>\n"

    for remote_domain_server in $RemoteDomainServers
    do
       if [[ $(check_host_alive ${remote_domain_server}) == 0 ]]; then
         echo "$remote_domain_server NOT REACHED, skipping !!"
         continue
       fi
       remote_dn=${remote_domain_server#*.}

       [[ -d ${vardir}/$remote_dn ]] || mkdir -p ${vardir}/$remote_dn

       echo "  create remote nsc configs on $remote_domain_server"
       create_remote_nsc_configs $remote_domain_server

       for remote_nsc in $(get_remote_nsc_list $remote_domain_server)
       do
         echo "  copy $remote_nsc config from $remote_domain_server"
         copy_remote_nsc_config $remote_domain_server $remote_nsc
         echo $remote_nsc >> $remote_nsc_list_file
       done
    done

    echo "\n<< Get ssh public keys from all Servers >>\n"

    for domain_server in $AlleDomainServers
    do
       echo "  copy public key"
       id_dsa_pub=$(ssh ${domain_server} cat /root/.ssh/id_dsa.pub)
       echo $id_dsa_pub >> ${vardir}/aks
       #authorized_keys
    done

    echo "\n<< Deploy all configs to all Servers >>\n"

    for domain_server in $AlleDomainServers
    do
      if [[ $domain_server != $(dnsdomainname) ]]; then
        echo "  Deploy all configs to $domain_server"
        rsync -ahH ${vardir} ${domain_server}:$basedir > /dev/null
      fi
    done
fi

#if ! [[ $arg1 != *deploy* && $arg1 == *all* || $arg1 == *config* || $arg1 == *scripts* || $arg1 == *keys* || $arg1 == *xinitrc* || $arg1 == *wall_msg* || $arg1 == *java* ]] ; then
if  [[ $arg1 != *deploy* ]] ; then
  echo "WARNING: Deployment to NSCs is SKIPPED because of missing or wrong options !!"
  exit
fi
echo "\n<< Deploy configs Resource NSC(s) >>\n"

for resource_domain_server in $TargetResourceDomainServers
do
    # sync all configd to nsc's
    echo "  syncing $resource_domain_server client(s)"
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
      #ssh $resource_domain_server "nsc_rsync ${bindir}/nsc_reconfigure.sh ${bindir} $target"   > /dev/null 2>&1
      ssh $resource_domain_server "nsc_rsync \'${bindir}/nsc*\' ${bindir} $target"  > /dev/null 2>&1
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
