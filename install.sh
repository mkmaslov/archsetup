#!/bin/bash

# This script performs a basic Arch Linux installation.
# The installation includes:
# --  LUKS encryption of / (root) and swap partitions using dm-crypt
# --  linux-hardened kernel
# --  basic CLI features: tmux, zsh, neovim, btop
#     (with reasonable default dotfiles)
# --  basic networking: networkmanager, firefox, torbrowser
# --  Desktop environment: GNOME (only DM and shell)

# Highlight the output.
YELLOW="\e[1;33m" && RED="\e[1;31m" && GREEN="\e[1;32m" && COLOR_OFF="\e[0m"
say() { echo -e "${YELLOW}${1}${COLOR_OFF}"; }
status() { echo -ne "${YELLOW}${1}${COLOR_OFF}"; }
error() { echo -e "${RED}${1}${COLOR_OFF}"; }
success() { echo -e "${GREEN}${1}${COLOR_OFF}"; }

# Prompt for a response.
ask() { echo -ne "${YELLOW}${1}" && read RESPONSE && echo -ne "${COLOR_OFF}"; }

# Confirm continuing installation.
confirm() { 
    ask "${1} [y/N]? "
    if [[ !(${RESPONSE} =~ ^(yes|y|Y|YES|Yes)$) ]]; then
        say "Cancelling installation." && exit
    fi
}

# Reset terminal window.
loadkeys us && setfont ter-132b && clear
say "** ARCH LINUX INSTALLATION **"

# Test Internet connection.
status "Testing Internet connection: "
ping -w 5 archlinux.org &>/dev/null
NREACHED=${?}
if [ ${NREACHED} -ne 0 ]; then
    error "failed."
    echo -ne "Before proceeding with the installation, "
    echo -e "please make sure you have a functional Internet connection."
    echo -ne "To connect to a WiFi network, please use: "
    echo -e "iwctl station wlan0 connect <ESSID>."
    echo -ne "To test your Internet connection, please use: "
    echo -e "ping archlinux.org."
    exit
else
  success "success."
  timedatectl set-ntp true
fi

# Check that system is booted in UEFI mode.
status "Checking UEFI boot mode: "
COUNT=$(ls /sys/firmware/efi/efivars | grep -c '.')
if [ ${COUNT} -eq 0 ]; then
  error "failed."
  echo -ne "Before proceeding with installation, "
  echo -ne "please make sure your system is booted in UEFI mode. "
  echo -e "This setting can be changed in BIOS."
  exit
else
  success "success."
fi

# Check that Secure Boot is disabled.
say "Checking Secure Boot status. Should return: disabled (setup)."
bootctl --quiet status | grep "Secure Boot:"
confirm "Is Secure Boot disabled"
# Delete all keys, restore factory keys, reset to Setup Mode.

# Check system clock synchronization.
say "Checking time synchronization."
timedatectl status | grep -E 'Local time|synchronized'
confirm "Is the time correct (UTC+1) and synchronized"

# Detect CPU vendor.
CPU=$(grep vendor_id /proc/cpuinfo)
if [[ ${CPU} == *"AuthenticAMD"* ]]; then
    MICROCODE=amd-ucode
else
    MICROCODE=intel-ucode
fi

# Choose a target drive.
lsblk -ado PATH,SIZE
ask "Choose the target drive for installation: /dev/" && DISK="/dev/${RESPONSE}"
confirm "This script will delete all the data on ${DISK}. Do you agree"
clear

# Partition the target drive.
wipefs -af ${DISK} &>/dev/null
sgdisk ${DISK} -Zo -I -n 1:0:512M -t 1:ef00 -c 1:EFI \
  -n 2:0:0 -t 2:8e00 -c 2:LVM &>/dev/null

# Notify kernel about filesystem changes and get partition labels.
sleep 1 && partprobe ${DISK}
EFI="/dev/$(lsblk ${DISK} -o NAME,PARTLABEL | grep EFI | cut -d " " -f1 | cut -c7-)"
LVM="/dev/$(lsblk ${DISK} -o NAME,PARTLABEL | grep LVM | cut -d " " -f1 | cut -c7-)"

# Set up LUKS encryption for the LVM partition.
say "Setting up full-disk encryption. You will be prompted for a password."
modprobe dm-crypt
cryptsetup luksFormat --cipher=aes-xts-plain64 \
  --key-size=512 --verify-passphrase --verbose ${LVM}
say "Mounting the encrypted drive. You will be prompted for the password."
cryptsetup open --type luks ${LVM} lvm

# Create LVM volumes, format and mount partitions.
MAPLVM="/dev/mapper/lvm"
SWAP="/dev/mapper/main-swap"
ROOT="/dev/mapper/main-root"
pvcreate ${MAPLVM} && vgcreate main ${MAPLVM}
lvcreate -L18G main -n swap
lvcreate -l 100%FREE main -n root
mkfs.fat -F 32 ${EFI} &>/dev/null
mkfs.ext4 ${ROOT} &>/dev/null
mkswap ${SWAP} && swapon ${SWAP}
mount ${ROOT} /mnt
mkdir /mnt/efi
mount $EFI /mnt/efi
clear

