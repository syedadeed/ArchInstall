#!/bin/bash

pre_setup(){
    timedatectl set-timezone Asia/Kolkata
    timedatectl set-ntp true
    timedatectl
    # reflector --latest 20 --protocol https --sort rate --save /etc/pacman.d/mirrorlist -c India --download-timeout 50
    pacman -Syy
}

disk_setup(){
    #--------------------------------Disk Selection--------------------------------------
    lsblk
    echo "Enter the disk name(format = /dev/..): "
    read disk

    #--------------------------------Disk Formating----------------------------------------
    mkfs.ext4 -F $disk

    #--------------------------------Disk Partition----------------------------------------
    echo -e "g\nw" | fdisk $disk
    echo -e "g\nn\n\n\n+512M\nt\n1\nn\n\n\n+100G\nt\n\n23\nn\n\n\n\nt\n\n42\nw" | fdisk $disk
    if [[ $disk == *"nvme"* ]]; then
        part_prefix="${disk}p"
    else
        part_prefix="${disk}"
    fi
    boot_partition="${part_prefix}1"
    root_partition="${part_prefix}2"
    home_partition="${part_prefix}3"

    #------------------------------------LUKS Setup------------------------------------------
    cryptsetup -v luksFormat $root_partition
    cryptsetup open --allow-discards --persistent $root_partition root
    root_mapper="/dev/mapper/root"
    cryptsetup -v luksFormat $home_partition
    cryptsetup open --allow-discards --persistent $home_partition home
    home_mapper="/dev/mapper/home"

    #--------------------------------Partition Formating-------------------------------------
    mkfs.fat -F 32 $boot_partition
    mkfs.btrfs -L root $root_mapper
    mkfs.ext4 -L home $home_mapper

    #--------------------------------Subvolume Creation--------------------------------------
    mount $root_mapper /mnt
    btrfs subvolume create /mnt/@root
    btrfs subvolume create /mnt/@snapshots
    btrfs subvolume create /mnt/@swap
    umount /mnt

    #--------------------------------Mounting Partition--------------------------------------
    mount -o subvol=@root $root_mapper /mnt
    mount --mkdir -o subvol=@snapshots $root_mapper /mnt/.snapshots
    mount --mkdir -o subvol=@swap $root_mapper /mnt/swap
    mount --mkdir $home_mapper /mnt/home
    mount --mkdir $boot_partition /mnt/efi

    #---------------------------------- Swap Creation----------------------------------------
    btrfs filesystem mkswapfile --size 10g --uuid clear /mnt/swap/swapfile
    swapon /mnt/swap/swapfile
}

install_packages(){
    pacstrap -K /mnt base
    echo "KEYMAP=us" > /mnt/etc/vconsole.conf
    pacstrap -K /mnt btrfs-progs
    pacstrap -K /mnt dosfstools
    pacstrap -K /mnt linux
    pacstrap -K /mnt linux-firmware
    pacstrap -K /mnt linux-headers
    pacstrap -K /mnt base-devel
    pacstrap -K /mnt networkmanager
    pacstrap -K /mnt efibootmgr
}

configure_system(){
    #Genrating fstab file
    genfstab -U /mnt >> /mnt/etc/fstab

    #Setting up timezone and locale
    arch-chroot /mnt ln -sf /usr/share/zoneinfo/Asia/Kolkata /etc/localtime
    arch-chroot /mnt hwclock --systohc --utc
    echo en_US.UTF-8 UTF-8 > /mnt/etc/locale.gen
    arch-chroot /mnt locale-gen
    echo LANG=en_US.UTF-8 > /mnt/etc/locale.conf

    #Setting up root password
    echo "Enter root password: "
    read rp
    echo -e "${rp}\n${rp}\n" | arch-chroot /mnt passwd

    #Creating user(adeed)
    echo "Enter username: "
    read username
    arch-chroot /mnt useradd -m -G wheel $username
    echo "Enter user password: "
    read up
    echo -e "${up}\n${up}\n" | arch-chroot /mnt passwd $username
    echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" >> /mnt/etc/sudoers

    #Making system bootable using UKI
    echo -e "rootflags=subvol=@root rw" > /mnt/etc/kernel/cmdline
    echo -e 'ALL_kver="/boot/vmlinuz-linux"\nPRESETS=("default")\ndefault_uki="/efi/EFI/Linux/arch-linux.efi"' > /mnt/etc/mkinitcpio.d/linux.preset

    #Editing mkinitcpio.conf for btrfs support and genrating EFI file for UKI
    echo -e "MODULES=(btrfs)\nBINARIES=()\nFILES=()\nHOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block sd-encrypt btrfs filesystems fsck)" > /mnt/etc/mkinitcpio.conf
    mkdir -p /mnt/efi/EFI/Linux
    arch-chroot /mnt mkinitcpio -P

    #Creating boot entry
    arch-chroot /mnt efibootmgr --create --disk $disk --part 1 --label "Arch Linux" --loader '\EFI\Linux\arch-linux.efi' --unicode
}

pre_setup
disk_setup
install_packages
configure_system
