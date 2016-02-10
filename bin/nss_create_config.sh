#!/usr/bin/ksh
#
# (c) Peter Krauspe 02/2016
#
# This script runs on an NSS of a Remote Domain (e.g. mu1.muc.dfs,de or ka1.krl.dfs.de) 
#
# Create 2step.vars files for the given fqdn (to create it's network configuration)
#

# <2step>
. /etc/2step/2step.vars
#
dbg=echo
dbg=""
# ggfs spaeter aus config file
basedir=/opt/dfs/tsctl2
bindir=${basedir}/bin
confdir=${basedir}/config
vardir=${basedir}/var
typeset fqdn

args=$*

if (( ${#*} < 1 )); then
  echo "\nusage: $(basename $0) <fqdn1> [<fqdn2> <fqdn3> ...]\n "
  exit 1
fi

[[ -d ${vardir}/$dn ]] || mkdir -p ${vardir}/$dn

for item in $args
do
  h=${item%%.*}
  d=${item#*.}
  host $h >/dev/null
  resolved=$?

  if [[ $h == $d ]]; then
    fqdn=${h}.$dn
  else
    fqdn=$item
  fi

  if [[ $resolved -ne 0 ]]; then
    echo "$item can't be resolved !!, skipping."
    continue 
  fi
  echo "\n<< Creating network config for $fqdn >>\n"
  ${bindir}/2step-get-infos-local --no-bootargs --no-dhcp hn=$fqdn  > ${vardir}/${dn}/${h}.2step.vars
done

  
