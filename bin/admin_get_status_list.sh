#!/usr/bin/ksh
#
# (c) Peter Krauspe 10/2015
#
# This script should run on admin machine
#
# creates a status list (or a single entry) of resource_nsc / remote_nsc assignment and current status
#
# It reads the following files:
#
#   remote_nsc.list     # will be created from admin_deploy_configs.sh (manually bevor as preparation)
#   resource_nsc.list   # will be created from admin_get_resource_nsc_list.sh if not vailable 
#
#
## example nsc_status.list
## resource_nsc           configured_nsc           status     # status=available|occupied|unreachable|nss_unreachable
##-------------------------------------------------------------------------------------------------
# psp1-s1.te1.lgn.dfs.de psp1-s1.te1.lgn.dfs.de   available       # running @home-domain, not assigned       
# psp2-s1.te1.lgn.dfs.de psp103-s1.lx1.lgn.dfs.de occupied        # running assigned to remote domain lx1.lgn.dfs.de 
# psp3-s1.te1.lgn.dfs.de unknown                  unreachable     # not network connection, try WOL on home domain and all remote doamins  
# psp4-s1.te1.lgn.dfs.de unknown                  nss_unreachable # not network connection to nss of resource domain and not found on remote domains
#
# Changes: 
#   13.01.2016 check existence of previous target_config_list , than existence og status list and take assignment for first guess when searching resource nscs
#
#

# <2step>
. /etc/2step/2step.vars
#
#dbg=echo
dbg=""
dev=eth0
# ggfs spaeter aus config file
basedir=/opt/dfs/tsctl2
bindir=${basedir}/bin
confdir=${basedir}/config
vardir=${basedir}/var
instdir=${vardir}/install
typeset resource_fqdn
typeset resource_dn
typeset resource_hn
typeset -A RESOURCE_MACS
typeset -A PREVIOUS_TARGET_FQDN
typeset -A PREVIOUS_REMOTE_FQDN
typeset -A TARGET_OPTION
typeset arg1=$1
typeset search_type
typeset found
typeset previous_status_list_available=0
typeset target_config_list_available=0
typeset option_enabled_only=0

source ${confdir}/remote_nsc.cfg # providing:  subtype, ResourceDomainServers, RemoteDomainServers
[[ -f ${confdir}/remote_nsc.${dn}.cfg ]] && source ${confdir}/remote_nsc.${dn}.cfg # read domain specific cfg
typeset AllDomainServers=$(echo $RemoteDomainServers $ResourceDomainServers | sed 's/\s+*/\n/g' |  sort -u )

# check cmdline args
opts=$*

if [[ $opts == *--enabled-only* ]] ; then
	echo "CHECKING ONLY resource fqdns which are enabled for reconfiguration !!"
	option_enabled_only=1
fi

# set vars

resource_nsc_list_file=${vardir}/resource_nsc.list
nsc_status_list_file=${vardir}/nsc_status.list
target_config_list_current_file=${vardir}/target_config.list
target_config_list_previous_file=${vardir}/target_config.list.previous

