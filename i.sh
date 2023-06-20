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
say() { echo -e "${YELLOW}$1${COLOR_OFF}"; }
status() { echo -ne "${YELLOW}$1${COLOR_OFF}"; }
error() { echo -e "${RED}$1${COLOR_OFF}"; }
success() { echo -e "${GREEN}$1${COLOR_OFF}"; }

# Prompt for a response.
ask() { echo -ne "${YELLOW}$1" && read RESPONSE && echo -ne "${COLOR_OFF}"; }

# Confirm continuing installation.
confirm() { 
    ask "$1 [y/N]? "
    if [[ !($RESPONSE =~ ^(yes|y|Y|YES|Yes)$) ]]; then
        say "Cancelling installation." && exit
    fi
}

# Reset terminal window.
loadkeys us && setfont ter-132b && clear
say "** ARCH LINUX INSTALLATION **"

# Test Internet connection.
status "Testing Internet connection: "
ping -w 5 archlinux.org &>/dev/null
NREACHED=$?
if [ $NREACHED -ne 0 ]; then
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
if [ $COUNT -eq 0 ]; then
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

# Check system clock synchronization.
say "Checking time synchronization."
timedatectl status | grep -E 'Local time|synchronized'
confirm "Is the time correct (UTC+1) and synchronized"

# Detect CPU vendor.
CPU=$(grep vendor_id /proc/cpuinfo)
if [[ $CPU == *"AuthenticAMD"* ]]; then
    MICROCODE=amd-ucode
else
    MICROCODE=intel-ucode
fi

# Choose a target drive.
lsblk -ado PATH,SIZE
ask "Choose the target drive for installation: /dev/" && DISK="/dev/$RESPONSE"
confirm "This script will delete all the data on $DISK. Do you agree"

# Partition the target drive.
wipefs -af "$DISK" &>/dev/null
sgdisk "$DISK" -Zo -I -n 1:0:512M -t 1:ef00 -c 1:EFI \
  -n 2:0:0 -t 2:8e00 -c 2:LVM &>/dev/null

# Notify kernel about filesystem changes and get partition labels.
sleep 1 && partprobe "$DISK"
EFI="/dev/$(lsblk $DISK -o NAME,PARTLABEL | grep EFI | cut -d " " -f1 | cut -c7-)"
LVM="/dev/$(lsblk $DISK -o NAME,PARTLABEL | grep LVM | cut -d " " -f1 | cut -c7-)"

# Set up LUKS encryption for the LVM partition.
say "Setting up full-disk encryption. You will be prompted for a password."
modprobe dm-crypt
cryptsetup luksFormat --cipher=aes-xts-plain64 \
  --key-size=512 --sector-size 4096 --verify-passphrase --verbose $LVM
say "Mounting the encrypted drive. You will be prompted for the password."
cryptsetup open --type luks $LVM lvm

#systemctl reboot --firmware-setup
