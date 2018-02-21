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
#  Modified SLES version 12.09.2017
#
#TODO: create function for reboot including stop of nis kill comands etc
#TODO  replace on all 'reboot' commands 
#

dbg=""


#<2step>
source /etc/2step/2step.vars

typeset -i debug_level=1
dev=eth0
# ggfs spaeter aus config file
basedir=/opt/dfs/tsctl2
bindir=${basedir}/bin
confdir=${basedir}/config
vardir=${basedir}/var
remote_nsc_list=${vardir}/remote_nsc.list

typeset log=${vardir}/reconfigure.sles.log

typeset -i do_reboot

if [[ $3 == *reboot* ]]; then
  do_reboot=1
else
  do_reboot=0
fi


function boot_manager
{
    typeset target_os=$1
    #typeset fqdn=$2
    typeset mount_point=/USB
    typeset grub_cfg=${mount_point}/boot/grub2/grub.cfg

    echo "Boot-Manager:"

    # ensure mounted stick and existence of grub.cfg

    if [[ ! -f $grub_cfg ]]; then
        [[ -d $mount_point ]] || mkdir -p $mount_point
        mount -L REMPIL ${mount_point}
        if [[ $? -ne 0 ]]; then
          echo " Boot-Manager: Cant't mount boot stick on $mount_point !" | tee -a $log
          echo " Boot-Manager: Check mount point and/or stick, exiting !!" | tee -a $log
          exit 1
        fi
        if [[ ! -f $grub_cfg ]]; then
          echo " Boot-Manager: Cant't find $grub_cfg, exiting !!" | tee -a $log
          exit 1
        fi
    fi

    if [[ $target_os == 'CentOS' ]] ; then
        echo " Boot-Manager: prepare boot stick for booting CentOS system"  | tee -a $log
        sed -i 's/set default.*/set default=0/' $grub_cfg
    elif [[ $target_os == 'SLES' ]] ; then
        echo " Boot-Manager: prepare boot stick for booting SLES system..."  | tee -a $log
        sed -i 's/set default.*/set default=1/' $grub_cfg
    fi
    # be sure to sync changes to stick
    sync
}

function my_print
{
  typeset text=$1
  if (( $debug_level > 0 )); then
    echo "  $text"
  fi
}

function config_multicast # vorlaeufig
{
  sed -i "/240.0.0.0 eth0/d" /etc/sysconfig/network/routes
  echo "224.0.0.0 0.0.0.0 240.0.0.0 eth0" >> /etc/sysconfig/network/routes
}

function config_nis
{
  date >> $log
  typeset ypserver_ip=$ns
  typeset nisdom=yp_nsim1
  my_print "reconfigure NIS client... "  | tee -a $log
  rcypbind stop
  echo "ypserver $ypserver_ip" > /etc/yp.conf
  echo "domain $nisdom"       >> /etc/yp.conf
}

function kill_simprocs
{
  #$dbg su - spv -c "simkill all" > /dev/null
  $dbg  pkill -u spv
  $dbg  pkill -U spv
  $dbg  pkill -9 -u spv
  $dbg  pkill -9 -U spv
}

function prepare_and_reboot
{
  date >> $log
  my_print "\nprepare_and_reboot: kill sim processes"  | tee -a $log
  $dbg kill_simprocs | tee -a $log

  date >> $log
  my_print "\nprepare_and_reboot: stopping automounter.."  | tee -a $log
  $dbg rcautofs stop | tee -a $log

  date >> $log
  my_print "prepare_and_reboot: stopping ypbind"  | tee -a $log
  rcypbind stop | tee -a $log

  date >> $log
  my_print "prepare_and_reboot: enable ypbind (for next boot)"  | tee -a $log
  chkconfig ypbind on | tee -a $log

  date >> $log
  my_print "prepare_and_reboot: check ypbind (for next boot)"  | tee -a $log
  chkconfig ypbind  | tee -a $log


  if [[ $do_reboot -eq 1 ]]; then
    date >> $log
    echo "\n  prepare_and_reboot: done, rebooting to aktivate new config... \n"  | tee -a $log
    $dbg reboot &
  else
    date >> $log
    echo "\n  prepare_and_reboot: done, NO REBOOT OPTION GIVEN !\n"  | tee -a $log
  fi
  exit
}

