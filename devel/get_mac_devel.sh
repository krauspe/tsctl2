#!/usr/bin/ksh

host=$1
dev=eth0

function get_mac_from_cache # get mac from /nss/home/remote_adm/config/newsim.all.hosts
{
  typeset host=$1
  typeset mac
  typeset x=$(nsc_adm -q nsc mac | grep $host)
  mac=${x#$host* }
  echo $mac
}

function get_mac_from_host # get mac from local or remote host
{
  typeset host=$1
  typeset dev=$2
  typeset -l mac

  ping -c 1 $host > /dev/null 2>&1

  if (( $? == 0 )); then
    cmd="ifconfig $dev | grep HWaddr"
    [[ -n $2 ]] && cmd="ssh $host $cmd"
    x=$($cmd)
    mac=${x#*HWaddr }
  else
    mac=""
  fi
  echo $mac
}

function get_mac
{
  typeset host=$1
  typeset dev=$2
  typeset retval

  typeset mac_cached=$(get_mac_from_cache $host)
  typeset mac_current=$(get_mac_from_host $host $dev)
  #echo
  #echo "mac_cached = $mac_cached"
  #echo "mac_current = $mac_current"
  #echo
  
  if [[ -n $mac_current ]]; then
    retval="$mac_current:mac(current)"
  elif [[ -n $mac_cached ]]; then
    retval="$mac_cached:mac(cached)"
  else
    retval=""
  fi
  
  if [[ $mac_cached != $mac_current ]] ; then
    retval="$mac_current:warning, cached and current values differ !!"
  fi
  echo $retval
  
}

get_mac $host $dev
