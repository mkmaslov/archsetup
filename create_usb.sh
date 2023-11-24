#!/bin/bash
#
# This script creates bootable USB drive using the latest Arch Linux image.
# 
set -e

# Function to highlight a message.
color_on="\e[1;33m" && color_off="\e[0m"
function say () { echo -e "${color_on}$1${color_off}";}

# Function to prompt for a response.
function ask () { 
  echo -en "${color_on}$1${color_off}$2" && read response
}

# Create temporary directory to store files.
say "Creating Arch Linux installation medium."
mkdir arch_temp && cd arch_temp

# Download image and its GPG signature.
say "Downloading the latest Arch Linux image and its GPG signature."
if ! [ -x "$(command -v wget)" ]; then
  if ! [ -x "$(command -v curl)" ]; then
    say "ERROR: please install either 'wget' or 'curl' to be able to proceed."
    exit
  else
    curl --progress-bar \
      -O http://mirror.easyname.at/archlinux/iso/latest/archlinux-x86_64.iso.sig \
      -O http://mirror.easyname.at/archlinux/iso/latest/archlinux-x86_64.iso
  fi
else
  wget -q --show-progress \
    http://mirror.easyname.at/archlinux/iso/latest/archlinux-x86_64.iso.sig \
    http://mirror.easyname.at/archlinux/iso/latest/archlinux-x86_64.iso
fi

# Verify the signature.
say "Verifying image signature."
gpg --keyserver-options auto-key-retrieve --verify *.iso.sig *.iso
say "Output above should contain \"Good signature from ...\". \
Also, you need to compare the fingerprint with the official PGP \
fingerprint (from https://archlinux.org/download/)."
ask "Do you want to proceed [y/N]? "

if [[ $response =~ ^(yes|y|Y|YES|Yes)$ ]]; then
  # Scan hardware for storage devices.
  lsblk -ado PATH,SIZE
  ask "Choose the drive:" " /dev/" && disk="/dev/$response"
  ask "This will delete all the data on $disk. Do you agree [y/N]? "
  if [[ $response =~ ^(yes|y|Y|YES|Yes)$ ]]; then
    # Return "true", if umount throws "not mounted" error.
    say "Writing the image. Do not remove the drive."
    say "[Note that writing to disks requires superuser access.]"
    umount -q $disk?* || /bin/true && sudo wipefs --all $disk
    # Write image into USB disk.
    sudo dd bs=4M if=archlinux-x86_64.iso of=$disk \
      conv=fsync oflag=direct status=progress
    # Check that all data is transferred and remove the drive.
    sudo sync && sudo eject $disk
    say "USB installation medium successfully created."
  else
    say "Canceling operation."
  fi
else
  say "Canceling operation."
fi

# Remove temporary directory.
cd .. && rm -rf arch_temp
exit
