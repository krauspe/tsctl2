#!/usr/bin/ksh

basedir=/opt/dfs/tsctl2
source ${basedir}/config/remote_nsc.cfg
typeset arg1=$1

SERVERS=$(echo $RemoteDomainServers $ResourceDomainServers | sed 's/\s+*/\n/g' |  sort -u | grep -v $(dnsdomainname))

function do_it
{
  typeset server=$1

  if [[ $arg1 == "--delete" ]]; then
    cmd="ssh ${server} rm -r ${basedir}"
  else
    cmd="rsync -ahHv --delete bin config ${server}:${basedir}"
  fi

  echo $cmd
  [[ -n $basedir ]] && $cmd
}

for server in $SERVERS
do
   do_it $server 
done
