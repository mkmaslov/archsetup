#!/bin/bash
 
set -e

# -----------------------------------------------------------------------------
# This script performs basic Arch Linux installation.
# 
# There are three installation types (details below):
# Arch Linux as a single OS, dual boot with Windows, and headless server setup.
# -----------------------------------------------------------------------------

# GitHub repository containing necessary dotfiles.
RESOURCES="https://raw.githubusercontent.com/mkmaslov/archsetup/main"

# Highlight the output.
YELLOW="\e[1;33m" && RED="\e[1;31m" && GREEN="\e[1;32m" && COLOR_OFF="\e[0m"
cprint() { echo -ne "${1}${2}${COLOR_OFF}"; }
msg() { cprint ${YELLOW} "${1}\n"; }
status() { cprint ${YELLOW} "${1} "; }
error() { cprint ${RED} "${1}\n"; }
success() { cprint ${GREEN} "${1}\n"; }

# Prompt for a response.
ask () { status "$1 " && echo -ne "$2" && read RESPONSE; }

# Confirm whether a certain requirement for continuing installation is fulfilled.
# If not and the disks are already mounted - unmount and encrypt the drives.
confirm() { 
  ask "${1} [Y/n]?"
  if [[ ${RESPONSE} =~ ^(no|n|N|NO|No)$ ]]; then
    error "Cancelling installation."
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

# -----------------------------------------------------------------------------
# Initial checks.
# -----------------------------------------------------------------------------

# Reset terminal window.
loadkeys us ; setfont ter-132b ; clear

# Choose installation type.
msg    "** ARCH LINUX INSTALLATION **"
msg    "Available installation types:"
msg    "[1]: Arch Linux as a single OS, includes:"
cprint "     - Secure Boot, Unified Kernel Image, luks encryption\n"
cprint "     - Wayland display server, GNOME desktop environment\n"
cprint "     - AppArmor+audit (MAC), nftables (firewall), firejail (sandboxing)\n"
msg    "[2]: Arch Linux alongside Windows. Same as [1], but:"
cprint "     - does not erase the disk, preserving Windows partitions\n"
cprint "     - uses EFI boot partition created by Windows\n"
error  "       (WARNING! Windows Update may prevent Linux from booting!)\n"
msg    "[3]: Arch Linux as a single OS on a headless server."
cprint "     - This option is not implemented yet."
ask "Choose installation type [1,2,3]:" "" ; clear
WINDOWS=1 ; SERVER=1 ; MOUNTED=1 ; NVIDIA=1
case $RESPONSE in
  "2") WINDOWS=0 ;;
  "3") SERVER=0 ;;
esac

# Check whether Secure Boot is disabled.
msg "Full Secure Boot reset is recommended before using this script."
cprint "To perform the reset:\n"
cprint "- Enter BIOS firmware (by pressing F1/F2/Esc/Enter/Del at boot)\n"
cprint "- Navigate to the \"Security\" settings tab\n"
cprint "- Delete/Clear all Secure Boot keys\n"
cprint "- Restore factory default Secure Boot keys\n"
cprint "- Reset Secure Boot to \"Setup Mode\"\n"
cprint "- Disable Secure Boot\n"
msg "Verifying Secure Boot status. The output should contain: disabled (setup)."
bootctl --quiet status | grep "Secure Boot:"
confirm "Did you reset and disable Secure Boot"

# Test Internet connection.
status "Testing Internet connection (takes few seconds): "
ping -w 5 archlinux.org &>/dev/null
NREACHED=${?}
if [ ${NREACHED} -ne 0 ]; then
  error  "failed."
  cprint "Before proceeding with the installation, "
  cprint "please make sure you have a functional Internet connection.\n"
  cprint "To connect to a WiFi network, use:\n"
  cprint ">>  iwctl station wlan0 connect <ESSID>.\n"
  cprint "To manually test the Internet connection, use: "
  cprint ">>  ping archlinux.org.\n"
  exit
else
  success "success."
  timedatectl set-ntp true
fi

# Check that system is booted in UEFI mode.
status "Checking UEFI boot mode: "
COUNT=$(ls /sys/firmware/efi/efivars | grep -c '.')
if [ ${COUNT} -eq 0 ]; then
  error  "failed."
  cprint "Before proceeding with the installation, "
  cprint "please make sure the system is booted in UEFI mode."
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

# -----------------------------------------------------------------------------
# Disk configuration.
# -----------------------------------------------------------------------------

# Choose the target drive.
msg "List of attached storage devices:"
lsblk -ado PATH,SIZE
ask "Choose target drive for installation:" "/dev/" && DISK="/dev/${RESPONSE}"

