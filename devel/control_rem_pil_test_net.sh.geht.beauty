#!/bin/bash
#
script=`basename $0`
Generic_Name=control_net_test_psp.sh
version=1.3
author="Uwe Micksch OP/TS"
sc_date="2015-10-26" 
#
#   craetaed by U. micksch TEIS
#   last change 26.10.2015: #
#   Bug fixed in status
psp_portlist="cswitch61 Gi1/0/17 [LGNTE1]_psp1-s1_sim 209\ncswitch61 Gi1/0/19 [LGNTE1]_psp2-s1_sim 209\ncswitch60 Gi1/0/39 [LGNTEST]_psp5-s1_sim 15\ncswitch60 Gi1/0/41 [LGNTEST]_psp6-s1_sim 15\ncswitch62 Gi1/0/39 [LGNTEST]_psp7-s1_sim 100\ncswitch62 Gi1/0/41 [LGNTEST]_psp8-s1_sim 100"

####  global settings #####
VLAN_TE1=209
VLAN_LX1=15
VLAN_LX3=100
desc_finder="rempil"

MODES1=te1.lgn.dfs.de
MODES2=lx1.lgn.dfs.de
MODES3=lx3.lgn.dfs.de
MODES4=dummy1
MODES5=dummy2
MODESdummy=dummy

tsctl_basedir=/opt/dfs/tsctl2
tsctl_vardir=${tsctl_basedir}/var

STATDIR=$tsctl_vardir
#STATDIR=/home/sysman/tools/rem_pil_test/var
SIMPORTLIST=$STATDIR/sim_vlan_status.txt
#PSPPORTLIST=/home/sysman/tools/rem_pil_test/bin/psp_list_testsysteme.txt
PSPPORTLIST="./psp_list_testsysteme.txt"
FILEID=`date +%y%m%d%s`
###########################
#set -x

####    functions ######
get_descr_snmp(){
  cat /dev/null > /$STATDIR/status_raw.txt
  target=$1
  for i in `seq 1 48`
  do
    PORT=`expr 10100 + $i`
    snmpget -v 2c -c obec $target ifAlias.$PORT >>/$STATDIR/status_raw.txt
  done
}

get_vlan_by_port(){
  # arg1: <simcsw> arg2: portid
  switch=$1
  portid=$2
  snmpget -v 2c -c obec $switch  .1.3.6.1.4.1.9.9.68.1.2.2.1.2.$portid
}

pw_check(){
  echo -n "This operation is password protected:  ";read -s pass
  if [ $pass == "suffix4711" ]
  then
    echo "successful"
  else
    echo "Wrong password, hint: 4711"
    exit 1
  fi
}

set_vlan_by_port(){
  # arg1: <simcsw> arg2: portid arg3: vlan
  switch=$1
  portid=$2
  vlan=$3
  #echo "TEST!!!! snmpset -v 2c -c starosta $switch  .1.3.6.1.4.1.9.9.68.1.2.2.1.2.$portid i $vlan"
  snmpset -v 2c -c starosta $switch  .1.3.6.1.4.1.9.9.68.1.2.2.1.2.$portid i $vlan
  if [ $? == 0 ];then
    echo -e "SUCCESS:\t $switch $portid set to: VLAN $vlan"
  else
    echo -e "ERROR:\t  $switch $portid not switched"
  fi
}

create_sim_portlist(){

  cat /dev/null > /$STATDIR/sim_vlan_status.txt

  # get port - description list from switch (see status_raw.txt)
  get_descr_snmp $SWITCH
  grep $desc_finder /$STATDIR/status_raw.txt | grep -v -i mgt | awk -F. '{print $2}' > /$STATDIR/sim_vlan_status_REP_PIL_Ports.txt
  # parsing switch related list (sim_vlan_status_<switch>.txt
  while read -r port inf
  do
    echo -e "$SWITCH  \t Port: ${port} \t ID: $inf" >> /$STATDIR/sim_vlan_status_us.txt
  done < /$STATDIR/sim_vlan_status_REP_PIL_Ports.txt
       #
  sort -V -k7 /$STATDIR/sim_vlan_status_us.txt > /$STATDIR/sim_vlan_status.txt
}


usage(){
  echo "usage: `basename $0` -c <target domain> <host FQDN> ...  (e.g. `basename $0` -c te1.lgn.dfs.de  psp5-s1.lx1.lgn,dfs.de)"
  echo "usage: `basename $0` -d  to set every Port to default VLAN"
  echo "usage: `basename $0` -v  to see Client association "
  echo "usage: `basename $0` -h  to see some help text"
  exit 0
}

