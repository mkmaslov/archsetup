#!/bin/bash
 
set -e

# This script performs basic Arch Linux installation.

# It enables luks encryption and configures Wayland display server,
# GNOME desktop environment and Unified Kernel Image for UEFI Secure Boot.

RES="https://raw.githubusercontent.com/mkmaslov/archsetup/main"

# Highlight the output.
YELLOW="\e[1;33m" && RED="\e[1;31m" && GREEN="\e[1;32m" && COLOR_OFF="\e[0m"
cprint() { echo -ne "${1}${2}${COLOR_OFF}"; }
msg() { cprint ${YELLOW} "${1}\n"; }
status() { cprint ${YELLOW} "${1} "; }
error() { cprint ${RED} "${1}\n"; }
success() { cprint ${GREEN} "${1}\n"; }

# Prompt for a response.
ask () { status "$1 " && echo -ne "$2" && read RESPONSE; }

# Confirm whether a vital requirement for continuing installation is fulfilled.
# If not and the disks are already mounted - unmount and encrypt the drives.
confirm() { 
  ask "${1} [Y/n]?"
  if [[ ${RESPONSE} =~ ^(no|n|N|NO|No)$ ]]; then
    msg "Cancelling installation."
    if [ "$MOUNTED" -eq 0 ]; then
      umount ${EFI}
      umount ${ROOT}
      swapoff ${SWAP}
      vgchange -a n main
      cryptsetup close ${LVM}
    fi
    exit
  else
    clear
  fi
}

# Reset terminal window.
loadkeys us && setfont ter-132b && clear

# Choose instalaltion type.
msg "** ARCH LINUX INSTALLATION **"
msg "Installation types:"
msg    "Option #1: Arch Linux for PC (single OS)"
cprint "           [Unified Kernel Image, luks encryption, wayland, GNOME]\n"
msg    "Option #2: Arch Linux for PC (dual-boot)"
cprint "           [same as #1, but leaves space for Windows partition]\n"
msg    "Option #3: Arch Linux for server."
cprint "           [same as #1, but does not include GUI applications]\n"
ask "Choose installation type:" "Option #"
WINDOWS=1 && SERVER=1 && MOUNTED=1 && NVIDIA=1
case $RESPONSE in
  "2") WINDOWS=0 ;;
  "3") SERVER=0 ;;
esac

# Check whether Secure Boot is disabled.
msg "\nFull Secure Boot reset is recommended before using this script. In BIOS:"
msg "delete all SB keys, restore factory SB keys, then reset SB to Setup Mode."
msg "Verifying Secure Boot status. Should return: disabled (setup)."
bootctl --quiet status | grep "Secure Boot:"
confirm "Did you reset and disable Secure Boot"

# Test Internet connection.
status "Testing Internet connection:"
ping -w 5 archlinux.org &>/dev/null
NREACHED=${?}
if [ ${NREACHED} -ne 0 ]; then
  error "failed."
  status "Before proceeding with the installation,"
  msg    "please make sure you have a functional Internet connection."
  msg    "To connect to a WiFi network, use: "
  cprint " >> iwctl station wlan0 connect <ESSID>.\n"
  msg    "To manually test the Internet connection, use: "
  cprint " >> ping archlinux.org.\n"
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
confirm "Is system time correct and synchronized"

# Detect CPU vendor.
CPU=$(grep vendor_id /proc/cpuinfo)
if [[ ${CPU} == *"AuthenticAMD"* ]]; then
  MICROCODE=amd-ucode
else
  MICROCODE=intel-ucode
fi

# Choose a target drive.
msg "List of the attached storage devices:"
lsblk -ado PATH,SIZE
ask "Choose target drive for installation:" "/dev/" && DISK="/dev/${RESPONSE}"

# Partition target drive.
if [ "$WINDOWS" -eq 0 ]; then
  confirm "Installing Linux alongside Windows on ${DISK}. Do you agree"
  # Windows creates 4 partitions, including EFI.
  sgdisk ${DISK} -n 5:0:0 -t 5:8e00 -c 5:LVM &>/dev/null
