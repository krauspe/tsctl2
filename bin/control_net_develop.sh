#!/bin/bash
#
# Angepasst fuer /opt/dfs/tsctl2 - Umgebung P.K 19.05.2016
#
#
script=`basename $0`
Generic_Name=control_net_ak_psp.sh
version=1.1
author="Uwe Micksch OP/TS"
sc_date="2016-04-08" 
#
#
####  global settings #####
VLAN_TE1=209
VLAN_LX1=15
VLAN_LX3=100
VLAN_AK2=114
VLAN_AK3=116
VLAN_AK4=119
VLAN_AK51=113
VLAN_AK5=$VLAN_AK51
VLAN_AK6=42
VLAN_MU1=744
VLAN_Ka1=743
VLAN_BR1=742
CSWITCH_AK2=cswitch48
CSWITCH_AK3=cswitch43
CSWITCH_AK4=cswitch44
CSWITCH_AK51=cswitch46
CSWITCH_AK6=cswitch6
CSWITCH_TE_1=cswitch60
CSWITCH_TE_2=cswitch61
CSWITCH_TE_3=cswitch62



desc_finder="psp"
cwp_finder="cwp"
dom_check="lgn.dfs.de"

MODETE1=te1.lgn.dfs.de
MODEAK2=ak2.lgn.dfs.de
MODEAK3=ak3.lgn.dfs.de
MODEAK4=ak4.lgn.dfs.de
MODEAK5=ak5.lgn.dfs.de
MODETE1=te1.lgn.dfs.de
MODELX1=lx1.lgn.dfs.de
MODELX3=lx3.lgn.dfs.de

MODEBR1=br1.bre.dfs.de
MODEMU1=mu1.muc.dfs.de
MODEKA1=ka1.krl.dfs.de
MODEAK6=ak6.lgn.dfs.de
MODE_SHORTAK2=lgnak2
MODE_SHORTAK3=lgnak3
MODE_SHORTAK4=lgnak4
MODE_SHORTAK5=lgnak5
MODE_SHORTAK6=LGNAK6
MODE_SHORTTE1=LGNTE1
MODE_SHORTLX1=LGNLX1
MODE_SHORTLX3=LGNLX3

MODESdummy=dummy
#
# remove "new" for Production
# PK: Anpassung fuer Testumgebung lgnlx3
#STATDIR=/home/sysman/tools/rem_pil/portlists/
STATDIR=/opt/dfs/tsctl2/tmp
[[ -d $STATDIR ]] || mkdir -p $STATDIR
#
DESCR_RAW=descr_raw.txt
SIMPORTLIST=$STATDIR/ak_sim_vlan_status.txt
#SIMPORTLIST_ALL=$STATDIR/ak_sim_vlan_status_all.txt
PSPPORTLIST=$STATDIR/ak_psp_port_list
PSPPORTLIST_TMP=$PSPPORTLIST.tmp
FILEID=`date +%y%m%d%s`
###########################

get_descr_snmp(){
target=$1
#target=$switch
for p in `seq 1 48`
do
PORT=`expr 10100 + $p`
RAW=$(snmpget -v 2c -c obec ${target} ifAlias.${PORT} | grep -vi "no such")
#echo "snmpget -v 2c -c obec ${target} ifAlias.${PORT}"
if [ $? = 0 ]
then
echo -e "${target}\tPort: ${p}\t $(echo $RAW | awk -F: '{print $NF}')"
# Example: cswitch72    Port: 1   Entwicklernetz
fi
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
    SWITCH=$1
    echo " writing file for: $SWITCH"

     # get port - description list from switch (see status_raw.txt)
       get_descr_snmp $SWITCH > $STATDIR/$DESCR_RAW
        grep -i $desc_finder $STATDIR/$DESCR_RAW  > $STATDIR/$SWITCH.$desc_finder.list
        grep -i $cwp_finder $STATDIR/$DESCR_RAW  > $STATDIR/$SWITCH.$cwp_finder.list

}


usage(){
      echo "usage: `basename $0` -c <target domain> <host FQDN> ...  (e.g. `basename $0` -c br1.bre.dfs.de  psp5-s1.ak2.lgn,dfs.de)"
#      echo "usage: `basename $0` -d  to set every Port to default VLAN"
      echo "usage: `basename $0` -v  to see Client association "
      echo "usage: `basename $0` -h  to see some help text"
      echo "usage: `basename $0` -rb to rebuild port lists for AK psp"
      echo -e "\n\nValid Target Domains:\nbr1.bre.dfs.de\nmu1.muc.dfs.de\nka1.krl.dfs.de\nak6.lgn.dfs.de"
 
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
if [ -s $PSPPORTLIST ] 
  then
   echo "Portlist Files are existing...."
  else
   echo "Portlist ($PSPPORTLIST) not found, ..."
   echo "usage: `basename $0` -rb to rebuild port lists "
fi



case $1 in

-h)
sc_version	
usage
	;;