# Partition target drive.
if [ "$WINDOWS" -eq 0 ]; then
  confirm "Installing Linux alongside Windows on ${DISK}. Do you agree"
  # Windows creates 4 partitions, including EFI boot partition.
  # Hence, Arch Linux only needs one partition that takes all free disk space.
  sgdisk ${DISK} -n 5:0:0 -t 5:8e00 -c 5:LVM &>/dev/null
else
  confirm "Deleting all data on ${DISK}. Do you agree"
  wipefs -af ${DISK} &>/dev/null
  sgdisk ${DISK} -Zo -I -n 1:0:4096M -t 1:ef00 -c 1:EFI \
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
EFI_UUID="$(lsblk ${DISK} -o PARTUUID,PARTLABEL | grep EFI | cut -d \" \" -f1)"
LVM_UUID="$(lsblk ${DISK} -o PARTUUID,PARTLABEL | grep LVM | cut -d \" \" -f1)"

# Set up LUKS encryption for the LVM partition.
msg "Setting up full-disk encryption. You will be prompted for a password."
modprobe dm-crypt
cryptsetup luksFormat --cipher=aes-xts-plain64 \
  --key-size=512 --verify-passphrase ${LVM}
msg "Mounting the encrypted drive. You will be prompted for the password."
cryptsetup open --type luks ${LVM} lvm

# Create LVM volumes, format and mount partitions.
MAPLVM="/dev/mapper/lvm"
pvcreate ${MAPLVM} && vgcreate main ${MAPLVM}
lvcreate -L18G main -n swap
lvcreate -l 100%FREE main -n root
SWAP="/dev/mapper/main-swap"
SWAP_UUID="$(lsblk ${DISK} -o UUID,NAME | grep "main-swap" | cut -d " " -f1)"
ROOT="/dev/mapper/main-root"
ROOT_UUID="$(lsblk ${DISK} -o UUID,NAME | grep "main-root" | cut -d " " -f1)"
[ "$WINDOWS" -eq 1 ] && mkfs.fat -F 32 ${EFI} &>/dev/null
mkfs.ext4 ${ROOT} &>/dev/null
mkswap ${SWAP} && swapon ${SWAP}
mount ${ROOT} /mnt
mkdir /mnt/efi
mount ${EFI} /mnt/efi
MOUNTED=0
confirm "Do you want to continue the installation"

# -----------------------------------------------------------------------------
# Package installation.
# -----------------------------------------------------------------------------

# Install packages to the / (root) partition.
msg "Installing packages:"
# If the USB installation medium is old, one needs to update pacman keys:
# (this operation takes a long time and is therefore disabled by default)
# pacman-key --refresh-keys &>/dev/null
# Update pacman cache.
pacman -Sy
# Create a list of packages.
PKGS=""
# Base Arch Linux system.
PKGS+="base base-devel linux "
# Drivers.
PKGS+="linux-firmware sof-firmware alsa-firmware ${MICROCODE} "
# UEFI and Secure Boot tools.
PKGS+="efibootmgr sbctl "
# AppArmor (Mandatory Access Control system) and Audit framework
PKGS+="apparmor audit "
# Application sandboxing.
PKGS+="firejail firetools "
# Documentation.
PKGS+="man-db man-pages texinfo "
# CLI tools.
PKGS+="tmux neovim nano btop git go jq "
PKGS+="zsh zsh-completions zsh-syntax-highlighting zsh-autosuggestions "
# Fonts.
PKGS+="terminus-font "
# Networking tools.
PKGS+="networkmanager wpa_supplicant network-manager-applet "
# Audio.
# pipewire is installed as dependency of gdm -> mutter.
PKGS+="pipewire-pulse pipewire-alsa pipewire-jack "
# GNOME desktop environment - base packages.
PKGS+="gdm gnome-control-center gnome-terminal wl-clipboard gnome-keyring "
PKGS+="xdg-desktop-portal xdg-desktop-portal-gnome xdg-desktop-portal-gtk "
# File(system) management tools.
PKGS+="lvm2 nautilus sushi "
ask "Do you want to install the proprietary NVIDIA driver [y/N]?"
if [[ $RESPONSE =~ ^(yes|y|Y|YES|Yes)$ ]]; then
  NVIDIA=0
  PKGS+="nvidia "
fi
# Install packages.
pacstrap -K /mnt ${PKGS}
confirm "Do you want to continue the installation"

# Enable daemons.
systemctl enable apparmor.service --root=/mnt &>/dev/null
systemctl enable auditd.service --root=/mnt &>/dev/null
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

# -----------------------------------------------------------------------------
# User configuration.
# -----------------------------------------------------------------------------

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

# Set up environment variables.
cat >> /mnt/etc/environment <<EOF
  EDITOR=nvim
  # Choose wayland by default
  QT_QPA_PLATFORMTHEME="wayland;xcb"
  ELECTRON_OZONE_PLATFORM_HINT=auto
