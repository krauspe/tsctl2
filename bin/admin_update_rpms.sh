#!/usr/bin/ksh

basedir=/opt/dfs/tsctl2
bindir=${basedir}/bin
confdir=${basedir}/config
vardir=${basedir}/var

typeset -Al zypper_info
typeset -A repo_url

typeset -l k

unset http_proxy
unset https_proxy


RPMS="dfs_remotePiloten_appHandling gnome-desktop tcpdump"


function initRepoURL {
	#TODO: hat noch ein Problem wegen dem reponamen Feld : ist zT ein version string drin , daher key falsch !!
  #zypper lr -pu  | cut -d '|' -f 3,7) | while read line
  cat ${confdir}/zypper_lr_pu.out | cut -d '|' -f 3,7 | while read line
  do
		set -- $line
		[[ -n $1 ]] && repo_url[$1]="$3"
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
	baseurl=${repo_url[$repo]}
	version=${zypper_info["version"]}
	arch=${zypper_info["arch"]}
  echo "-- $rpm --"
	echo "repo=$repo"
	echo "baseurl=$baseurl"
	echo "version=$version"
	echo "arch=$arch"
	echo "url=${baseurl}/${arch}/${rpm}-${version}.${arch}.rpm"
	echo
	echo
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

  return $out
}


#echo "#######################################"
#echo "USE getRpmInfoFromZypper"

initRepoURL

for rpm in $RPMS
do
	getRpmURL $rpm
done

