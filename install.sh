#!/bin/bash
 
set -e

# This script performs basic Arch Linux installation.

# Highlight the output.
YELLOW="\e[1;33m" && RED="\e[1;31m" && GREEN="\e[1;32m" && COLOR_OFF="\e[0m"
cprint() { echo -ne "${1}${2}${COLOR_OFF}"; }
msg() { cprint ${YELLOW} "${1}\n"; }
status() { cprint ${YELLOW} "${1} "; }
error() { cprint ${RED} "${1}\n"; }
success() { cprint ${GREEN} "${1}\n"; }

# Prompt for a response.
ask () { status "$1 " && echo -ne "$2" && read RESPONSE; }

# Confirm continuing installation.
confirm() { 
    status "Press \"Enter\" to continue, \"Ctrl+c\" to cancel ..."
    read -p ""
    clear
}
confirm_action() { 
    ask "${1} [y/N]?"
    if [[ !(${RESPONSE} =~ ^(yes|y|Y|YES|Yes)$) ]]; then
        msg "Cancelling installation." && exit
    fi
    clear
}

# Reset terminal window.
loadkeys us && setfont ter-132b && clear
msg "** ARCH LINUX INSTALLATION **"
msg "Installation types:"
msg    "Option #1: Arch Linux for PC (single OS)"
cprint "           [Unified Kernel Image, luks encryption, wayland, GNOME]\n"
msg    "Option #2: Arch Linux for PC (dual-boot)"
cprint "           [same as #1, but leaves space for Windows partition]\n"
msg    "Option #3: Arch Linux for server."
cprint "           [same as #1, but does not include GUI applications]\n"
ask "Choose installation type:" "Option #"
WINDOWS=1 && SERVER=1
case $RESPONSE in
  "2") WINDOWS=0 ;;
  "3") SERVER=0 ;;
esac

# Check that Secure Boot is disabled.
msg "\nFull Secure Boot reset is recommended before using this script. In BIOS:"
msg "delete all SB keys, restore factory SB keys, then reset SB to Setup Mode."
msg "Verifying Secure Boot status. Should return: disabled (setup)."
bootctl --quiet status | grep "Secure Boot:"
confirm_action "Did you reset and disable Secure Boot"

# Test Internet connection.
status "Testing Internet connection:"
ping -w 5 archlinux.org &>/dev/null
NREACHED=${?}
if [ ${NREACHED} -ne 0 ]; then
    error "failed."
    status "Before proceeding with the installation,"
    msg    "please make sure you have a functional Internet connection."
    msg    "To connect to a WiFi network, use: "
    cprint " >> iwctl station wlan0 connect <ESSID>."
    msg    "To manually test the Internet connection, use: "
    cprint " >> ping archlinux.org."
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
  status "Before proceeding with the installation,"
  status "please make sure the system is booted in UEFI mode."
  msg    "This setting can be configured in BIOS."
  exit
else
  success "success."
fi

# Check system clock synchronization.
msg "Checking time synchronization:"
timedatectl status | grep -E 'Local time|synchronized'
confirm_action "Is the time correct and synchronized"

# Detect CPU vendor.
CPU=$(grep vendor_id /proc/cpuinfo)
if [[ ${CPU} == *"AuthenticAMD"* ]]; then
    MICROCODE=amd-ucode
else
    MICROCODE=intel-ucode
fi

# Choose a target drive.
msg "List of all attached storage devices:"
lsblk -ado PATH,SIZE
ask "Choose target drive for installation:" "/dev/" && DISK="/dev/${RESPONSE}"
confirm_action "This script will delete all the data on ${DISK}. Do you agree"

# Partition the target drive.
wipefs -af ${DISK} &>/dev/null
if [ "$WINDOWS" -eq 0 ]; then
  ask "Enter size of Linux partition in GiB:"
  sgdisk ${DISK} -Zo -I -n 1:0:512M -t 1:ef00 -c 1:EFI \
    -n 2:0:+${RESPONSE}G -t 2:8e00 -c 2:LVM &>/dev/null
else
  sgdisk ${DISK} -Zo -I -n 1:0:512M -t 1:ef00 -c 1:EFI \
    -n 2:0:0 -t 2:8e00 -c 2:LVM &>/dev/null
fi
msg "Current partition table:"
sgdisk -p ${DISK}
confirm

# Notify kernel about filesystem changes and get partition labels.
sleep 1 && partprobe ${DISK}
EFI="/dev/$(lsblk ${DISK} -o NAME,PARTLABEL | grep EFI | cut -d " " -f1 | cut -c7-)"
LVM="/dev/$(lsblk ${DISK} -o NAME,PARTLABEL | grep LVM | cut -d " " -f1 | cut -c7-)"

# Set up LUKS encryption for the LVM partition.
msg "Setting up full-disk encryption. You will be prompted for a password."
modprobe dm-crypt
cryptsetup luksFormat --cipher=aes-xts-plain64 \
  --key-size=512 --verify-passphrase ${LVM}
msg "Mounting the encrypted drive. You will be prompted for the password."
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
confirm

