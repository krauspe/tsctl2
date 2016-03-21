#!/usr/bin/ksh

basedir=/opt/dfs/tsctl2
bindir=${basedir}/bin
confdir=${basedir}/config
vardir=${basedir}/var
instdir=${vardir}/install

typeset -Al zypper_info
typeset -A repo_url
typeset -l k
typeset WSPACE=' 	'

unset http_proxy
unset https_proxy
# <2step>
source /etc/2step/2step.vars

# get client_rpm_name frpm cfg
source ${confdir}/remote_nsc.cfg # providing:  subtype, ResourceDomainServers, RemoteDomainServers

[[ -f ${confdir}/remote_nsc.${dn}.cfg ]] && source ${confdir}/remote_nsc.${dn}.cfg # read domain specific cfg

# result=${result//+([$WSPACE])=+([$WSPACE])/=}

function initRepoURIs {
  typeset -l key
  #cat ${confdir}/zypper_lr_pu.out | while read line
  zypper lr -pu  | while read line
  do

		key=$(echo $line |  cut -d '|' -f 3)
		val=$(echo $line |  cut -d '|' -f 7)
		key=${key//[$WSPACE]/""}
		val=${val//[$WSPACE]/""}
		#echo "initRepoURLs:repo=($key) REPO_URL=($val)"
		repo_url[$key]="$val"
  done
}

function initZypperInfo {
	rpm=$1
	#cat ${confdir}/zypper_info.${rpm}.out| while read line
	zypper info $rpm | while read line
	do
		set -- $line
		key=$1
		val=$*
		val=${val#$1 }
  	val=${val//[$WSPACE]/""}
		if [[ -n $key ]]; then
			k=${key%:}
			zypper_info[$k]="$val"
			#echo "initZypperInfo:key=($k) repo=($val)"
		fi
	done
}

function getRpmURI {
	rpm=$1
  initZypperInfo $rpm
  repo=${zypper_info["repository"]}
	baseurl=${repo_url[$repo]}
	version=${zypper_info["version"]}
	arch=${zypper_info["arch"]}
	echo "${baseurl}/${arch}/${rpm}-${version}.${arch}.rpm"
}

function gethttpURL {
	url=$1
	if [[ $url == nfs:* ]]; then
	  url=${url//srv\/inst\/sw\//""}
	  url=${url//nfs/http}
  fi
  echo $url
}


initRepoURIs

rpm_uri=$(getRpmURI $client_rpm_name)
echo $rpm_uri
rpm_url=$(gethttpURL $rpm_uri)
echo $rpm_url

mkdir -p $instdir
cd $instdir
wget $rpm_url --timeout 10

if [[ $? -ne 0 ]]; then
	echo "WARNING: coul not update $client_rpm_name"
fi

ls ${instdir}/${client_rpm_name}*.rpm >/dev/null 2>&1

if [[ $? -ne 0 ]] ; then
	echo "WARNING: NO  $client_rpm_name available !!"
else
  latest_rpm=$(ls ${instdir}/${client_rpm_name}*.rpm| tail -1)
  echo "latest version is $latest_rpm"
fi

echo


