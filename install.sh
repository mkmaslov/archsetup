#!/bin/bash
# Install Arch Linux with full-disk encryption.

# Highlight a message.
yellow="\e[1;33m" && red="\e[1;31m" && green="\e[1;32m" && color_off="\e[0m"
function say () { echo -e "${yellow}$1${color_off}";}
function status () { echo -ne "${yellow}$1${color_off}";}
function error () { echo -e "${red}$1${color_off}";}
function success () { echo -e "${green}$1${color_off}";}

# Prompt for a response.
function ask () { 
  echo -ne "${yellow}$1" && read response && echo -ne "${color_off}"
}

# Confirm continuing evaluation.
function confirm () { 
    ask "$1 [y/N]?"
    if [[ !($response =~ ^(yes|y|Y|YES|Yes)$) ]]; then
        say "Quitting installation." && exit
    fi
}

# Reset terminal.
loadkeys us && setfont ter-132b && clear
say "\n** Arch Linux Installation **\n"

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
fi

# Veryfy that system is booted in UEFI mode.
status "Checking UEFI boot mode:"
count=$(ls /sys/firmware/efi/efivars | grep -c '.')
if [ $count -eq 0 ]; then
  error "failed."
  echo -e "Before proceeding with installation, please make sure your system boots in UEFI mode. This behavior can be set up in BIOS."
  exit
else
  success "success."
fi

# Veryfy that Secure Boot is disabled.
say "Checking Secure Boot status. Should be: disabled (setup)."
bootctl status | grep "Secure Boot"
confirm "Is Secure Boot disabled"

# Veryfy system clock synchronization.
say "Checking time synchronization."
timedatectl set-ntp true
sleep 1
timedatectl status | grep -E 'Local time|synchronized'
confirm "Is system clock synchronized"

# Detect CPU vendor.
CPU=$(grep vendor_id /proc/cpuinfo)
if [[ $CPU == *"AuthenticAMD"* ]]; then
    microcode=amd-ucode
else
    microcode=intel-ucode
fi
