#!/bin/bash
# Install Arch Linux with full-disk encryption.

# Highlight message.
yellow="\e[1;33m" && red="\e[1;31m" && green="\e[1;32m" && color_off="\e[0m"
function say () { echo -e "${yellow}$1${color_off}";}
function status () { echo -ne "${yellow}$1${color_off}";}
function error () { echo -e "${red}$1${color_off}";}
function success () { echo -e "${green}$1${color_off}";}

# Prompt for response.
function ask () { 
  echo -ne "${yellow}$1" && read response && echo -ne "${color_off}"
}

# Confirm continuing evaluation.
function confirm () { 
    ask "$1 [y/N]?"
    if [[ !($response =~ ^(yes|y|Y|YES|Yes)$) ]]; then
        say "Cancelling installation." && exit
    fi
}

# Reset terminal.
loadkeys us && setfont ter-132b && clear
say "** Arch Linux Installation **"

# Test Internet connection.
status "Testing Internet connection: "
ping -w 5 archlinux.org &>/dev/null
further=$?
if [ $further -ne 0 ]; then
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
status "Checking UEFI boot mode:"
count=$(ls /sys/firmware/efi/efivars | grep -c '.')
if [ $count -eq 0 ]; then
  error "failed."
  echo -e "Before proceeding with installation, please make sure your system is booted in UEFI mode. This can be set up in BIOS."
  exit
else
  success "success."
fi

# Check that Secure Boot is disabled.
say "Checking Secure Boot status. Should return: disabled (setup)."
bootctl --quiet status | grep "Secure Boot"
confirm "Is Secure Boot disabled"

# Check system clock synchronization.
say "Checking time synchronization."
timedatectl status | grep -E 'Local time|synchronized'
confirm "Is the time correct"

# Detect CPU vendor.
CPU=$(grep vendor_id /proc/cpuinfo)
if [[ $CPU == *"AuthenticAMD"* ]]; then
    microcode=amd-ucode
else
    microcode=intel-ucode
fi

# Choose target drive.
lsblk -ado PATH,SIZE
ask "Choose the drive: /dev/" && disk="/dev/$response"
confirm "This will delete all the data on $disk. Do you agree"

# Partition target drive.
wipefs -af "$disk"
sgdisk -Zo "$disk"
parted -s "$disk" \
  mklabel gpt \
  mkpart ESP fat32 1MiB 512MiB \
  set 1 esp on \
  mkpart cryptroot 512MiB 100%
sleep 1
esp="/dev/$(lsblk $disk -o NAME,PARTLABEL | grep ESP| cut -d " " -f1 | cut -c7-)"
cryptroot="/dev/$(lsblk $disk -o NAME,PARTLABEL | grep cryptroot | cut -d " " -f1 | cut -c7-)"
partprobe "$disk"
say "ESP here: $esp"
say "cryptroot here: $cryptroot"
