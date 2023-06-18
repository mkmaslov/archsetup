#!/bin/bash
# Install Arch Linux with full-disk encryption.

# Highlight a message.
YELLOW="\e[1;33m" && RED="\e[1;31m" && GREEN="\e[1;32m" && COLOR_OFF="\e[0m"
function say () { echo -e "${YELLOW}$1${COLOR_OFF}";}
function status () { echo -ne "${YELLOW}$1${COLOR_OFF}";}
function error () { echo -e "${RED}$1${COLOR_OFF}";}
function success () { echo -e "${GREEN}$1${COLOR_OFF}";}

# Prompt for a response.
function ask () { 
  echo -ne "${YELLOW}$1" && read RESPONSE && echo -ne "${COLOR_OFF}"
}

# Confirm continuing evaluation.
function confirm () { 
    ask "$1 [y/N]? "
    if [[ !($RESPONSE =~ ^(yes|y|Y|YES|Yes)$) ]]; then
        say "Cancelling installation." && exit
    fi
}

# Reset terminal.
loadkeys us && setfont ter-132b && clear
say "** Arch Linux Installation **"

# Test Internet connection.
status "Testing Internet connection: "
ping -w 5 archlinux.org &>/dev/null
NREACHED=$?
if [ $NREACHED -ne 0 ]; then
    error "failed."
    echo -e "Before proceeding with installation, please make sure you have a functional Internet connection."
    echo -e "To connect to WiFi network, use: iwctl station wlan0 connect <ESSID>."
    echo -e "To test your connection, use: ping archlinux.org."
    exit
else
  success "success."
  timedatectl set-ntp true
fi

# Check that system is booted in UEFI mode.
status "Checking UEFI boot mode: "
COUNT=$(ls /sys/firmware/efi/efivars | grep -c '.')
if [ $COUNT -eq 0 ]; then
  error "failed."
  echo -e "Before proceeding with installation, please make sure your system is booted in UEFI mode. This can be set up in BIOS."
  exit
else
  success "success."
fi

# Check that Secure Boot is disabled.
say "Checking Secure Boot status. Should return: disabled (setup)."
bootctl --quiet status | grep "Secure Boot:"
confirm "Is Secure Boot disabled"

# Check system clock synchronization.
say "Checking time synchronization."
timedatectl status | grep -E 'Local time|synchronized'
confirm "Is the clock correct and synchronized"

# Detect CPU vendor.
CPU=$(grep vendor_id /proc/cpuinfo)
if [[ $CPU == *"AuthenticAMD"* ]]; then
    MICROCODE=amd-ucode
else
    MICROCODE=intel-ucode
fi

# Choose target drive.
lsblk -ado PATH,SIZE
ask "Choose the drive: /dev/" && DISK="/dev/$RESPONSE"
confirm "This will delete all the data on $DISK. Do you agree"

# Partition target drive.
wipefs -af "$DISK" &>/dev/null
sgdisk -Zo "$DISK" &>/dev/null
parted -s "$DISK" \
  mklabel gpt \
  mkpart ESP fat32 1MiB 512MiB \
  set 1 esp on \
  mkpart swap linux-swap 512MiB 16896MiB \
  mkpart cryptroot 16896MiB 100%
sleep 1
EFI="/dev/$(lsblk $DISK -o NAME,PARTLABEL | grep ESP | cut -d " " -f1 | cut -c7-)"
CRYPTROOT="/dev/$(lsblk $DISK -o NAME,PARTLABEL | grep cryptroot | cut -d " " -f1 | cut -c7-)"
SWAP="/dev/$(lsblk $DISK -o NAME,PARTLABEL | grep swap | cut -d " " -f1 | cut -c7-)"
partprobe "$DISK"
mkfs.fat -F 32 $EFI &>/dev/null
mkswap $SWAP && swapon $SWAP

# Set up LUKS encryption for the root partition.
say "Setting up full-disk encryption. You will be prompted for a password."
modprobe dm-crypt
cryptsetup luksFormat --cipher=aes-xts-plain64 --key-size=512 --sector-size 4096 --verify-passphrase --verbose $CRYPTROOT
say "Opening the LUKS Container. You will be prompted for the password."
cryptsetup open $CRYPTROOT cryptroot

# Format root partition.
ROOTFS="/dev/mapper/cryptroot"
mkfs.ext4 $ROOTFS &>/dev/null
mount $ROOTFS /mnt
mkdir /mnt/efi
mount $EFI /mnt/efi

