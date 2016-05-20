#!/usr/bin/ksh

# test script for function get_dn_from_vlan_config in
# admin_get_status_list.sh
basedir=/opt/dfs/tsctl2
bindir=${basedir}/bin
typeset -A VLAN_DN

switch_vlan_prod_script=/home/sysman/tools/rem_pil/bin_ak/control_net_ak_psp.sh
switch_vlan_dev_script=${bindir}/control_net_develop.sh

if [[ -x $switch_vlan_prod_script ]] ; then
  switch_vlan_script=$switch_vlan_prod_script
elif [[ -x $switch_vlan_dev_script ]] ; then
  switch_vlan_script=$switch_vlan_dev_script
else
  switch_vlan_script=""
fi

# test input for function

FQDNS2CHECK="cwp4-s1.ak3.lgn.dfs.de cwp3-s1.te1.lgn.dfs.de psp45-s1.te1.lgn.dfs.de psp8-mgt.lx3.lgn.dfs.de psp2-s1.te1.lgn.dfs.de"

function get_dn_from_vlan_config
{
	fqdn_in=$1

	if [[ -z $switch_vlan_script ]]; then
		#echo "DEBUG: $switch_vlan_script NOT FOUND"
		echo ""
		return
	fi

	if (( ${#VLAN_DN[*]} == 0 )); then

		#echo "No data available, running script $switch_vlan_script ..."

		$switch_vlan_script -v | while read -r  fqdn descr switch port default_vlan current_vlan id
		do
			#echo $fqdn $descr $switch $port $default_vlan $current_vlan
			current_dn=${current_vlan##Current_VLAN=}
			VLAN_DN[$fqdn]=$current_dn
			current_vlan=""
		done
	fi

	dn_found=${VLAN_DN[$fqdn_in]}

	if [[ -n $dn_found && $dn_found != *unknown* ]]; then
		echo $dn_found
	else 
		echo ""
	fi

	return
}


for fqdn2check in $FQDNS2CHECK
do
	# for test with echos
	#get_dn_from_vlan_config $fqdn2check

	dn=$(get_dn_from_vlan_config $fqdn2check)
	echo "$fqdn2check: dn=$dn"
done

