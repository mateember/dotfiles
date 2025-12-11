#!/bin/bash

timedatectl

pacstrap -K /mnt base linux-lts linux-lts-headers linux-firmware nano 

genfstab -U /mnt >> /mnt/etc/fstab

arch-chroot /mnt