sc_version(){
echo -e "\n \
	 $script\n \
        Generic_Name: $Generic_Name\n \
         Version: $version\n \
	 Author=$author\n \
	 $sc_date\n \
------------------------------------------------\n"
}

####    main ########
currentuser=$(whoami)
#echo "User: $currentuser"
#if [[ $currentuser != "sysman" ]]; then 
#		echo "This script must be run as user sysman!" 
#		exit 1
#	fi 
if [ A$1 == A ]
  then
  echo -e "no Arguments given\n"
  usage
  exit 1
fi
#if [ A$STATDIR != A ]
#then 
#rm /$STATDIR/s*.txt 2> /dev/null
#else 
#echo "Statusdirectory not defined"
#exit 1
#fi
if [ -s $PSPPORTLIST ] 
then
  echo "Portlist Files are existing...."
else
  echo "Portlist ($PSPPORTLIST) not found, will generate it..."
  echo -e $psp_portlist > $PSPPORTLIST
fi

case $1 in

-h)
  sc_version	
  usage
;;

-xxx)
echo -e "Default Port List:\n"
echo -e $psp_portlist
;;

-v)
  location=unknown
  while read -r switch port descr default_VLAN
  do
    case $default_VLAN in
      $VLAN_TE1) dlocation=$MODES1 ;;
      $VLAN_LX1) dlocation=$MODES2 ;;
      $VLAN_LX3) dlocation=$MODES3 ;;
      *)
      dlocation=unknown ;;
    esac

    portid=101$(echo $port | awk -F\/ '{print $3}')
    vlanid=`get_vlan_by_port $switch $portid | awk '{print $(NF)}'`

    case $vlanid in
      $VLAN_TE1) location=$MODES1 ;;
      $VLAN_LX1) location=$MODES2 ;;
      $VLAN_LX3) location=$MODES3 ;;
              *) location=unknown ;;
    esac
    echo -e "Machine=$descr\tSwitch=$switch \tPort=$port\tID=$portid Default_VLAN=$dlocation\tCurrent_VLAN=$location"
    # echo -e "Postition: $descr is assigned to: $location"
  done < $PSPPORTLIST
;;

-c) 
  echo "switching selected components"
  #pw_check
  args=("$@")
  ARG_SITE=$2
  # SITE=$(echo $ARG_SITE | tr "[a-z]" "[A-Z]")
  SITE=$(echo $ARG_SITE | tr "[A-Z]" "[a-z]")
  echo -e "Argument = $SITE \n"
  case $SITE in $MODES1) targetvlan=$VLAN_TE1 ;;
     $MODES2) targetvlan=$VLAN_LX1 ;;
     $MODES3) targetvlan=$VLAN_LX3 ;;
  esac

  echo "TARGET VLAN= $targetvlan"
 
  for ((i=2; i < $#; i++))
  do
    echo "Argument: $((i)): ${args[$i]}"
    component_raw=${args[$i]}
    component=$(echo $component_raw | awk -F. '{print $1}')
    domain=$(echo $component_raw | awk -F. '{print $2"."$3"."$4"."$5}')
    company=$(echo $component_raw | awk -F. '{print $4"."$5}')
    echo -e "Host=$component\tDomain=$domain"

    if [ $company != "dfs.de" ]
    then
      echo "Error in Domain Name"
      exit 2
    fi
    
    hosttype=`echo $component | cut -c1-3`
    if [ $hosttype == "psp" ] || [ $hosttype == "rem" ]
    then
      while read -r switch port descr default_VLAN
      do
        portid=101$(echo $port | awk -F\/ '{print $3}')
        echo $descr
        echo ${component}
        echo $descr | grep -i ${component}

        if [ $? == 0 ]
        then
          echo "Componentcheck OK"
          set_vlan_by_port $switch $portid $targetvlan
        fi

      done < $PSPPORTLIST
    fi
  done
;;

-d)
  echo "Setting everything to default"

  while read -r switch port descr default_VLAN
  do
    targetvlan=$default_VLAN
    portid=101$(echo $port | awk -F\/ '{print $3}')
    set_vlan_by_port $switch $portid $targetvlan
  done < $PSPPORTLIST
;;

*)
  usage
;;
esac
