#!/bin/bash

set -e

# -----------------------------------------------------------------------------
# This script creates a bootable USB drive using the latest Arch Linux image.
# -----------------------------------------------------------------------------

# Output formatting.

# Highlight the output.
YELLOW="\e[1;33m" ; RED="\e[1;31m" ; COLOR_OFF="\e[0m"
cprint() { echo -ne "${1}${2}${COLOR_OFF}" ; }
msg() { cprint "${YELLOW}" "${1}\n" ; }
error() { cprint "${RED}" "ERROR: ${1}\n" ; }

# Prompt for a response.
ask () { cprint "${YELLOW}" "${1} " ; echo -ne "${2}" ; read RESPONSE ; }

# -----------------------------------------------------------------------------
# Downloading and verifying image.
# -----------------------------------------------------------------------------

msg "Creating Arch Linux USB installation medium."

# Clear cache directory if it exists.
rm -rf archinstall_cache &> /dev/null
# Create cache directory.
mkdir archinstall_cache && cd archinstall_cache

# Download Arch Linux image and its GPG signature.
msg "Downloading the latest Arch Linux image and its GPG signature:"
# kurl() function copied from: https://stackoverflow.com/a/66504482
kurl(){ F=${1##*/} ; printf "%32s[%s]" "" "${F}" ; COLUMNS=28 curl -# ${1} -o ${F} ; }
# Check whether wget or curl are available, if not - return error.
download() {
  if [ -x "$(command -v wget)" ]; then
    wget -q --show-progress "${1}" "${2}"
  elif [ -x "$(command -v curl)" ]; then
    kurl "${1}" && kurl "${2}"
  else
    error "please install either \"wget\" or \"curl\" to proceed."
    exit
  fi
}
# Using download mirror for Austria.
# Mirrors for other countries: https://archlinux.org/download/
IMAGE="http://mirror.easyname.at/archlinux/iso/latest/archlinux-x86_64.iso"
download "${IMAGE}.sig" "${IMAGE}"

# Verify image signature.
msg "Verifying image signature:"
gpg --keyserver-options auto-key-retrieve --verify *.iso.sig *.iso
msg "Output above should contain \"Good signature from ...\" line."
msg "The above fingerprint should match this fingerprint:"
msg "(from https://archlinux.org/download/)"
PGPKEY=$(curl --silent https://archlinux.org/download/ | \
  grep -o "title=\"PGP key search.*\"" | cut -d " " -f 5-14)
echo "Primary key fingerprint: ${PGPKEY::-1}"
ask "Do you confirm that the GPG signature is correct [y/N]?"

# -----------------------------------------------------------------------------
# Writing image to disk.
# -----------------------------------------------------------------------------

if [[ $RESPONSE =~ ^(yes|y|Y|YES|Yes)$ ]]; then
  # Scan hardware for storage devices.
  msg "Available storage devices:"
  lsblk -ao PATH,SIZE,TYPE | grep -E "TYPE|disk"
  ask "Select the USB drive:" "/dev/" && DISK="/dev/$RESPONSE"
  ask "Proceeding will erase all data on ${DISK}. Do you agree [y/N]?"
  if [[ $RESPONSE =~ ^(yes|y|Y|YES|Yes)$ ]]; then
    msg "Writing to drives requires superuser access:"
    # Return "true", if umount throws "not mounted" error.
    umount -q ${DISK}?* || /bin/true && sudo wipefs --all ${DISK} > /dev/null
    # Write image into USB disk.
    msg "Writing Arch Linux image to the USB drive. Do NOT remove the drive."
    sudo dd bs=4M if=archlinux-x86_64.iso \
      of=${DISK} conv=fsync oflag=direct status=progress
    # Check that all data is transferred and eject the drive.
    sudo sync && sudo eject ${DISK}
    msg "USB installation medium created. You can remove the USB drive."
  else
    msg "Canceling operation."
  fi
else
  msg "Canceling operation."
fi

# Remove cache directory.
cd .. && rm -rf archinstall_cache && exit

# -----------------------------------------------------------------------------