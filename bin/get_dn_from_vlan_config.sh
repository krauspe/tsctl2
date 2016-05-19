#!/usr/bin/ksh

# test script for function get_dn_from_vlan_config in
# admin_get_status_list.sh

switch_vlan_prod_script=/home/sysman/tools/rem_pil/bin_ak/control_net_ak_psp.sh
switch_vlan_dev_script=${bindir}/control_net_develop.sh

if [[ -x $switch_vlan_prod_script ]] ; then
  switch_vlan_script=$switch_vlan_prod_script
elif [[ -x $switch_vlan_dev_script ]] ; then
  switch_vlan_script=$switch_vlan_dev_script
else
  switch_vlan_script=""
fi

fqdn2check=$1
# fake cmdline arg
fqdn2check=cwp4-s1.ak3.lgn.dfs.de  # exists
#fqdn2check=cwp99-s1.ak3.lgn.dfs.de  # exists NOT

function get_dn_from_vlan_config
{
	fqdn_in=$1

	if [[ -z $switch_vlan_script ]]; then
		echo "DEBUG: $switch_vlan_script NOT FOUND"
		echo ""
		return
	fi
	# check if data available, if no run the script
	if (( ${#VLAN_DN[*]} == 0 )); then
		echo "running script $switch_vlan_script ..."
		$switch_vlan_script -v | while read -r  fqdn descr switch port default_vlan current_vlan
		do
			echo $fqdn $descr $switch $port $default_vlan $current_vlan
			current_dn=${current_vlan##Current_VLAN=}
			VLAN_DN[$fqdn]=$current_dn
		done
	fi

	if [[ -n ${VLAN_DN[$fqdn_in]} ]]; then
		echo ${VLAN_DN[$fqdn_in]}
	else
		echo "DEBUG: NO entry for $fqdn_in FOUND"
		echo ""
	fi

	return
}

dn=$(get_dn_from_vlan_config $fqdn2check)

echo "dn=$dn"

### FUNZT NET !!!!!!!!