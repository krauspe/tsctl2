#!/usr/bin/ksh

basedir=/opt/dfs/tsctl2
bindir=${basedir}/bin
confdir=${basedir}/config
vardir=${basedir}/var

typeset -Al zypper_info
typeset -A repo_url
typeset -l k
typeset WSPACE=' 	'

unset http_proxy
unset https_proxy


RPMS="dfs_remotePiloten_appHandling"

# result=${result//+([$WSPACE])=+([$WSPACE])/=}

function initRepoURLs {
	#TODO: hat noch ein Problem wegen dem reponamen Feld:
	#TODO: ist zT zusaetzlich ein version string drin dann kommt "|" als field 7 !!

  #zypper lr -pu  | while read line
  cat ${confdir}/zypper_lr_pu.out | while read line
  do
		key=$(echo $line |  cut -d '|' -f 3)
		val=$(echo $line |  cut -d '|' -f 7)
		key=${key//[$WSPACE]/""}
		val=${val//[$WSPACE]/""}
		#echo "$key|$val"
		repo_url[$key]="$val"
  done
}

function initZypperInfo {
	rpm=$1
	#zypper info $rpm | while read line
	cat ${confdir}/zypper_info.${rpm}.out| while read line
	do
		set -- $line
		k=$1
		k=${k%:}
		[[ -n $k ]] && zypper_info[$k]="$2"
  	#echo "$k=${zypper_info[$k]}"
	done
}

function getRpmURL {
	rpm=$1
  initZypperInfo $rpm
  repo=${zypper_info["repository"]}
  #repo=${repo//[$WSPACE]/""}
	baseurl=${repo_url[$repo]}
	version=${zypper_info["version"]}
	arch=${zypper_info["arch"]}
#  echo "-- $rpm --"
#	echo "repo=$repo"
#	echo "baseurl=$baseurl"
#	echo "version=$version"
#	echo "arch=$arch"
	echo "${baseurl}/${arch}/${rpm}-${version}.${arch}.rpm"
}

# functions for nsc

function getRpmInfo {
	rpm=$1
	#out=$(rpm -qa | grep $rpm| tail -1)
	out=$(cat ${confdir}/zypper_lr_pu.out | grep $rpm| tail -1)
  if [[ -n $out ]]; then
  	installed="Yes"
  	version=${out#*-}
  else
  	installed="No"
	fi
	echo $out
}


initRepoURLs

for rpm in $RPMS
do
  url=$(getRpmURL $rpm)
	echo $url
done

