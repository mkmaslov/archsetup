#!/usr/bin/env -S bash -e

YELLOW="\e[1;33m"
WHITE="\e[0m"
# Highlight a message.
function say () { echo -e "${YELLOW}$1${WHITE}";}
# Prompt for a response.
function ask () { 
    echo -e -n "${YELLOW}$1" && read response && echo -e -n "${WHITE}"
}

say "Creating Arch Linux installation medium."
mkdir arch_temp && cd arch_temp
say "Downloading latest .iso and its GPG signature."
wget -q --show-progress \
    http://mirror.easyname.at/archlinux/iso/latest/archlinux-x86_64.iso.sig \
    http://mirror.easyname.at/archlinux/iso/latest/archlinux-x86_64.iso
say "Verifying image signature."
gpg --keyserver-options auto-key-retrieve \
    --verify archlinux-x86_64.iso.sig archlinux-x86_64.iso
say "The output above should contain the \"Good signature from ...\" line."
say "Also, you need to compare the fingerprint above with the official PGP \
fingerprint (from https://archlinux.org/download/)."
ask "Do you want to proceed [y/N]? "
if [[ $response =~ ^(yes|y)$ ]]; then
	lsblk -a -d -o PATH,SIZE
	ask "Choose the drive: /dev/"
    DISK="/dev/$response"
    ask "This will delete all the data on $DISK. Do you agree [y/N]? "
    if [[ $response =~ ^(yes|y)$ ]]; then
        for partition in $DISK?*; do umount -q "$partition"; done
        sudo dd bs=4M if=archlinux-x86_64.iso of="$DISK" conv=fsync oflag=direct status=progress
	    sync
        for partition in $DISK?*; do umount -q "$partition"; done
        say "USB installation medium successfully created."
    else
        say "Canceling operation."
    fi
else
    say "Canceling operation."
fi
cd ..
rm -rf arch_temp
exit
