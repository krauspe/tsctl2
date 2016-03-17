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


#rpm_name="dfs_remotePiloten_appHandling"
rpm_name="newsim_web"

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

rpm_uri=$(getRpmURI $rpm_name)
echo $rpm_uri
rpm_url=$(gethttpURL $rpm_uri)
echo $rpm_url

mkdir -p $instdir
cd $instdir
wget $rpm_url