function usage
{
    echo "\nusage: $(basename $0) <fqdn>|reset|default|list <target_os> [reboot]"
    echo " e.g.: $(basename $0) psp101-s1.te1.lgn.dfs.de CentOS        # configure as psp101-s1 in on te1.lgn.dfs.de (CentOS)"
    echo " e.g.: $(basename $0) psp101-s1.te1.lgn.dfs.de CentOS reboot # as above and do a reboot after writing the config"
    echo " e.g.: $(basename $0) psp101-s1.ak3.lgn.dfs.de SLES   reboot # configure as psp101-s1 in on ak3.lgn.dfs.de (SLES)"
    echo " e.g.: $(basename $0) psp101-s1.te1.lgn.dfs.de CentOS reboot # as above and do a reboot after writing the config"
    echo "     : $(basename $0) reset                                  # to reset configuration as local simulator client\n"
    echo "     : $(basename $0) default                                # same as "reset"\n"
    echo
    echo " <target_os> mus be 'SLES' or 'CentOS' !"
    exit 1
}

if  [[ ! ( -n $1 && ( $2 == 'CentOS' || $2 == 'SLES')) ]] ; then
    usage
fi

typeset remote_fqdn=$1
typeset target_os=$2
typeset option=$3


## MAIN ####

[[ -f $log ]] && rm $log
date > $log
echo >> $log

#if  [[  $remote_fqdn == "reset" || $remote_fqdn == "default" || $remote_fqdn == ${hn}.${dn} ]] ; then
if [[ $1 == "list" ]] ; then
    echo "\npossible arguments are:\n"
    cat $remote_nsc_list
    echo
    echo "or 'reset' to reconfigure to home configuration: ${hn}.${dn}"
    echo
    exit
fi

if [[ $target_os == 'CentOS' ]]; then
    echo "program boot stick to boot CentOS on next reboot..."  | tee -a $log
    boot_manager CentOS # default
    # TODO: check possible creation of local jobfile which can be read from CentOS (/sles/.../simcontrol.job)
    # admin_reconfigure_nscs.sh should have created a jobfile with 'reconfigure:fqdn:default'
    date >> $log
    my_print "\nprepare_and_reboot: kill sim processes"  | tee -a $log
    $dbg kill_simprocs | tee -a $log

    date >> $log
    my_print "\nprepare_and_reboot: stopping automounter.."  | tee -a $log
    $dbg rcautofs stop | tee -a $log

    date >> $log
    my_print "prepare_and_reboot: stopping ypbind"  | tee -a $log
    rcypbind stop | tee -a $log

    date >> $log
    my_print "prepare_and_reboot: enable ypbind (for next boot)"  | tee -a $log
    chkconfig ypbind on | tee -a $log

    date >> $log
    my_print "prepare_and_reboot: check ypbind (for next boot)"  | tee -a $log
    chkconfig ypbind  | tee -a $log


    if [[ $do_reboot -eq 1 ]]; then
        date >> $log
        echo "\n  prepare_and_reboot: done, rebooting to aktivate new config... \n"  | tee -a $log
        $dbg reboot
    else
        date >> $log
        echo "\n  prepare_and_reboot: done, NO REBOOT OPTION GIVEN !\n"  | tee -a $log
    fi
    exit
fi

echo "target system ($remote_fqdn) is SLES, no changes on boot stick necessary"  | tee -a $log

if  [[  $remote_fqdn == "reset" || $remote_fqdn == "default" || $remote_fqdn == ${hn}.${dn} ]] ; then
    twostep_vars=/etc/2step/2step.vars
    date >> $log
    my_print "use original $twostep_vars to reconfigure host"  | tee -a $log
    echo "${bindir}/nsc_manage_rpms.sh local"  | tee -a $log
    $dbg ${bindir}/nsc_manage_rpms.sh local
else
    remote_hn=${remote_fqdn%%.*}
    remote_dn=${remote_fqdn#*.}
    twostep_vars=${vardir}/${remote_dn}/${remote_hn}.2step.vars

    if [[ ! -f $twostep_vars ]] ; then
        echo "$twostep_vars NOT found !!, SKIPPING."  | tee -a $log
        exit 1
    fi

    date >> $log
    echo "${bindir}/nsc_manage_rpms.sh $remote_dn"  | tee -a $log
    $dbg ${bindir}/nsc_manage_rpms.sh $remote_dn
fi

#date >> $log
#my_print "configure network.."  | tee -a $log
#$dbg ${bindir}/2step-netconfig-local $twostep_vars
#
#date >> $log
#my_print "configure multicast.."  | tee -a $log
#$dbg config_multicast
#
#my_print "Configure NIS client.."  | tee -a $log
#$dbg config_nis
#
#$dbg prepare_and_reboot

source $twostep_vars  # read configuration data

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

if [[ $do_reboot -eq 1 ]]; then
  echo "\n  done, rebooting to aktivate new config... \n"
  reboot
else
  echo "\ndone, reboot to aktivate new config !\n"
fi

