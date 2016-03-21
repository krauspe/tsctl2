#!/usr/bin/ksh

# runs on NSC's
# will be called from nsc_reconfigure.sh and installs/removes a special rpm which handles app caching
#
# TODO: check if everything works
#<2step>
source /etc/2step/2step.vars

basedir=/opt/dfs/tsctl2
bindir=${basedir}/bin
confdir=${basedir}/config
vardir=${basedir}/var
instdir=${vardir}/install

source ${confdir}/remote_nsc.cfg # providing:  subtype, ResourceDomainServers, RemoteDomainServers
[[ -f ${confdir}/remote_nsc.${dn}.cfg ]] && source ${confdir}/remote_nsc.${dn}.cfg # read domain specific cfg

# functions for nsc

function getRpmInfo {
	rpm=$1
	#out=$(cat ${confdir}/zypper_lr_pu.out | grep $rpm| tail -1)
	out=$(rpm -qa | grep $rpm| tail -1)
  if [[ -n $out ]]; then
  	installed="Yes"
  	version=${out#*-}
  	ret_string="$installed:$out"
  	ret=0
  else
  	ret_string=""
  	ret=1
	fi
	echo $ret_string
	return $ret
}

function installClientRpm {
  client_rpm_file=$1
	if [[ -z $client_rpm_file ]] ; then
		echo "no client_rpm_file found."
	else
	  echo "installing $client_rpm_file : "
	  cmd="rpm -hiv $client_rpm_file"
	  echo $cmd
	  $cmd
	fi
}

function removeClientRpm {
	client_rpm_name=$1
	echo " removing $client_rpm_name"
	cmd="rpm -e $client_rpm_name"
	echo $cmd
	$cmd
}

# check if caching is enabled for target  domain

typeset mode

if [[ $1 == *local* ]]; then
	mode=local
else
  echo $AppCacheEnabledDomains | grep $1 > /dev/null 2>&1
	if [[ $? != 0 ]]; then
		echo "App cache rpm management is NOT enabled on this daomin. skipping"
		exit
	else
		mode=remote
	fi
fi

# check wether client_rpm is installed or not

client_rpm_info=$(getRpmInfo $client_rpm_name)

if [[ -n $client_rpm_info ]]; then
	rpm_installed=1
	echo "$client_rpm_info"
else
	rpm_installed=0
fi


# get latest rpm

client_rpm_file=$(ls ${instdir}/${client_rpm_name}*.rpm 2>/dev/null| tail -1)

#echo "client_rpm_file=$client_rpm_file"

# install/remove rpm depending on reconfiguration target

if [[ $mode == *local* ]]; then
	if [[ $rpm_installed -eq 1 ]]; then
		echo "we reconfigure to local, $client_rpm_name is installed. Going to remove it"
		removeClientRpm $client_rpm_name
	else
		echo "we reconfigure to local, $client_rpm_name is not installed. nothing to do."
	fi
elif  [[ $mode == *remote* ]];then
	if [[ $rpm_installed -eq 0 ]]; then
	  echo "we reconfigure to remote. $client_rpm_name is not installed, Going to install it."
		installClientRpm $client_rpm_file
	else
	  echo "we reconfigure to remote. $client_rpm_name is already installed, nothing to do."
	  exit
	fi
else
  echo "usage: $(basename $0) local|remote"
  exit 1
fi

