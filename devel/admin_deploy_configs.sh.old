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
# 01.12.2015: added java deployment for atcoach
# 10.12.2015: deploy ssh keys (als) to ALL domain servers (not only remote) , becvause otherwise the "home nss" has no pwdless root acess on psp's
#             fixed bug on mkdir commmands for bindir and java deployment 
#
# TODO: create deploy options for selective deployments (more than java and wall_msg)
# TODO: Thus, make it possible to deploy to a single target rather than to a list
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
remote_nsc_list_file=${vardir}/remote_nsc.list

source ${confdir}/remote_nsc.cfg # providing:  subtype, ResourceDomainServers, RemoteDomainServers

arg1=$1

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

echo "\n<< Create nsc list from all ResourceDomainServers >>\n"

${bindir}/admin_get_resource_nsc_list.sh --no-target-config-list

echo "\n<< Collect nsc configs from all RemoteDomainServers >>\n"

[[ -f $remote_nsc_list_file     ]] && rm $remote_nsc_list_file 
[[ -f  ${vardir}/aks ]] && rm  ${vardir}/aks

# get uniq list of ALL servers

AlleDomainServers=$(echo $ResourceDomainServers $RemoteDomainServers | sed 's/\s/\n/g' | sort -u)

echo "\n<< Deploy scripts and configs to all ResourceDomainServers and RemoteDomainServers >>\n"

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
   
for domain_server in $AlleDomainServers 
do
   echo "  copy public key"
   id_dsa_pub=$(ssh ${domain_server} cat /root/.ssh/id_dsa.pub)
   echo $id_dsa_pub >> ${vardir}/aks
   #authorized_keys
done

echo "\n<< Deploy all configs to all ResourceDomainServers and RemoteDomainServers >>\n"

for domain_server in $AlleDomainServers
do
  if [[ $domain_server != $(dnsdomainname) ]]; then
    echo "  Deploy all configs to $domain_server"
    rsync -ahH ${vardir} ${domain_server}:$basedir > /dev/null 
  fi
done

echo "\n<< Deploy all configs to all Resource NSC's >>\n"

for resource_domain_server in $ResourceDomainServers
do
    # sync all configd to nsc's
    echo "  syncing $resource_domain_server clients"
    echo "    syncing tsctl2 stuff"
    ssh $resource_domain_server "nsc_sh \"mkdir -p $bindir\" $subtype" # > /dev/null 2>&1
    ssh $resource_domain_server "nsc_rsync $vardir $basedir $subtype "  # > /dev/null 2>&1
    ssh $resource_domain_server "nsc_rsync $confdir $basedir $subtype " # > /dev/null 2>&1
    ssh $resource_domain_server "nsc_rsync ${bindir}/nsc_reconfigure.sh ${bindir} $subtype"    # > /dev/null 2>&1
    ssh $resource_domain_server "nsc_rsync ${bindir}/2step-get-infos-local ${bindir} $subtype" # > /dev/null 2>&1
    ssh $resource_domain_server "nsc_rsync ${bindir}/2step-netconfig-local ${bindir} $subtype" # > /dev/null 2>&1
    ssh $resource_domain_server "nsc_rsync ${vardir}/aks /root/.ssh/authorized_keys $subtype"  # > /dev/null 2>&1

    if [[ $arg1 == *xinitrc*  || $arg1 == "all" ]] ; then
      echo "    syncing xinitrc"
      ssh $resource_domain_server "nsc_sh '[ -f /etc/X11/xinit/xinitrc ] && mv /etc/X11/xinit/xinitrc /etc/X11/xinit/xinitrc.$$' psp"
      ssh $resource_domain_server "nsc_rsync ${confdir}/xinitrc.${subtype} /etc/X11/xinit/xinitrc $subtype"
    fi
    if [[ $arg1 == *wall_msg*  || $arg1 == "all" ]]; then
      echo "    syncing wall_msg script"
      ssh $resource_domain_server "nsc_rsync ${confdir}/set_wall_msg.sh /usr/local/share/wall_msg/bin $subtype"
    fi

    if [[ $arg1 == *java*  || $arg1 == "all" ]] ; then
      echo "    syncing java ..."
      ufa_dir=/opt/ufa
      cmd="mkdir -p ${ufa_dir}"
      # ufa_dir auf allen resource_domain_server anlegen
      
      if [[ $resource_domain_server != $(dnsdomainname) ]]; then
          ssh $resource_domain_server $cmd 
          # java auf alle resource_domain_server kopieren
	  rsync -ahH ${ufa_dir}/java ${resource_domain_server}:${ufa_dir}
      fi
      # javadir auf allen nscs anlegen
      ssh $resource_domain_server "nsc_sh \"mkdir -p $ufa_dir\" $subtype" #> /dev/null 2>&1
      # javadir auf alle nscs kopieren
      ssh $resource_domain_server "nsc_rsync ${ufa_dir}/java ${ufa_dir} $subtype"    > /dev/null 2>&1
    fi
done

echo "\nDone.\n"