else
  confirm "Deleting all data on ${DISK}. Do you agree"
  wipefs -af ${DISK} &>/dev/null
  sgdisk ${DISK} -Zo -I -n 1:0:512M -t 1:ef00 -c 1:EFI \
    -n 2:0:0 -t 2:8e00 -c 2:LVM &>/dev/null
fi
msg "Current partition table:"
sgdisk -p ${DISK}
confirm "Do you want to continue the installation"

# Notify kernel about filesystem changes and get partition labels.
msg "Updating information about partitions, please wait."
sleep 5 && partprobe ${DISK} && sleep 5
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
[ "$WINDOWS" -eq 1 ] && mkfs.fat -F 32 ${EFI} &>/dev/null
mkfs.ext4 ${ROOT} &>/dev/null
mkswap ${SWAP} && swapon ${SWAP}
mount ${ROOT} /mnt
mkdir /mnt/efi
mount ${EFI} /mnt/efi
MOUNTED=0
confirm "Do you want to continue the installation"

# Install packages to the / (root) partition.
msg "Installing packages:"
#pacman-key --refresh-keys &>/dev/null
pacman -Sy
PKGS=""
# Base Arch Linux system.
PKGS+="base base-devel linux "
# Drivers.
PKGS+="linux-firmware sof-firmware alsa-firmware ${MICROCODE} "
# UEFI and Secure Boot tools.
PKGS+="efibootmgr sbctl "
# Documentation.
PKGS+="man-db man-pages texinfo "
# CLI tools.
PKGS+="tmux neovim nano btop git go "
PKGS+="zsh zsh-completions zsh-syntax-highlighting zsh-autosuggestions "
# Fonts.
PKGS+="terminus-font "
# Networking tools.
PKGS+="networkmanager wpa_supplicant network-manager-applet firewalld "
# Audio.
# pipewire is installed as dependency of gdm -> mutter.
PKGS+="pipewire-pulse pipewire-alsa pipewire-jack "
# GNOME desktop environment - base packages.
PKGS+="gdm gnome-control-center gnome-terminal wl-clipboard gnome-keyring "
PKGS+="xdg-desktop-portal xdg-desktop-portal-gnome xdg-desktop-portal-gtk "
# File(system) management tools.
PKGS+="lvm2 nautilus sushi "
ask "Do you want to install proprietary NVIDIA driver [y/N]?"
if [[ $RESPONSE =~ ^(yes|y|Y|YES|Yes)$ ]]; then
  NVIDIA=0
  PKGS+="nvidia "
fi
pacstrap -K /mnt ${PKGS}
confirm "Do you want to continue the installation"

# Enable daemons.
systemctl enable bluetooth --root=/mnt &>/dev/null
systemctl enable NetworkManager --root=/mnt &>/dev/null
systemctl enable firewalld.service --root=/mnt &>/dev/null
systemctl enable wpa_supplicant.service --root=/mnt &>/dev/null
systemctl enable systemd-resolved.service --root=/mnt &>/dev/null
systemctl enable gdm.service --root=/mnt &>/dev/null
systemctl enable systemd-timesyncd.service --root=/mnt &>/dev/null
if [ "$NVIDIA" -eq 0 ]; then
  systemctl enable nvidia-suspend.service --root=/mnt &>/dev/null
  systemctl enable nvidia-hibernate.service --root=/mnt &>/dev/null
  systemctl enable nvidia-resume.service --root=/mnt &>/dev/null
fi

# Mask useless services.
systemctl mask geoclue.service --root=/mnt &>/dev/null
systemctl mask org.gnome.SettingsDaemon.UsbProtection.service --root=/mnt &>/dev/null
systemctl mask org.gnome.SettingsDaemon.Wacom.service --root=/mnt &>/dev/null
systemctl mask org.gnome.SettingsDaemon.Smartcard.service --root=/mnt &>/dev/null

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
arch-chroot /mnt useradd -m -G wheel -s /bin/zsh ${USERNAME}
curl "${RES}/resources/user.zshrc" > "/mnt/home/${USERNAME}/.zshrc"
msg "Choose a password for ${USERNAME}:"
arch-chroot /mnt passwd ${USERNAME}
sed -i 's/# \(%wheel ALL=(ALL\(:ALL\|\)) ALL\)/\1/g' /mnt/etc/sudoers
cat > /mnt/etc/gdm/custom.conf <<EOF
  [daemon]
  WaylandEnable=True
  AutomaticLoginEnable=True
  AutomaticLogin=${USERNAME}
