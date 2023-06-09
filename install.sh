#!/bin/bash
# Install Arch Linux with full-disk encryption.
set -e

# Highlight a message.
yellow="\e[1;33m" && red="\e[1;31m" && color_off="\e[0m"
function say () { echo -e "${yellow}$1${color_off}";}
function error () { echo -e "${red}$1${color_off}";}

# Prompt for a response.
function ask () { 
  echo -en "${yellow}$1" && read response && echo -en "${color_off}"
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
say "Testing Internet connection."
ping -w 5 archlinux.org &>/dev/null
further=$?
if [ $further -ne 0 ]; then
    error "Couldn't connect to Internet."
    echo -e "Before proceeding with the installation, you must have a functioning Internet connection."
    echo -e "To connect to WiFi network, use: iwctl station wlan0 connect <ESSID>."
    echo -e "To test your connection, use: ping archlinux.org."
    exit
fi
