#!/bin/bash
# Name: simcontrol.sh 
# Description: triggerd by simcontrol.service at boot time if enabled 
#              or maybe called manually
 
typeset script_desc="simcontrol"

simcontrol_dir=/opt/shared/simcontrol
log=/tmp/simcontrol.log


#[[ -d $logdir ]] || mkdir -p $logdir

nfs_server="cis01"
nfs_server_share="${nfs_server}:/opt/export/puppet-master"
nfs_client_mountpoint="/mnt/puppet"
adm_bindir=/opt/local/remote_adm/bin

echo "$(date):BEGIN $script_desc " >> $log
#echo "$d: $(basename $0): checking /etc/resolv.conf FIRST TIME" >> $log
#echo "------------------------------------------------" >> $log
#cat /etc/resolv.conf >> $log
#echo "------------------------------------------------" >> $log

# check server

systemctl status rpcbind
[[ $? != 0 ]] && systemctl start rpcbind

# Try to reach the NFS server 3 times
sleep_secs=2

for index in 1 2 3; do
ping -c 2 ${nfs_server} &> /dev/null
reached=$?

if [[ $reached -eq 0 ]]; then
  break
else
  echo -e "$script_desc>> Could not reach ${nfs_server}. Sleeping for $sleep_secs seconds and will try again." | tee -a $log
  sleep $sleep_secs
fi
done

if [[ $reached -ne 0 ]]; then
echo "\n$script_desc: FAILED: nfs server not reached !!"
exit 1
fi

# refresh public key for root :-)

/usr/bin/wget http://${nfs_server}/ks-files/key -O /tmp/key

if [[ $? -eq 0 ]]; then
    cp /tmp/key /root/.ssh/authorized_keys
    echo "updated public key for root" | tee -a  $log
else
    echo "warning: update root key failed !" | tee -a  $log
fi

client_check_job_cmd="${adm_bindir}/adm.py --client-check-job"
client_run_job_cmd="${adm_bindir}/adm.py --client-run-job"

echo "$script_desc $(date):" >> $log

echo -e "====================================================================="
echo -e "#=== Check Simulator install/remove or reconfiguration Requests ====#"
echo -e "====================================================================="

# check if job is present for this host

$client_check_job_cmd
retval=$?

# do nothing when retval not 0

if [[ $retval -ne 0 ]]; then
    echo "NO job found for this host, exiting..."  | tee -a  $log
    exit 0
fi

# OK theres a job, lets go ...
echo "Job found for this host, start execute ..."  | tee -a  $log

[[ -d $nfs_client_mountpoint ]] || mkdir -p  $nfs_client_mountpoint
# mount nfs server if not already mounted

if [[ ! -d ${nfs_client_mountpoint}/modules ]]; then
  # Mount script location

  d=$(date)
  echo -e "\n$d: $script_desc>> Mounting puppet dir"  | tee -a  $log
  mount -t nfs ${nfs_server_share} ${nfs_client_mountpoint}
fi

# Run client job
d=$(date)

echo -e "\n$d: $client_run_job_cmd\n>> Executing ..." | tee -a $log
${client_run_job_cmd}  | tee -a $log

d=$(date)

if [[ $? -eq 0 ]]; then
  echo -e "\n$d: $script_desc>> Script successful." | tee -a $log
else
  echo -e "\n$d: $script_desc>> Error; Script exited with error(s)! Quiting..." | tee -a $log
  exit 1
fi

#echo "$d: $(basename $0): checking /etc/resolv.conf SECOND TIME" >> $log
#echo "------------------------------------------------" >> $log
#cat /etc/resolv.conf >> $log
#echo "------------------------------------------------" >> $log

echo "$(date):END $script_desc " >> $log