-xxx)
echo -e "Default Port List no longer supported\n"
echo "usage: `basename $0` -rb to rebuild port lists "
;;
-rb)
   	echo "Rebuilding port lists for DFS AK Ressources"
        for s in $CSWITCH_AK2 $CSWITCH_AK3 $CSWITCH_AK4 $CSWITCH_AK51 $CSWITCH_TE_1 $CSWITCH_TE_2 $CSWITCH_TE_3
         do
          echo "creating port lists for: $s"
          create_sim_portlist $s 
         done
         cat /dev/null > $PSPPORTLIST_TMP
         cat /dev/null > $PSPPORTLIST

        while read line
        do
         case $(echo $line | awk -vRS="]" -vFS="[" '{print $2}') in
           $MODE_SHORTAK2)
            echo "$MODEAK2 $line DefVLAN: $VLAN_AK2" >>$PSPPORTLIST_TMP
           ;;
           $MODE_SHORTAK3)
	    echo "$MODEAK3 $line DefVLAN: $VLAN_AK3" >>$PSPPORTLIST_TMP
	   ;;
           $MODE_SHORTAK4)
	    echo "$MODEAK4 $line DefVLAN: $VLAN_AK4" >>$PSPPORTLIST_TMP
           ;;
           $MODE_SHORTAK5)
	    echo "$MODEAK5 $line DefVLAN: $VLAN_AK5" >>$PSPPORTLIST_TMP
          ;;
	   $MODE_SHORTTE1)
	    echo "$MODETE1 $line DefVLAN: $VLAN_TE1" >>$PSPPORTLIST_TMP
	  ;;
	   $MODE_SHORTLX1)
            echo "$MODELX1 $line DefVLAN: $VLAN_LX1" >>$PSPPORTLIST_TMP
	  ;;
           $MODE_SHORTLX3)
            echo "$MODELX3 $line DefVLAN: $VLAN_LX3" >>$PSPPORTLIST_TMP
          ;;

          *)
           echo "unknown_fqdn $line DefVLAN: undefined" >>$PSPPORTLIST_TMP
           ;;
         esac
        done< <(cat $STATDIR/cswitch*.list)
        
        while read -r fqdn switch x port descr xx default_VLAN
        do
        hostnamefqdn="$(echo $descr | awk -F[ '{print $1}').$fqdn"
        echo -e "$hostnamefqdn\t$descr\t$switch\t$port\t$default_VLAN" >> $PSPPORTLIST
        done < $PSPPORTLIST_TMP
;;
-v)
        location=unknown
       while read -r hostnamefqdn descr switch port default_VLAN
        do
        case $default_VLAN in
	$VLAN_AK2)
                    dlocation=$MODEAK2
        ;;
        $VLAN_AK3)
                    dlocation=$MODEAK3
        ;;
        $VLAN_AK4)
                    dlocation=$MODEAK4
        ;;
        $VLAN_AK51)
                    dlocation=$MODEAK5
        ;;
	$VLAN_AK6)
                    dlocation=$MODEAK6
	;;
        $VLAN_TE1)
		    dlocation=$MODETE1
	;;
        $VLAN_LX1)
                    dlocation=$MODELX1
        ;;
        $VLAN_LX3)
                    dlocation=$MODELX3
        ;;

        *)
        dlocation="unknown\t"
        ;;
        esac

        portid=`expr 10100 + $port`
        vlanid=`get_vlan_by_port $switch $portid | awk '{print $(NF)}'`


        case $vlanid in
        $VLAN_AK2)
                    location=$MODEAK2
        ;;
        $VLAN_AK3)
                    location=$MODEAK3
        ;;
        $VLAN_AK4)
                    location=$MODEAK4
        ;;
        $VLAN_AK51)
                    location=$MODEAK5
        ;;
        $VLAN_AK6)
                    location=$MODEAK6
        ;;
        $VLAN_MU1)
		    location=$MODEMU1
	;;
	$VLAN_Ka1)
		    location=$MODEKA1
	;;
	$VLAN_BR1)
		    location=$MODEBR1
	;;
	$VLAN_TE1)
                    location=$MODETE1
	;;
        $VLAN_LX1)
                    location=$MODELX1
        ;;
        $VLAN_LX3)
                    location=$MODELX3
	;;
        *)
        location="unknown_name ID=$vlanid"
        ;;
        esac
   echo -e "$hostnamefqdn\t$descr   \tSwitch=$switch \tPort=$port\tDefault_VLAN=$dlocation\t    Current_VLAN=$location"
        done < $PSPPORTLIST
;;
#
-c) 
      echo "switching selected components"
#     pw_check
      args=("$@")
      ARG_SITE=$2
      SITE=$(echo $ARG_SITE | tr "[A-Z]" "[a-z]")
      echo -e "Argument = $SITE \n"
        case $SITE in
         $MODEAK2)
          targetvlan=$VLAN_AK2
         ;;
         $MODEAK3)
          targetvlan=$VLAN_AK3
         ;;
         $MODEAK4)
          targetvlan=$VLAN_AK4
         ;;
         $MODEAK5)
          targetvlan=$VLAN_AK5
         ;;
         $MODEAK6)
	  targetvlan=$VLAN_AK6
	 ;;
	 $MODEBR1)
          targetvlan=$VLAN_BR1
         ;;
	 $MODEMU1)
          targetvlan=$VLAN_MU1
         ;;
	 $MODEKA1)
          targetvlan=$VLAN_Ka1
         ;;
         *)
         echo "Target domain not found"
         exit 2
	 ;;
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
                checkfound=false
	        while read -r hostnamefqdn descr switch port default_VLAN
        	do
 			portid=`expr 10100 + $port`
#        		echo ${hostnamefqdn}
                  
       				if [ $component_raw = $hostnamefqdn  ]
               			then
               			  echo "Component found, switching VLAN to $targetvlan"
				  set_vlan_by_port $switch $portid $targetvlan
                                  checkfound=true
               			fi
		done < $PSPPORTLIST
                if [ $checkfound = "false" ]
                then
                echo "$component_raw not found in portlist"
                fi
            else
            echo "component_raw is not a valid component type"
	    fi            
        done   

;;
-d)
#echo "Setting everything to default"
echo "not yet implemented"
#while read -r switch port descr default_VLAN
#        do
#        targetvlan=$default_VLAN
#        portid=101$(echo $port | awk -F\/ '{print $3}')
#               set_vlan_by_port $switch $portid $targetvlan
#
#
#done < $PSPPORTLIST

;;


*)
usage
;;
esac
