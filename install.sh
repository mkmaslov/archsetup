#!/bin/bash
# Install Arch Linux with full-disk encryption.
set -e

# Highlight a message.
color_on="\e[1;33m" && color_off="\e[0m"
function say () { echo -e "${color_on}$1${color_off}";}

# Prompt for a response.
function ask () { 
  echo -en "${color_on}$1" && read response && echo -en "${color_off}"
}

# Confirm continuing evaluation.
function confirm () { 
    ask "$1 [y/N]?"
    if [[ !($response =~ ^(yes|y|Y|YES|Yes)$) ]]; then
        say "Quitting installation." && exit
    fi
}

# Reset terminal
loadkeys us && setfont ter-132b && clear
say "\n** Arch Linux Installation **\n"
say "Before proceeding, please activate your WiFi connection."
say "For instance, use: iwctl station wlan0 connect <ESSID>."
say "To probe connection to Internet, use: ping archlinux.org."
confirm "Do you confirm that the Internet is reachable?"