# Install packages to the / (root) partition.
pacman -Sy
msg "Installing packages:"
PKGS=""
# Base Arch Linux system.
PKGS+="base base-devel linux "
# Drivers.
PKGS+="linux-firmware sof-firmware alsa-firmware ${MICROCODE} "
# BIOS, UEFI and Secure Boot tools.
PKGS+="fwupd efibootmgr sbctl "
# CLI tools.
PKGS+="tmux zsh neovim btop git go man-db man-pages texinfo "
# Fonts.
PKGS+="terminus-font "
# Networking tools.
PKGS+="networkmanager wpa_supplicant network-manager-applet firefox "
# GNOME desktop environment.
PKGS+="gdm gnome-control-center gnome-shell-extensions gnome-themes-extra "
PKGS+="gnome-tweaks gnome-terminal wl-clipboard gnome-keyring eog "
PKGS+="xdg-desktop-portal xdg-desktop-portal-gnome xdg-desktop-portal-gtk "
# File(system) management tools.
PKGS+="lvm2 exfatprogs nautilus sushi gnome-disk-utility gvfs-mtp "
ask "Do you want to install miscellaneous applications [y/N]?"
if [[ $RESPONSE =~ ^(yes|y|Y|YES|Yes)$ ]]; then
  # Fonts.
  PKGS+="adobe-source-code-pro-fonts adobe-source-sans-fonts "
  # Networking tools.
  PKGS+="torbrowser-launcher "
  # Miscelaneous applications.
  # Applications that are rarely used and should be installed in a VM:
  # easytag, unrar, lmms, tuxguitar, pdfarranger, okular, libreofice-fresh.
  PKGS+="calibre gimp inkscape vlc guvcview signal-desktop telegram-desktop "
  PKGS+="transmission-gtk "
  # Virtualization software
  PKGS+="qemu-base libvirt virt-manager iptables-nft dnsmasq"
fi
pacstrap -K /mnt ${PKGS}
confirm

# Enable daemons.
systemctl enable bluetooth --root=/mnt &>/dev/null
systemctl enable NetworkManager --root=/mnt &>/dev/null
systemctl enable wpa_supplicant.service --root=/mnt &>/dev/null
systemctl enable systemd-resolved.service --root=/mnt &>/dev/null
systemctl enable gdm.service --root=/mnt &>/dev/null
systemctl enable systemd-timesyncd.service --root=/mnt &>/dev/null
systemctl mask geoclue.service --root=/mnt &>/dev/null

# Set hostname.
ask "Choose a hostname:" && HOSTNAME="${RESPONSE}"
echo "${HOSTNAME}" > /mnt/etc/hostname
cat >> /mnt/etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain   $HOSTNAME
EOF

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
msg "Choose a password for the root user:"
arch-chroot /mnt passwd
ask "Choose a username of a non-root user:" && USERNAME="${RESPONSE}"
arch-chroot /mnt useradd -m ${USERNAME}
arch-chroot /mnt usermod -aG wheel ${USERNAME}
msg "Choose a password for ${USERNAME}:"
arch-chroot /mnt passwd ${USERNAME}
sed -i 's/# \(%wheel ALL=(ALL\(:ALL\|\)) ALL\)/\1/g' /mnt/etc/sudoers
cat > /mnt/etc/gdm/custom.conf <<EOF
[daemon]
WaylandEnable=True
AutomaticLoginEnable=True
AutomaticLogin=${USERNAME}
EOF
clear

# Set up nvim as default editor globally.
echo "EDITOR=nvim" >> /mnt/etc/environment

# Configure disk mapping tables.
echo "lvm $LVM - luks,password-echo=no,x-systemd.device-timeout=0,timeout=0,\
no-read-workqueue,no-write-workqueue,discard" > /mnt/etc/crypttab.initramfs
cat >> /mnt/etc/fstab <<EOF
${EFI}             /efi   vfat    defaults     0       0
${ROOT}            /      ext4    defaults     0       0
${SWAP}            none   swap    defaults     0       0
EOF

# Configure mkinitcpio.
sed -i 's,HOOKS=(base udev autodetect modconf kms keyboard keymap consolefont block filesystems fsck),HOOKS=(base systemd keyboard autodetect modconf kms sd-vconsole block sd-encrypt lvm2 filesystems fsck),g' /mnt/etc/mkinitcpio.conf

# Create Unified Kernel Image.
# Also, add "quiet" later.
msg "Creating Unified Kernel Image:"
# i915.modeset=0 nouveau.modeset=1
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
rm /mnt/efi/initramfs-*.img &>/dev/null || true
rm /mnt/boot/initramfs-*.img &>/dev/null || true
confirm

# Configure Secure Boot.
msg "Configuring Secure Boot:"
arch-chroot /mnt /bin/bash -e <<EOF
  sbctl create-keys
  chattr -i /sys/firmware/efi/efivars/{KEK,db}* || true
  sbctl enroll-keys --microsoft
  sbctl sign --save /efi/EFI/Linux/arch.efi
  sbctl sign --save /efi/EFI/Linux/arch-fb.efi
EOF
confirm

# Add UEFI boot entries.
msg "Adding UEFI boot entries:"
efibootmgr --create --disk ${DISK} --part 1 \
  --label "Arch Linux" --loader "EFI\\Linux\\arch.efi"
efibootmgr --create --disk ${DISK} --part 1 \
  --label "Arch Linux (fallback)" --loader "EFI\\Linux\\arch-fb.efi"

# Finishing installation.
success "** Installation completed successfully! **"
msg "Please set up the desired boot order using:"
msg " >> efibootmgr --bootorder XXXX,YYYY,..."
msg "To remove unused boot entries, use:"
msg " >> efibootmgr -b XXXX --delete-bootnum"
msg "After finishing UEFI configuration, reboot into BIOS using:"
msg " >> systemctl reboot --firmware-setup"
msg "Inside the BIOS, enable Secure Boot and Boot Order Lock (if present)."