EOF

# Set up nvim as default editor globally.
echo "EDITOR=nvim" >> /mnt/etc/environment

# Create default directory for PulseAudio. (to avoid journalctl warning)
mkdir -p /mnt/etc/pulse/default.pa.d

# Enable parallel downloads in pacman.
sed -i 's,#ParallelDownloads,ParallelDownloads,g' /mnt/etc/pacman.conf

# Configure disk mapping during decryption. (do NOT add spaces/tabs)
echo "lvm $LVM - luks,password-echo=no,x-systemd.device-timeout=0,timeout=0,\
no-read-workqueue,no-write-workqueue,discard" > /mnt/etc/crypttab.initramfs

# Configure disk mapping after decryption.
cat >> /mnt/etc/fstab <<EOF
  ${EFI}             /efi   vfat    defaults     0       0
  ${ROOT}            /      ext4    defaults     0       0
  ${SWAP}            none   swap    defaults     0       0
EOF

# Change mkinitcpio hooks. (do NOT add spaces/tabs)
sed -i "s,HOOKS=(base udev autodetect modconf kms keyboard keymap \
consolefont block filesystems fsck),HOOKS=(base systemd keyboard autodetect \
modconf kms sd-vconsole block sd-encrypt lvm2 filesystems fsck),g" \
/mnt/etc/mkinitcpio.conf

# Add mkinitcpio modules for NVIDIA driver.
if [ "$NVIDIA" -eq 0 ]; then
  sed -i "s,MODULES=(),\
  MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm),g" \
  /mnt/etc/mkinitcpio.conf
fi
confirm "Do you want to continue the installation"

# Create Unified Kernel Image.
msg "Creating Unified Kernel Image:"
if [ "$NVIDIA" -eq 0 ]; then
  echo "root=${ROOT} resume=${SWAP} cryptdevice=${LVM}:main rw quiet \
  nvidia_drm.modeset=1 nvidia_drm.fbdev=1" > /mnt/etc/kernel/cmdline
  echo "options nvidia \
  NVreg_PreserveVideoMemoryAllocations=1 NVreg_TemporaryFilePath=/var/tmp" > \
  /mnt/etc/modprobe.d/nvidia-power-management.conf
else
  echo "root=${ROOT} resume=${SWAP} cryptdevice=${LVM}:main rw quiet" > \
  /mnt/etc/kernel/cmdline
fi
echo "root=${ROOT} resume=${SWAP} cryptdevice=${LVM}:main rw" > \
  /mnt/etc/kernel/cmdline_fallback
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
confirm "Do you want to continue the installation"

# Configure Secure Boot.
#chattr -i /sys/firmware/efi/efivars/{KEK,db}* || true
msg "Configuring Secure Boot:"
arch-chroot /mnt /bin/bash -e <<EOF
  sbctl create-keys
  sbctl enroll-keys --microsoft
  sbctl sign --save /efi/EFI/Linux/arch.efi
  sbctl sign --save /efi/EFI/Linux/arch-fb.efi
EOF
confirm "Do you want to continue the installation"

# Add UEFI boot entries.
msg "Adding UEFI boot entries:"
efibootmgr --create --disk ${DISK} --part 1 \
  --label "Arch Linux" --loader "EFI\\Linux\\arch.efi"
efibootmgr --create --disk ${DISK} --part 1 \
  --label "Arch Linux (fallback)" --loader "EFI\\Linux\\arch-fb.efi"

# Download post-install script.
curl "${RES}/post_install.zsh" > /mnt/home/${USERNAME}/post_install.zsh

# Finish installation.
success "** Installation completed successfully! **"
msg    "Please set up the desired boot order using:"
cprint " >> efibootmgr --bootorder XXXX,YYYY,...\n"
msg    "To remove unused boot entries, use:"
cprint " >> efibootmgr -b XXXX --delete-bootnum\n"
msg    "After finishing UEFI configuration, reboot into BIOS using:"
cprint " >> systemctl reboot --firmware-setup\n"
msg    "Inside the BIOS, enable Secure Boot and Boot Order Lock (if present)."