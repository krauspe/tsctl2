# create partition

disk=$1
size=$(fdisk -l $disk | awk -F[:,\ ] '/Disk/ {print $4$5}')
echo "parted $disk mkpartfs primary fat32 0 $size"
echo "parted -s $disk set 1 boot on"

#echo "mkfs.vfat -F 32 -n REMPIL $device"
echo "mkdir -p /USB && mount -L REMPIL /USB"
echo "grub2-install --force --no-floppy --boot-directory=/USB/boot $disk"
echo "cp message /USB/boot"
