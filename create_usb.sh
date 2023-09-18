#!/bin/bash
# Create bootable USB drive using the latest Arch Linux ISO.
set -e

# Highlight a message.
color_on="\e[1;33m" && color_off="\e[0m"
function say () { echo -e "${color_on}$1${color_off}";}

# Prompt for a response.
function ask () { 
  echo -en "${color_on}$1" && read response && echo -en "${color_off}"
}

say "Creating Arch Linux installation medium."
mkdir arch_temp && cd arch_temp
say "Downloading latest .iso and its GPG signature."
wget -q --show-progress \
  http://mirror.easyname.at/archlinux/iso/latest/archlinux-x86_64.iso.sig \
  http://mirror.easyname.at/archlinux/iso/latest/archlinux-x86_64.iso
# curl --progress-bar \
#  -O http://mirror.easyname.at/archlinux/iso/latest/archlinux-x86_64.iso.sig \
#  -O http://mirror.easyname.at/archlinux/iso/latest/archlinux-x86_64.iso
say "Verifying image signature."
gpg --keyserver-options auto-key-retrieve --verify *.iso.sig *.iso
say "Output above should contain \"Good signature from ...\". \
Also, you need to compare the fingerprint with the official PGP \
fingerprint (from https://archlinux.org/download/)."
ask "Do you want to proceed [y/N]? "
if [[ $response =~ ^(yes|y|Y|YES|Yes)$ ]]; then
  lsblk -ado PATH,SIZE
  ask "Choose the drive: /dev/" && disk="/dev/$response"
  ask "This will delete all the data on $disk. Do you agree [y/N]? "
  if [[ $response =~ ^(yes|y|Y|YES|Yes)$ ]]; then
    # Return "true", if umount throws "not mounted" error
    umount -q $disk?* || /bin/true && sudo wipefs --all $disk
    say "Writing the image. Do not remove the drive."
    sudo dd bs=4M if=archlinux-x86_64.iso of=$disk \
      conv=fsync oflag=direct status=progress
    sudo sync && sudo eject $disk
    say "USB installation medium successfully created."
  else
    say "Canceling operation."
  fi
else
  say "Canceling operation."
fi
cd .. && rm -rf arch_temp
exit