# Install packages to the new root.
pacman -Sy
say "Installing packages."
# Installing basic Arch Linux system with hardened Linux kernel
pacstrap -K /mnt base linux-hardened linux-firmware ${MICROCODE}
arch-chroot /mnt /bin/bash -e <<EOF
# Select timezone and synchronize clock.
ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime
systemctl enable systemd-timesyncd.service &>/dev/null
hwclock --systohc
# Install BIOS, UEFI and Secure Boot tools.
pacman -S fwupd efibootmgr sbctl
# Install Linux documentation tools.
pacman -S man-db man-pages texinfo
# Install CLI tools.
pacman -S zsh neovim btop git
# Install fonts.
pacman -S terminus-font adobe-source-code-pro-fonts adobe-source-sans-fonts
# Install networking software.
pacman -S networkmanager wpa_supplicant network-manager-applet
systemctl enable NetworkManager &>/dev/null
systemctl enable wpa_supplicant.service &>/dev/null
systemctl enable systemd-resolved.service &>/dev/null
# Install desktop environment.
pacman -S gnome-terminal gdm gnome-control-center gnome-disk-utility gnome-shell-extensions gnome-tweaks
systemctl enable gdm.service &>/dev/null
# Installing system utilities.
pacman -S exfatprogs nautilus sushi gnome-disk-utility
# Install applications.
pacman -S calibre inkscape vlc signal-desktop telegram-desktop
# Progs for VM: easytag, unrar, lmms, tuxguitar, pdfarranger, libreofice-fresh
# Set up users.
say "Now, you will be prompted for the root password."
passwd
ask "Please enter username of a non-root user:" && username="$RESPONSE"
useradd -m $USERNAME
say "Now, you will be prompted for the $USERNAME's password."
passwd $USERNAME
EOF

# Set hostname.
ask "Please enter hostname: " && HOSTNAME="$RESPONSE"
echo "$HOSTNAME" > /mnt/etc/hostname
cat > /mnt/etc/hosts <<EOF
# Static table lookup for hostnames.
# See hosts(5) for details.
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

# Configure disk mapping tables.
ROOTUUID=$(blkid $CRYPTROOT | cut -f2 -d'"')
echo "cryptroot  UUID=$ROOTUUID  -  password-echo=no,x-systemd.device-timeout=0,timeout=0,no-read-workqueue,no-write-workqueue,discard" > /mnt/etc/crypttab.initramfs
swapoff $SWAP
mkfs.ext2 -L cryptswap $SWAP 1M
SWAPUUID=$(blkid $SWAP | cut -f2 -d'"')
cat > /mnt/etc/crypttab <<EOF
# Configuration for encrypted block devices.
# See crypttab(5) for details.
# <name>   <device>        <password>    <options>
cryptswap  UUID=$SWAPUUID  /dev/urandom  swap,offset=2048
EOF

cat > /mnt/etc/fstab <<EOF
# Static information about the filesystems.
# See fstab(5) for details.
# <file system>        <dir>  <type>  <options>      <dump>  <pass>
$EFI                   /efi   vfat    defaults,ssd   0       0
$ROOTFS                /      ext4    defaults,ssd   0       0
/dev/mapper/cryptswap  none   swap    defaults       0       0
EOF

# Configure mkinitcpio.
sed -i 's,HOOKS=(base udev autodetect modconf kms keyboard keymap consolefont block filesystems fsck),HOOKS=(base systemd keyboard autodetect modconf kms sd-vconsole block sd-encrypt filesystems fsck),g' /mnt/etc/mkinitcpio.conf

# Create Unified Kernel Image.
# Also, add "quiet" later.
echo "root=/dev/mapper/cryptroot rw" > /mnt/etc/kernel/cmdline
echo "root=/dev/mapper/cryptroot rw" > /mnt/etc/kernel/cmdline_fallback
cat > /mnt/etc/mkinitcpio.d/linux.preset <<EOF
ALL_config="/etc/mkinitcpio.conf"
ALL_kver="/boot/vmlinuz-linux"
ALL_microcode=(/boot/*-ucode.img)
PRESETS=('default' 'fallback')
default_uki="/efi/EFI/Linux/archlinux.efi"
fallback_options="-S autodetect --cmdline /etc/kernel/cmdline_fallback"
fallback_uki="/efi/EFI/Linux/archlinux-fallback.efi"
EOF
mkdir /mnt/efi/EFI && mkdir /mnt/efi/EFI/Linux
arch-chroot /mnt mkinitcpio -P
rm /mnt/efi/initramfs-*.img &>/dev/null
rm /mnt/boot/initramfs-*.img &>/dev/null

# Configure Secure Boot.
arch-chroot /mnt /bin/bash -e <<EOF
  sbctl create-keys
  sbctl enroll-keys
  sbctl sign --save /efi/EFI/Linux/archlinux.efi
  sbctl sign --save /efi/EFI/Linux/archlinux-fallback.efi
EOF

# Finish installation.
say "Rebooting to BIOS. Please enable Secure Boot and restart."
umount -R /mnt
say "Completed."
#systemctl reboot --firmware-setup
