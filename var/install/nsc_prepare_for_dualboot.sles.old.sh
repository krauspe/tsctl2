#!/bin/ksh

hn=$(hostname)
OS=$(facter operatingsystem)
menu_lst=/boot/grub/menu.lst

if ! [[ $hn == psp* ]]; then
  echo
  echo " This script should only be run on a PSP !! Exiting .."
  echo
  exit 1
elif [[ $OS != *SLES* ]]; then
  echo " This script should only be used for SLES !! Exiting .."
  exit 1
fi
echo "OS = $OS , ok"
echo "type = PSP, ok"

kernel=$(grep kernel /boot/grub/menu.lst| head -1 | awk '{print $2}')
initrd=$(grep initrd /boot/grub/menu.lst| head -1 | awk '{print $2}')
num_entrys=$(cat $menu_lst | grep ^title | wc -l)

root_dev=$(df / | awk '/dev/{print $1}' )
swap_dev=$(grep swap /etc/fstab | awk '{print $1}')

#echo "root_dev=$root_dev"
#echo "swap_dev=$swap_dev"

egrep '^title.*REMPIL' $menu_lst > /dev/null 2>&1
if [[ $? -eq 0 ]]; then
  echo -n "\n$menu_lst has a REMPIL entry.\n\n"
  echo -n "Machine seems already being prepared, doing nothing.\n\n"
  exit
fi

default=$(($num_entrys))
hd=1
echo -n "\n<< PREPARE GRUB MENU, DISK LABELS AND BOOT-STICK MOUNTPOINT FOR REMPIL >>>\n"

echo "  backup current $menu_lst to ${menu_lst}.$$"
cp $menu_lst ${menu_lst}.$$

echo "  adding REMPIL entry using disk/by-label instaed of disk/by-id $menu_lst"

cat <<EOF>>$menu_lst

### REMPIL ###
title SLES REMPIL
    root (hd$hd,0)
    kernel $kernel root=/dev/disk/by-label/sles load_ramdisk=1 x11=nsc resume=/dev/disk/by-label/swap splash=silent crashkernel= showopts vmalloc=256MB
    initrd $initrd 
EOF

echo "set default entry to $default"
sed -i "s/^default.*/default $default/" $menu_lst

echo "set timeout to 1 "
sed -i "s/^timeout.*/timeout 1/" $menu_lst
echo
echo "creating label 'swap' on swap device $swap_dev"
cmd="swaplabel -L swap $swap_dev"
echo $cmd
$cmd
echo
echo "creating label 'sles' on / device $root_dev"
cmd="tune2fs -L sles $root_dev"
echo $cmd
$cmd

echo "Done."


