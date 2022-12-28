#!/bin/bash
RED="\033[1;31m"
GREEN="\033[1;32m"
BLUE="\033[1;34m"
WHITE="\033[0m"
message(){ echo -e "${BLUE}$1${WHITE}"; }
warning(){ echo -e "${RED}$1${WHITE}"; }
success(){ echo -e "${GREEN}$1${WHITE}"; }
question(){ echo -e -n "${BLUE}$1${GREEN}"; read answer; echo -e -n "${WHITE}"; }
message "This script creates Arch Linux installation medium"
warning "WARNING: to avoid permission conflicts, this script uses sudo"
sudo echo -n ""
sudo mkdir create_USB_temp
cd create_USB_temp
message "Downloading latest Arch Linux image and its GnuPG signature"
sudo wget http://mirror.easyname.at/archlinux/iso/latest/archlinux-x86_64.iso.sig
sudo wget http://mirror.easyname.at/archlinux/iso/latest/archlinux-x86_64.iso
message "Verifying image signature"
gpg --keyserver-options auto-key-retrieve --verify archlinux-x86_64.iso.sig archlinux-x86_64.iso
message "The output above should contain \"Good signature from ...\" line."
message "Additionally, you need to compare the fingerprint above with the official PGP fingerprint (from https://archlinux.org/download/)."
question "Do you want to proceed? [y/n]: "
if [ $answer == "y" ]; then
	message "List of connected storage devices"
	sudo lsblk -a -d -o PATH,SIZE
	warning "WARNING: the chosen drive will be erased!"
	question "Choose drive [PATH]: "
	message "Creating installation medium on ${answer}"
	for partition in $answer?*; do sudo umount -q $partition; done
	sudo wipefs --all $answer
	sudo dd bs=4M if=archlinux-x86_64.iso of=$answer conv=fsync oflag=direct status=progress
	sudo sync
	success "Installation medium successfully created"
else
	warning "Creation procedure failed"
fi
cd ..
sudo rm -rf create_USB_temp

