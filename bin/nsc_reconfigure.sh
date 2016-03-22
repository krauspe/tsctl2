#!/usr/bin/ksh
#
# (c) Peter Krauspe 10/2015
#
# This script should run on any Resouce NSC (e.g. a PSP of a Resource Domain like ak4.lgn.dfs.de)
# to reconfigure it's network configuration to integrate this host into the target remote domain
#
# It uses one of the formerly collected 2step.vars files which matches the given target fqdn 
# given as command line argument
#
# - When "reset" or "default" is given as first argument, the original network configuration from it's resource domain will be restored
#
# - As long as a machine is reachable from it's current NSS it can be run by an ssh call,
#   In this case it is strongly recommendet to use "reboot" as second argument because after writing the configuration the machine may
#   no longer bereachable by the calling NSS . Otherwise it must be called on the console of the machine
#
# - During reboot of the machine the VLAN configuration should be switched to the target domain determined by the first argument (fqdn)
#
# Changes:
#
#  24.11.2015: added kill procs function
#  01.12.2015: added "default" option (=reset) 
#  14.01.2016: changed order: 2step-netconfig -> multicast
#  17.03.2016: added call nsc_manage_rpms.sh local | $remote_dn
#
#

#<2step>
source /etc/2step/2step.vars

#dbg=echo
dbg=""
typeset -i debug_level=1
dev=eth0
# ggfs spaeter aus config file
basedir=/opt/dfs/tsctl2
bindir=${basedir}/bin
confdir=${basedir}/config
vardir=${basedir}/var
remote_nsc_list=${vardir}/remote_nsc.list

function my_print
{
  typeset text=$1
  if (( $debug_level > 0 )); then
    echo "  $text"
  fi
}

if [[ -n $1 ]]; then
  if [[ $1 == "reset" || $1 == "default" || $1 == ${hn}.${dn} ]] ; then
    twostep_vars=/etc/2step/2step.vars
    ${bindir}/nsc_manage_rpms.sh local
  elif [[ $1 == "list" ]] ; then
    echo "\npossible arguments are:\n"
    cat $remote_nsc_list
    echo
    echo "or 'reset' to reconfigure to home configuration: ${hn}.${dn}"
    echo
    exit
  else
    fqdn=$1
    remote_hn=${fqdn%%.*}
    remote_dn=${fqdn#*.}

    if [[ -n $remote_hn && -n $remote_dn ]] ; then
      twostep_vars=${vardir}/${remote_dn}/${remote_hn}.2step.vars
      if [[ ! -f $twostep_vars ]] ; then
        echo "$twostep_vars NOT found !!, SKIPPING."
        exit 1
      fi
    #
    ${bindir}/nsc_manage_rpms.sh $remote_dn

    else
      echo "reconfigure failed! We need an FQDN ! SKIPPING."
      echo "hn=$hn"
      echo "dn=$dn"   
      exit 1
    fi
    #echo "hn=$hn dn=$dn" 
  fi
else
    echo "\nusage: $(basename $0) <fqdn>|reset|default|list [reboot]"
    echo " e.g.: $(basename $0) psp101-s1.te1.lgn.dfs.de        # to configure this host as psp101-s1 in te1.lgn.dfs.de"
    echo " e.g.: $(basename $0) psp101-s1.te1.lgn.dfs.de reboot # as above and do a reboot after writing the config"
    echo "     : $(basename $0) reset                           # to reset configuration as local simulator client\n"
    echo "     : $(basename $0) default                         # same as "reset"\n"
    exit 1
fi

source $twostep_vars  # read configuration data

function config_multicast # vorlaeufig
{
  sed -i "/240.0.0.0 eth0/d" /etc/sysconfig/network/routes
  echo "224.0.0.0 0.0.0.0 240.0.0.0 eth0" >> /etc/sysconfig/network/routes
}

function config_nis 
{
  typeset ypserver_ip=$ns
  typeset nisdom=yp_nsim1
  my_print "reconfigure NIS client... "
  rcypbind stop
  echo "ypserver $ypserver_ip" > /etc/yp.conf
  echo "domain $nisdom"       >> /etc/yp.conf
}

function kill_simprocs
{
  $dbg su - spv -c "simkill all" > /dev/null 
  $dbg  pkill -u spv 
  $dbg  pkill -U spv 
  $dbg  pkill -9 -u spv 
  $dbg  pkill -9 -U spv 
}


my_print "\nkill sim processes"
$dbg kill_simprocs
my_print "\nstopping automounter.."
$dbg rcautofs stop
my_print "stopping NIS client.."
$dbg config_nis 
my_print "configure network.."
$dbg ${bindir}/2step-netconfig-local $twostep_vars
my_print "configure multicast.."
$dbg config_multicast

if [[ $2 == "reboot" ]]; then
  echo "\n  done, rebooting to aktivate new config... \n"
  reboot
else
  echo "\ndone, reboot to aktivate new config !\n"
fi
