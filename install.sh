#!/bin/bash

set -e

# This script performs basic Arch Linux installation.
# The installation includes:
# --  LUKS encryption of / (root) and swap partitions using dm-crypt
# --  standard "linux" kernel
#     ["linux-hardened" lacks hibernation and reduces overall performance]
# --  CLI tools: tmux, zsh, neovim, btop
#     [including minimal dotfiles that enable essential functionality]
# --  Networking: networkmanager, firefox, torbrowser
# --  Desktop environment: GNOME [only DM and shell]
# --  Security tools: 
#     usbguard, apparmor [MAC], firejail [sandboxing], firewalld

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
    clear
}

# Reset terminal window.
loadkeys us && setfont ter-132b && clear
say "** ARCH LINUX INSTALLATION **"

# Check that Secure Boot is disabled.
say "Full Secure Boot reset is recommended before using this script. In BIOS:"
say "delete all SB keys, restore factory SB keys, then reset SB to Setup Mode."
say "Verifying Secure Boot status. Should return: disabled (setup)."
bootctl --quiet status | grep "Secure Boot:"
confirm "Is Secure Boot disabled and all the keys are reset to default"

# Test Internet connection.
status "Testing Internet connection: "
ping -w 5 archlinux.org &>/dev/null
NREACHED=${?}
if [ ${NREACHED} -ne 0 ]; then
    error "failed."
    status "Before proceeding with the installation, "
    say    "please make sure you have a functional Internet connection."
    say    "To connect to a WiFi network, use: "
    say    " >> iwctl station wlan0 connect <ESSID>."
    say    "To manually test the Internet connection, use: "
    say    " >> ping archlinux.org."
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
  status "Before proceeding with the installation, "
  status "please make sure the system is booted in UEFI mode. "
  say    "This setting can be configured in BIOS."
  exit
else
  success "success."
fi

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
say "List of all attached storage devices:"
lsblk -ado PATH,SIZE
ask "Choose the target drive for installation: /dev/" && DISK="/dev/${RESPONSE}"
confirm "This script will delete all the data on ${DISK}. Do you agree"

# Partition the target drive.
wipefs -af ${DISK} &>/dev/null
sgdisk ${DISK} -Zo -I -n 1:0:512M -t 1:ef00 -c 1:EFI \
  -n 2:0:0 -t 2:8e00 -c 2:LVM &>/dev/null

# Notify kernel about filesystem changes and get partition labels.
sleep 1 && partprobe ${DISK}
EFI="/dev/$(lsblk ${DISK} -o NAME,PARTLABEL | grep EFI | cut -d " " -f1 | cut -c7-)"
LVM="/dev/$(lsblk ${DISK} -o NAME,PARTLABEL | grep LVM | cut -d " " -f1 | cut -c7-)"

# Set up LUKS encryption for the LVM partition.
clear
say "Setting up full-disk encryption. You will be prompted for a password."
modprobe dm-crypt
cryptsetup luksFormat --cipher=aes-xts-plain64 \
  --key-size=512 --verify-passphrase ${LVM}
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
PKGS+="linux-firmware sof-firmware alsa-firmware ${MICROCODE} "
# BIOS, UEFI and Secure Boot tools.
PKGS+="fwupd efibootmgr sbctl "
# CLI tools.
PKGS+="tmux zsh neovim btop git go man-db man-pages texinfo "
# Fonts.
PKGS+="terminus-font adobe-source-code-pro-fonts adobe-source-sans-fonts "
# Networking tools.
PKGS+="networkmanager wpa_supplicant network-manager-applet firefox "
PKGS+="torbrowser-launcher "
# GNOME desktop environment.
PKGS+="gdm gnome-control-center gnome-shell-extensions gnome-themes-extra "
PKGS+="gnome-tweaks gnome-terminal wl-clipboard gnome-keyring eog "
# File(system) management tools.
PKGS+="lvm2 exfatprogs nautilus sushi gnome-disk-utility usbguard gvfs-mtp "
# Miscelaneous applications.
# Applications that are rarely used and should be installed in a VM:
# easytag, unrar, lmms, tuxguitar, pdfarranger, okular, libreofice-fresh.
PKGS+="calibre gimp inkscape vlc guvcview signal-desktop telegram-desktop "
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
systemctl enable usbguard-dbus.service --root=/mnt &>/dev/null
systemctl mask geoclue.service --root=/mnt &>/dev/null

# Set hostname.
ask "Choose a hostname: " && HOSTNAME="${RESPONSE}"
echo "${HOSTNAME}" > /mnt/etc/hostname
cat >> /mnt/etc/hosts <<EOF
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
ask "Choose a username of a non-root user: " && USERNAME="${RESPONSE}"
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

# Set up environment variables.
cat >> /mnt/etc/environment <<EOF
EDITOR=nvim
MOZ_ENABLE_WAYLAND=1
EOF

# Configure USB Guard.
arch-chroot /mnt /bin/bash -e <<EOF
  usbguard generate-policy > /home/rules.conf
  mv /home/rules.conf /etc/usbguard/rules.conf
  chmod 600 /etc/usbguard/rules.conf
EOF
cat >> /mnt/etc/polkit-1/rules.d/70-allow-usbguard.rules <<EOF
// Allow users in wheel group to communicate with USBGuard
polkit.addRule(function(action, subject) {
if ((action.id == "org.usbguard.Policy1.listRules" ||
action.id == "org.usbguard.Policy1.appendRule" ||
action.id == "org.usbguard.Policy1.removeRule" ||
action.id == "org.usbguard.Devices1.applyDevicePolicy" ||
action.id == "org.usbguard.Devices1.listDevices" ||
action.id == "org.usbguard1.getParameter" ||
action.id == "org.usbguard1.setParameter") &&
subject.active == true && subject.local == true &&
subject.isInGroup("wheel")) {
return polkit.Result.YES;
}
});
EOF

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
clear

# Configure Secure Boot.
say "Configuring Secure Boot."
arch-chroot /mnt /bin/bash -e <<EOF
  sbctl create-keys
  chattr -i /sys/firmware/efi/efivars/{KEK,db}* || true
  sbctl enroll-keys --microsoft
  sbctl sign --save /efi/EFI/Linux/arch.efi
  sbctl sign --save /efi/EFI/Linux/arch-fb.efi
EOF

# Add UEFI boot entries.
efibootmgr --create --disk ${DISK} --part 1 \
  --label "Arch Linux" --loader "EFI\\Linux\\arch.efi"
efibootmgr --create --disk ${DISK} --part 1 \
  --label "Arch Linux (fallback)" --loader "EFI\\Linux\\arch-fb.efi"

# Finishing installation.
success "** Installation completed successfully! **"
say "Please set up the desired boot order using:"
say " >> efibootmgr --bootorder XXXX,YYYY,..."
say "To remove unused boot entries, use:"
say " >> efibootmgr -b XXXX --delete-bootnum"
say "After finishing UEFI configuration, reboot into BIOS using:"
say " >> systemctl reboot --firmware-setup"
say "Inside the BIOS, enable Secure Boot and Boot Order Lock (if present)."
