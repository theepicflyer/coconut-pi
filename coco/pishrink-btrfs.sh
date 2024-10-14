#!/bin/bash
# Meant to be run on a host system mounting the Pi image!
# NOT on the Pi itself!

# Constants
img="$1"
part_num="2"
mntpt="/mnt/btrfs_mount"

# Add image as loop device
loop_dev="$(losetup --find --partscan --show "$img")"

# mount image to mountpoint
mkdir $mntpt
mount $loop_dev"p"$part_num $mntpt

# btrfs defrag
btrfs filesystem defrag -v -r -f $mntpt"/@rootA" $mntpt"/@rootB" $mntpt"/@home"
btrfs balance start -dusage=50 $mntpt
btrfs balance start -m $mntpt

# btrfs resize. Starting at 4GB
btrfs filesystem resize 4G $mntpt
# Keep resizing down by 100MB until no space
final_output=""
while final_output=$(btrfs filesystem resize -100M "$mntpt"); do
  echo "Shrunk by 100MB"
done
umount "$mntpt"

# Get size and calculate safe partition size
fs_size=$(echo "$final_output" | grep -oP 'from \K[\d.]+' | cut -d 'G' -f 1)
echo "Final btrfs filesystem size:" $fs_size"GB"
# Calculate partition to ~10% larger than filesystem
part_size=$(echo "scale=0; $fs_size/0.00092" | bc)
part_start=$(parted "$loop_dev" -ms unit s p | grep "^${part_num}" | cut -f 2 -d: | sed 's/[^0-9]//g')
part_start_MB=$(parted "$loop_dev" -ms unit MB p | grep "^${part_num}" | cut -f 2 -d: | sed 's/[^0-9]//g')
part_end="+$(($part_size + $part_start_MB))MB"

# Resize the partition
fdisk "$loop_dev" <<EOF
d
$part_num
n
p
$part_num
$part_start
$part_end
p
w
q
EOF

img_size=$(parted -ms "$loop_dev" unit B print free)
img_size=$(tail -1 <<< "$img_size" | cut -d ':' -f 2 | tr -d 'B')

# Delete loop device
losetup -d "$loop_dev"

# Truncate image file to the size
truncate -s $img_size $img

echo Final size: $(du -sh $img | cut -f1)