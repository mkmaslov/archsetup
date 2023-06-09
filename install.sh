#!/bin/bash
# Install Arch Linux with full-disk encryption.
set -e

# Highlight a message.
yellow="\e[1;33m" && red="\e[1;31m" && green="\e[1;32m" && color_off="\e[0m"
function say () { echo -ne "${yellow}$1${color_off}";}
function error () { echo -ne "${red}$1${color_off}";}
function success () { echo -ne "${red}$1${color_off}";}

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
say "Testing Internet connection: "
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