function get_domain_server_hn
{
  typeset domain=$1
  typeset hn 

  for fqdn in $AllDomainServers
  do
     if [[ $domain == ${fqdn#*.} ]] ; then
       hn=${fqdn%%.*}  
       echo $hn
       break
     fi
  done 
}

function check_nsc_status
{
  typeset fqdn=$1
  typeset -l ret
  #domain_server=nss.${fqdn#*.}
  domain_server=$(get_domain_server_hn ${fqdn#*.}).${fqdn#*.}
  ping -c 1 $domain_server > /dev/null 2>&1
  if (( $? != 0 )) ; then
    echo "nss_unreachable"
  else
    ssh $domain_server "ping -c 1 $fqdn"  > /dev/null 2>&1
    if (( $? > 0 )) ; then
      echo "unreachable"
    else
      ssh $domain_server "ssh $fqdn uptime"  > /dev/null 2>&1
      if (( $? > 0 )) ; then
        echo "alive"
      else
        echo "ssh-ok"
      fi
    fi
  fi
}


function deep_search
{
  echo "deep search: try LOCAL first ....."
  resource_status=$(check_nsc_status $resource_fqdn)

  if [[ $resource_status == "ssh-ok" ]]; then
    echo "$resource_fqdn $resource_fqdn available" | tee -a $nsc_status_list_file
    found=1
  else
    echo "search for $resource_fqdn in all remote domains..."
  
    for remote_domain_server in $RemoteDomainServers
    do
      echo "SEARCH ON $remote_domain_server"
      resource_status_in_remote_domain=$(ssh $remote_domain_server "${bindir}/nss_manage_remote_nsc.sh status $resource_fqdn --force_search")
      if [[ -n $resource_status_in_remote_domain ]]; then
      	echo "$resource_fqdn $resource_status_in_remote_domain" | tee -a $nsc_status_list_file
      	found=1
      	break
      fi
    done
  fi
}

# MAIN

echo "\n<< Create Resource NSC Status (List) .. This may take a while, be patient !!  >>\n"

if [[ ! -f $resource_nsc_list_file ]]; then
  echo "  $resource_nsc_list_file not found, create it .." >&2
  ${bindir}/admin_get_resource_nsc_list.sh --no-target-config-list
fi


# read MAC adresses from resource_nsc's

while read line
do
  [[ $line == \#* ]] && continue
  set -- $line
  fqdn=$1
  mac=$2
  RESOURCE_MACS[$fqdn]=$mac
  RESOURCE_FQDNS_ALL="$RESOURCE_FQDNS_ALL $fqdn"
done < $resource_nsc_list_file

# read target_config_list if available
# else read nsc_status_list_file
# for first guess as current status


# read nsc status list when available

if [[ -f $nsc_status_list_file ]] ; then
  echo "found nsc status list"
  while read line
  do
    [[ $line == \#* ]] && continue
    set -- $line
    resource_fqdn=$1
    remote_fqdn=$2
    #status=$3 # allways old
    PREVIOUS_REMOTE_FQDN[$resource_fqdn]=$remote_fqdn
  done < $nsc_status_list_file
  previous_status_list_available=1
fi

# read current target config list when available
# select enabled targets and store in array

if [[ -f $target_config_list_current_file ]] ; then
  echo "found current target config list"

  while read line
  do
    [[ $line == \#* ]] && continue
    set -- $line
    resource_fqdn=$1
    remote_fqdn=$2
    target_option=$3
    TARGET_OPTION[$resource_fqdn]=$target_option
  done < $target_config_list_current_file
  target_config_list_available=1
fi


if [[ -f $target_config_list_previous_file ]] ; then
  echo "found previous target config list"
  echo "taking entrys as first trial to check status ..."
  while read line
  do
    [[ $line == \#* ]] && continue
    set -- $line
    resource_fqdn=$1
    remote_fqdn=$2
    #target_option==$3
    PREVIOUS_TARGET_FQDN[$resource_fqdn]=$remote_fqdn
  done < $target_config_list_previous_file
  search_type=direct
elif (( previous_status_list_available == 1 )) ; then
  echo "NO previous target config list found."
  echo "but found old status list. taking entrys as first trial to check status ..."
  for resource_fqdn in  ${!PREVIOUS_REMOTE_FQDN[*]}
  do
    PREVIOUS_TARGET_FQDN[$resource_fqdn]=${PREVIOUS_REMOTE_FQDN[$resource_fqdn]}
  done < $nsc_status_list_file
  search_type=direct
else
  echo "NO previous target config list found."
  echo "NO status list found."
  echo "making a deep search ...."
  search_type=deep
fi

# rename old nsc_status_list_file

[[ -f $nsc_status_list_file ]] && mv $nsc_status_list_file ${nsc_status_list_file}.previous

# doing the search

for resource_fqdn in $RESOURCE_FQDNS_ALL
do
  found=0
  resource_dn=${resource_fqdn#*.}
  resource_hn=${resource_fqdn%%.*}

  if [[ $search_type == "direct" ]]; then

		if [[ ${TARGET_OPTION[$resource_fqdn]} == "enable_reconfiguration" || $option_enabled_only == 0 ]]; then
			previous_fqdn=${PREVIOUS_TARGET_FQDN[$resource_fqdn]}
			[[ $previous_fqdn == "default" ]] && previous_fqdn=$resource_fqdn
			echo
			echo "assume $resource_fqdn configured as $previous_fqdn"

			if [[ $previous_fqdn == "unknown" ]]; then
				echo "... try LOCAL"
				previous_fqdn=$resource_fqdn
			fi

			resource_status=$(check_nsc_status $previous_fqdn)
			if [[ $resource_status == "ssh-ok" ]]; then
				if [[ $previous_fqdn == $resource_fqdn ]]; then
					echo "$resource_fqdn $resource_fqdn available" | tee -a $nsc_status_list_file
					found=1
				else
					echo "$resource_fqdn $previous_fqdn occupied" | tee -a $nsc_status_list_file
					found=1
				fi
			fi
		else
			echo "$resource_fqdn unknown unknown" | tee -a $nsc_status_list_file
			found=1  # fake found to skip deep search
		fi

		if (( $found == 0 )); then
			deep_search
		fi

  else # search_type=deep
		deep_search
	fi

	(( $found==0 )) && echo "$resource_fqdn unknown unreachable" | tee -a  $nsc_status_list_file

done
echo "Done."