# Install packages to the / (root) partition.
pacman -Sy
say "Installing packages."
PKGS=""
# Base Arch Linux system.
PKGS+="base base-devel linux "
# Drivers.
PKGS+="linux-firmware sof-firmware alsa-firmware {MICROCODE} "
# BIOS, UEFI and Secure Boot tools.
PKGS+="fwupd efibootmgr sbctl "
# CLI tools.
PKGS+="tmux zsh neovim btop git man-db man-pages texinfo "
# Fonts.
PKGS+="terminus-font adobe-source-code-pro-fonts adobe-source-sans-fonts "
# Networking tools.
PKGS+="networkmanager wpa_supplicant network-manager-applet firefox torbrowser-launcher "
# GNOME desktop environment.
PKGS+="gdm gnome-control-center gnome-shell-extensions "
PKGS+="gnome-tweaks gnome-terminal wl-clipboard "
# File(system) management tools.
PKGS+="lvm2 exfatprogs nautilus sushi gnome-disk-utility "
# Miscelaneous applications.
PKGS+="calibre gimp inkscape vlc guvcview signal-desktop telegram-desktop "
# Applications that are rarely used and should be installed in a VM:
# easytag, unrar, lmms, tuxguitar, pdfarranger, okular, libreofice-fresh.
# KVM GUI manager.
PKGS+="gnome-boxes"
pacstrap -K /mnt ${PKGS}

# Enable daemons.
systemctl enable bluetooth --root=/mnt &>/dev/null
systemctl enable NetworkManager --root=/mnt &>/dev/null
systemctl enable wpa_supplicant.service --root=/mnt &>/dev/null
systemctl enable systemd-resolved.service --root=/mnt &>/dev/null
systemctl enable gdm.service --root=/mnt &>/dev/null
systemctl enable systemd-timesyncd.service --root=/mnt &>/dev/null

# Set hostname.
ask "Choose a hostname: " && HOSTNAME="${RESPONSE}"
echo "${HOSTNAME}" > /mnt/etc/hostname
cat > /mnt/etc/hosts <<EOF
# Static table lookup for hostnames.
# See hosts(5) for details.
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain   $HOSTNAME
EOF
clear

# Set up locale.
echo "en_IE.UTF-8 UTF-8"  > /mnt/etc/locale.gen
echo "LANG=en_IE.UTF-8" > /mnt/etc/locale.conf
cat > /mnt/etc/vconsole.conf <<EOF
KEYMAP=us
FONT=ter-132b
EOF
arch-chroot /mnt locale-gen &>/dev/null

# Set up the timezone.
arch-chroot /mnt ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime

# Set up users.
say "Choose a password for the root user."
arch-chroot /mnt passwd
ask "Choose a username of a non-root user:" && USERNAME="${RESPONSE}"
arch-chroot /mnt useradd -m ${USERNAME}
arch-chroot /mnt usermod -aG wheel ${USERNAME}
say "Choose a password for ${USERNAME}."
arch-chroot /mnt passwd ${USERNAME}
sed -i 's/# \(%wheel ALL=(ALL\(:ALL\|\)) ALL\)/\1/g' /mnt/etc/sudoers
cat > /mnt/etc/gdm/custom.conf <<EOF
[daemon]
WaylandEnable=True
AutomaticLoginEnable=True
AutomaticLogin=${USERNAME}
EOF
clear

# Configure disk mapping tables.
echo "lvm $LVM - luks,password-echo=no,x-systemd.device-timeout=0,timeout=0,\
no-read-workqueue,no-write-workqueue,discard" > /mnt/etc/crypttab.initramfs
cat > /mnt/etc/fstab <<EOF
# Static information about the filesystems.
# See fstab(5) for details.
# <file system>  <dir>  <type>  <options>      <dump>  <pass>
${EFI}             /efi   vfat    defaults     0       0
${ROOT}            /      ext4    defaults     0       0
${SWAP}            none   swap    defaults     0       0
EOF

# Configure mkinitcpio.
sed -i 's,HOOKS=(base udev autodetect modconf kms keyboard keymap consolefont block filesystems fsck),HOOKS=(base systemd keyboard autodetect modconf kms sd-vconsole block sd-encrypt lvm2 filesystems fsck),g' /mnt/etc/mkinitcpio.conf

# Create Unified Kernel Image.
# Also, add "quiet" later.
echo "root=${ROOT} resume=${SWAP} cryptdevice=${LVM}:main rw" > /mnt/etc/kernel/cmdline
echo "root=${ROOT} resume=${SWAP} cryptdevice=${LVM}:main rw" > /mnt/etc/kernel/cmdline_fallback
cat > /mnt/etc/mkinitcpio.d/linux.preset <<EOF
ALL_config="/etc/mkinitcpio.conf"
ALL_kver="/boot/vmlinuz-linux"
ALL_microcode=(/boot/*-ucode.img)
PRESETS=('default' 'fallback')
default_uki="/efi/EFI/Linux/arch.efi"
fallback_options="-S autodetect --cmdline /etc/kernel/cmdline_fallback"
fallback_uki="/efi/EFI/Linux/arch-fb.efi"
EOF
mkdir /mnt/efi/EFI && mkdir /mnt/efi/EFI/Linux
arch-chroot /mnt mkinitcpio -P
rm /mnt/efi/initramfs-*.img &>/dev/null
rm /mnt/boot/initramfs-*.img &>/dev/null
clear

# Configure Secure Boot.
say "Configuring Secure Boot."
arch-chroot /mnt /bin/bash -e <<EOF
  sbctl create-keys
  chattr -i /sys/firmware/efi/efivars/{PK,KEK,db}*
  sbctl enroll-keys
  sbctl sign --save /efi/EFI/Linux/arch.efi
  sbctl sign --save /efi/EFI/Linux/arch-fb.efi
EOF

# Add UEFI boot entries.
efibootmgr --create --disk ${DISK} --part 1 --label "arch" --loader "EFI\\Linux\\arch.efi"
efibootmgr --create --disk ${DISK} --part 1 --label "arch-fb" --loader "EFI\\Linux\\arch-fb.efi"

# Finishing installation.
success "Installation completed successfully!"
say "The computer will now reboot to BIOS."
say "Please, enable Secure Boot there and restart."
umount -R /mnt
say "DEBUG -> COMPLETED"
#systemctl reboot --firmware-setup