EOF
if [ "$NVIDIA" -eq 0 ]; then
  echo "GBM_BACKEND=nvidia-drm" >> /mnt/etc/environment
fi

# Create default directory for PulseAudio. (to avoid journalctl warning)
mkdir -p /mnt/etc/pulse/default.pa.d

# Enable parallel downloads in pacman.
sed -i 's,#ParallelDownloads,ParallelDownloads,g' /mnt/etc/pacman.conf

# Enable AppArmor rules cashing.
sed -i 's,#write-cache,write-cache,g' /mnt/etc/apparmor/parser.conf

# -----------------------------------------------------------------------------
# Unified Kernel Image configuration.
# -----------------------------------------------------------------------------

# Configure disk mapping during decryption. (do NOT add spaces/tabs)
echo "lvm UUID=${LVM_UUID} - \
luks,password-echo=no,x-systemd.device-timeout=0,timeout=0,\
no-read-workqueue,no-write-workqueue,discard" > /mnt/etc/crypttab.initramfs

# Configure disk mapping after decryption.
cat >> /mnt/etc/fstab <<EOF
  UUID=${EFI_UUID}    /efi   vfat    defaults     0       0
  UUID=${ROOT_UUID}   /      ext4    defaults     0       0
  UUID=${SWAP_UUID}   none   swap    defaults     0       0
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
# Kernel parameters: disk mapping
CMDLINE="root=UUID=${ROOT_UUID} resume=UUID=${SWAP_UUID} "
CMDLINE+="cryptdevice=UUID=${LVM_UUID}:main rw "
# Fallback image should contain minimal amount of kernel parameters.
echo ${CMDLINE} > /mnt/etc/kernel/cmdline_fallback
# Kernel parameters: security
CMDLINE+="lsm=landlock,lockdown,yama,integrity,apparmor,bpf audit=1 "
# Kernel parameters: NVIDIA drivers
if [ "$NVIDIA" -eq 0 ]; then
  CMDLINE+="nvidia_drm.modeset=1 nvidia_drm.fbdev=1"
  echo "options nvidia \
  NVreg_PreserveVideoMemoryAllocations=1 NVreg_TemporaryFilePath=/var/tmp" > \
  /mnt/etc/modprobe.d/nvidia-power-management.conf
fi
echo ${CMDLINE} > /mnt/etc/kernel/cmdline
# creating preset
cat > /mnt/etc/mkinitcpio.d/linux.preset <<EOF
  ALL_config="/etc/mkinitcpio.conf"
  ALL_kver="/boot/vmlinuz-linux"
  ALL_microcode=(/boot/*-ucode.img)
  PRESETS=('default' 'fallback')
  default_uki="/efi/EFI/Linux/arch.efi"
  fallback_options="-S autodetect --cmdline /etc/kernel/cmdline_fallback"
  fallback_uki="/efi/EFI/Linux/arch-fb.efi"
EOF
mkdir -p /mnt/efi/EFI/Linux
arch-chroot /mnt mkinitcpio -P
rm /mnt/efi/initramfs-*.img &>/dev/null || true
rm /mnt/boot/initramfs-*.img &>/dev/null || true
confirm "Do you want to continue the installation"

# -----------------------------------------------------------------------------
# Bootloader configuration.
# -----------------------------------------------------------------------------

# Configure Secure Boot.
msg "Configuring Secure Boot:"
# In some cases, the following command is required before enrolling keys:
# chattr -i /sys/firmware/efi/efivars/{KEK,db}* || true
arch-chroot /mnt /bin/bash -e <<EOF
  sbctl create-keys
  sbctl enroll-keys --microsoft
  sbctl sign --save /efi/EFI/Linux/arch-linux.efi
  sbctl sign --save /efi/EFI/Linux/arch-linux-fallback.efi
EOF
confirm "Do you want to continue the installation"

# Create UEFI boot entries.
msg "Creating UEFI boot entries:"
efibootmgr --create --disk ${DISK} --part 1 \
  --label "Arch Linux" --loader "EFI\\Linux\\arch-linux.efi"
efibootmgr --create --disk ${DISK} --part 1 \
  --label "Arch Linux (fallback)" --loader "EFI\\Linux\\arch-linux-fallback.efi"
success "UEFI boot entries successfully created!"

# Finish installation.
clear ; success "** Arch Linux installation completed successfully! **"
cprint  "Please set up the desired boot order using:"
cprint  ">>  efibootmgr --bootorder XXXX,YYYY,...\n"
cprint  "To remove unused boot entries, use:"
cprint  ">>  efibootmgr -b XXXX --delete-bootnum\n"
cprint  "After finishing UEFI configuration, reboot into BIOS using:"
cprint  ">>  systemctl reboot --firmware-setup\n"
cprint  "Inside the BIOS, enable Secure Boot and Boot Order Lock (if present)."
# -----------------------------------------------------------------------------