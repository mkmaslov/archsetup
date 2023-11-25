#!/bin/bash

set -e

# This script creates bootable USB drive using the latest Arch Linux image.

# Highlight the output.
YELLOW="\e[1;33m" && COLOR_OFF="\e[0m"
cprint() { echo -ne "${YELLOW}${1}${COLOR_OFF}"; }
msg() { cprint "${1}\n"; }

# Prompt for a response.
ask () { cprint "${1} " && echo -ne "$2" && read RESPONSE; }



# Create cache directory.
msg "Creating Arch Linux installation medium."
# Clear cache if exists.
rm -rf archinstall_cache &> /dev/null
mkdir archinstall_cache && cd archinstall_cache

# Download image and its GPG signature.
msg "Downloading the latest Arch Linux image and its GPG signature:"
if ! [ -x "$(command -v wget)" ]; then
  if ! [ -x "$(command -v curl)" ]; then
    msg "ERROR: please install either 'wget' or 'curl' to be able to proceed."
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
msg "\nVerifying image signature:"
gpg --keyserver-options auto-key-retrieve --verify *.iso.sig *.iso
msg "Output above should contain \"Good signature from ...\". \
Also, you need to compare the fingerprint with the official PGP \
fingerprint (from https://archlinux.org/download/)."
ask "Do you want to proceed [y/N]?"

if [[ $RESPONSE =~ ^(yes|y|Y|YES|Yes)$ ]]; then
  # Scan hardware for storage devices.
  msg "\nAvailable storage devices:"
  lsblk -ao PATH,SIZE,TYPE,MOUNTPOINTS
  ask "Choose the drive (with TYPE==disk):" "/dev/" && disk="/dev/$RESPONSE"
  ask "This will delete all the data on $disk. Do you agree [y/N]?"
  if [[ $RESPONSE =~ ^(yes|y|Y|YES|Yes)$ ]]; then
    # Return "true", if umount throws "not mounted" error.
    msg "\nWriting to disks requires superuser access:"
    umount -q $disk?* || /bin/true && sudo wipefs --all $disk
    # Write image into USB disk.
    msg "Writing the image. Do NOT remove the drive."
    sudo dd bs=4M if=archlinux-x86_64.iso of=$disk \
      conv=fsync oflag=direct status=progress
    # Check that all data is transferred and remove the drive.
    sudo sync && sudo eject $disk
    msg "Installation medium successfully created."
  else
    msg "Canceling operation."
  fi
else
  msg "Canceling operation."
fi

# Remove temporary directory.
cd .. && rm -rf archinstall_cache
exit