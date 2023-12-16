# Arch Linux installation guide and shell scripts

This document provides detailed instructions for Arch Linux installation on x86-64 machine. The accompanying repository contains shell scripts (bash and zsh) that implement these instructions. The instructions were tested on several Lenovo Thinkpad laptops, [which provide great hardware support for Linux](https://www.lenovo.com/linux).

*References*: [guide](https://wiki.archlinux.org/title/User:Bai-Chiang/Installation_notes#Reboot_into_BIOS) by [Bai-Chiang](https://github.com/Bai-Chiang) and [guide](https://www.coded-with-love.com/blog/install-arch-linux-encrypted/) by [Florian Brinker](https://github.com/fbrinker).

*Disclaimer*: herewith author renounces the responsibility for any issues one may encounter following this guide. [Leave feedback here](https://github.com/mkmaslov/archlsetup/issues).

---
### Contents
* [Creating installation medium](#creating-installation-medium)
* [Installing Windows as part of dual-boot setup](#installing-windows-as-part-of-dual-boot-setup)
* [Verifying Secure Boot mode and UEFI mode](#verifying-secure-boot-mode-and-uefi-mode)
* [Activating network connection](#activating-network-connection)
* [Setting up time synchronization](#setting-up-time-synchronization)
* [Partitioning disks and configuring full-disk encryption](#partitioning-disks-and-configuring-full-disk-encryption)
* [Install packages and change root](#install-packages-and-change-root)
* [Configure the system](#configure-the-system)
* [Configure disk mapping](#configure-disk-mapping)
* [Creating Unified Kernel Image](#creating-unified-kernel-image)
* [Configure Secure Boot](#configure-secure-boot)
* [Add UEFI boot entries](#add-uefi-boot-entries)
* [Reboot into BIOS and enable Secure Boot](#reboot-into-bios-and-enable-secure-boot)
* [Recommended software](#recommended-software)


## Creating installation medium

*References*: [official Arch Linux installation guide](https://wiki.archlinux.org/title/Installation_guide) and [USB drive creation](https://wiki.archlinux.org/title/USB_flash_installation_medium).

List all connected storage devices using `sudo lsblk -d` and choose the drive that will be used as an installation medium (further `/dev/sdX`). Unmount all of the selected drive's partitions and wipe the filesystem:
```
for partition in /dev/sdX?*; do sudo umount -q $partition; done
sudo wipefs --all /dev/sdX
```
[Download](https://archlinux.org/download/) the latest Arch Linux image (`archlinux-x86_64.iso`) and its GnuPG signature (`archlinux-x86_64.iso.sig`). Put both files in the same folder and run a terminal instance there. Verify the signature:
```console
$ gpg --keyserver-options auto-key-retrieve --verify archlinux-x86_64.iso.sig archlinux-x86_64.iso
gpg: Signature made Thu 01 Dec 2022 17:40:26 CET
gpg:                using RSA key 4AA4767BBC9C4B1D18AE28B77F2D434B9741E8AC
gpg: Good signature from "Pierre Schmitz <pierre@archlinux.de>" [unknown]
gpg:                 aka "Pierre Schmitz <pierre@archlinux.org>" [unknown]
gpg: WARNING: This key is not certified with a trusted signature!
gpg:          There is no indication that the signature belongs to the owner.
Primary key fingerprint: 4AA4 767B BC9C 4B1D 18AE  28B7 7F2D 434B 9741 E8A
```
Make sure that the primary key fingerprint matches PGP fingerprint from the [downloads page](https://archlinux.org/download/). This is especially important, if the signature file was downloaded from one of the mirror sites.

After successfull image verification, write it to the selected drive:
```
sudo dd bs=4M if=archlinux-x86_64.iso of=/dev/sdX conv=fsync oflag=direct status=progress
sudo sync
```

To wipe the storage device after Arch Linux installation, the ISO 9660 filesystem signature needs to be removed:
```
sudo wipefs --all /dev/sdX
```

## Installing Windows as part of dual-boot setup

Windows needs to be installed before Linux. Follow these steps:
1. [Create Windows 11 installation medium (from Windows).](https://www.microsoft.com/en-us/software-download/windows11)
2. Download [autounattend.xml](https://raw.githubusercontent.com/mkmaslov/archsetup/main/resources/autounattend.xml). Edit the file to set the size of Windows partition.
2. Mount the installation medium and copy `autounattend.xml` to its root folder.
3. Boot from the medium and install Windows.

## Verifying Secure Boot mode and UEFI mode

**Enter BIOS**: during system boot activate certain key combination (e.g., `Fn+F2` on Lenovo laptops):
- navigate to the **Security** section
- **restore Factory Keys** (`PK,KEK,db and dbx`)
- set Secure Boot to **Setup Mode**
- **disable** Secure Boot

**Boot into installation medium**: during system boot activate certain key combination (e.g., `Fn+F12` on Lenovo laptops). 

When booted, choose US keyboard layout using `loadkeys us`. On HiDPI displays, one can use `setfont ter-132b` to make text more readable. Excessive notifications from audit framework can be disabled using `auditctl -e 0`. Verify Secure Boot status:
```console
$ bootctl status | grep "Secure Boot"
...
Secure Boot: disabled (setup)
...
```
Verify current [UEFI](https://wiki.archlinux.org/title/Unified_Extensible_Firmware_Interface) boot options:
```console
$ efibootmgr
BootCurrent: 0004
BootNext: 0003
BootOrder: 0004,0000,0001,0002,0003
Timeout: 30 seconds
Boot0000* Diskette Drive(device:0)
Boot0001* CD-ROM Drive(device:FF)
Boot0002* Hard Drive(Device:80)/HD(Part1,Sig00112233)
Boot0003* PXE Boot: MAC(00D0B7C15D91)
Boot0004* Linux
```
If necessary, remove the excessive options:
```
efibootmgr -b 0004 -B
```

Verify that the system is booted in UEFI mode. The following command should produce a non-empty output:
```
ls /sys/firmware/efi/efivars
```

## Activating network connection

Connect to Internet using a network cable or set up a Wi-Fi connection using [iwd](https://wiki.archlinux.org/title/Iwd) and [dhcpcd](https://wiki.archlinux.org/title/Dhcpcd):
```
iwctl station wlan0 connect <SSID>
dhcpcd wlan0
```
By default at boot, Arch Linux assigns the name `wlan0` to the Wi-Fi card.<br>
The following commands could be used to debug network connection:
```
ip link show                        # list all network devices
iwctl device list                   # list all Wi-Fi devices

rfkill list                         # list kill switch settings
rfkill unblock <DEVICE-NUM>         # unblock soft-blocked device

iwctl station <DEVICE-NAME> scan    # scan for Wi-Fi networks
ping archlinux.org                  # test Internet connection
```

## Setting up time synchronization

Automatic time synchronization is **vital** for the functional OS[^C1]. One can enable it using [systemd-timesyncd](https://wiki.archlinux.org/title/Systemd-timesyncd) daemon:
```
systemctl enable systemd-timesyncd.service
timedatectl set-ntp true
```

If set up correctly, one should obtain the following status message:
```console
$ timedatectl status
Local time: Thu 2015-07-09 18:21:33 CEST
           Universal time: Thu 2015-07-09 16:21:33 UTC
                 RTC time: Thu 2015-07-09 16:21:33
                Time zone: Europe/Amsterdam (CEST, +0200)
System clock synchronized: yes
              NTP service: active
          RTC in local TZ: no
```
If debugging is needed, one can request the information about current time server:
```console
$ timedatectl timesync-status
       Server: 103.47.76.177 (0.arch.pool.ntp.org)
Poll interval: 2min 8s (min: 32s; max 34min 8s)
         Leap: normal
      Version: 4
      Stratum: 2
    Reference: C342F10A
    Precision: 1us (-21)
Root distance: 231.856ms (max: 5s)
       Offset: -19.428ms
        Delay: 36.717ms
       Jitter: 7.343ms
 Packet count: 2
    Frequency: +267.747ppm
```
The configuration file containing addresses of time servers is stored in `/etc/systemd/timesyncd.conf`.

## Partitioning disks and configuring full-disk encryption

Use [gdisk](https://wiki.archlinux.org/title/GPT_fdisk) to create GPT partition table with two [partitions](https://wiki.archlinux.org/title/Partitioning): 
- `512 MiB` EFI-type partition for storing [Unified Kernel Image](#creating-unified-kernel-image)
- LVM-type partition for storing filesystem root and swap partitions

Execute:
```
sgdisk /dev/sdX -Zo -I -n 1:0:512M -t 1:ef00 -c 1:EFI -n 2:0:0 -t 2:8e00 -c 2:LVM
```


Load [dm-crypt](https://wiki.archlinux.org/title/Dm-crypt/Device_encryption) kernel module and benchmark available encryption algorithms:
```
modprobe dm-crypt && cryptsetup benchmark
```
On hardware that supports AES acceleration, `aes-xts-plain64` will be the fastest method. Create `luks2` container with `512 byte` key length:
```
cryptsetup luksFormat --cipher=aes-xts-plain64 --key-size=512 --verify-passphrase /dev/sdX2
```
Open the encrypted partition:
```
cryptsetup open /dev/sdX2 cryptroot
```
This will open `/dev/sdX2` to new disk device `/dev/mapper/cryptroot`.

Format and mount all partitions:
```
mkfs.ext4 /dev/mapper/cryptroot
mount /dev/mapper/cryptroot /mnt

mkfs.fat -F 32 /dev/sdX1
mkdir /mnt/efi
mount /dev/sdX1 /mnt/efi

mkswap /dev/sdX3
swapon /dev/sdX3
```

## Install packages and change root
```
pacstrap -K /mnt base base-devel linux linux-firmware man-db man-pages texinfo nano terminus-font
```
Additionally, one should consider installing the following packages:
- `intel-ucode` to acquire updated CPU microcode
- `sbctl` to create and enroll Secure Boot keys
- `efibootmgr` to create custom UEFI boot entries
- `wpa_supplicant` and `networkmanager` for Internet connectivity
- `alsa-firmware`, `sof-firmware` and `alsa-ucm-conf` to assure functionality of the soundcard
- minimal subset of packages from `gnome` group, `gnome-keyring`, `gnome-tweaks` and `gnome-bluetooth` to enable desktop environment

Change root into `/mnt` and enable newly installed services:
```
arch-chroot /mnt
export PS1="(chroot) ${PS1}"
systemctl enable systemd-resolved.service
systemctl enable NetworkManager.service
systemctl enable wpa_supplicant.service
systemctl enable gdm.service
```
Set up root password using `passwd`.

## Configure the system
Configure system clock[^C1]:
```
ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime
hwclock --systohc
timedatectl set-ntp true
```
Configure localization. Uncomment `en_IE.UTF-8 UTF-8` in `/etc/locale.gen`, then:
```
locale-gen
echo "LANG=en_IE.UTF-8" > /etc/locale.conf
echo "KEYMAP=us\nFONT=ter-132b" > /etc/vconsole.conf
``` 
Configure local network properties:
```console
$ echo <HOSTNAME> > /etc/hostname
$ nano /etc/hosts
127.0.0.1  localhost <HOSTNAME>
::1        localhost <HOSTNAME>
127.0.1.1  <HOSTNAME>.localdomain <HOSTNAME>
```
Add non-root user and set their password:
```
useradd -m <NAME>
passwd <NAME>
```
**TO-DO:** disable root login, add user to sudoers, enable Gnome auto login.

Configure `mkinitcpio`:
```console
$ nano /etc/mkinitcpio.conf
...
HOOKS=(base systemd keyboard autodetect modconf kms sd-vconsole block sd-encrypt filesystems fsck)
...
```
## Configure disk mapping
Configure `crypttab`:
```console
$ nano /etc/crypttab.initramfs
cryptroot  UUID=<ROOT-UUID>  -  password-echo=no,x-systemd.device-timeout=0,timeout=0,no-read-workqueue,no-write-workqueue,discard
```
Use `lsblk -f` to determine `<ROOT-UUID>`, options `no-read-workqueue,no-write-workqueue,discard` increase SSD performance.

Set up swap encryption. First, deactivate swap partition:
```
swapoff /dev/sdX3
```
Create `1M` sized `ext2` filesystem with label `cryptswap`:
```
mkfs.ext2 -F -F -L cryptswap /dev/sdX3 1M
```
Edit `/etc/crypttab`:
```console
$ nano /etc/crypttab
#  <name>     <device>          <password>    <options>
   cryptswap  UUID=<SWAP-UUID>  /dev/urandom  swap,offset=2048
```
Use `lsblk -f` to determine `<SWAP-UUID>`, option `offset` is the offset from the partition's first sector in 512-byte sectors (`1MiB=2048*512B`).

Configure `/etc/fstab`:
```console
$ nano /etc/fstab
#  <filesystem>           <dir>  <type>  <options>  <dump>  <pass>
   /dev/sdX1              /efi   vfat    defaults,ssd   0   0
   /dev/mapper/cryptroot  /      ext4    defaults,ssd   0   0
   /dev/mapper/cryptswap  none   swap    defaults       0   0
```

## Creating Unified Kernel Image

Create `/etc/kernel/cmdline` and `/etc/kernel/cmdline_fallback`:
```console
$ nano /etc/kernel/cmdline
root=/dev/mapper/cryptroot rw i8042.direct i8042.dumbkbd
$ nano /etc/kernel cmdline_fallback
root=/dev/mapper/cryptroot rw i8042.direct i8042.dumbkbd
```
Kernel parameters `i8042.direct` and `i8042.dumbkbd` are required to enable built-in keyboard on Lenovo Yoga Pro X. After successfull installation, one can also include kernel parameter `quiet` to suppress debug messages at boot.

Modify `/etc/mkinitcpio.d/linux.preset`:
```console
# mkinitcpio preset file for the 'linux' package

ALL_config="/etc/mkinitcpio.conf"
ALL_kver="/boot/vmlinuz-linux"
ALL_microcode=(/boot/*-ucode.img)

PRESETS=('default' 'fallback')

#default_config="/etc/mkinitcpio.conf"
#default_image="/boot/initramfs-linux.img"
default_options=""
default_uki="/efi/EFI/Linux/Archlinux-linux.efi"

#fallback_config="/etc/mkinitcpio.conf"
#fallback_image="/boot/initramfs-linux-fallback.img"
fallback_options="-S autodetect --cmdline /etc/kernel/cmdline_fallback"
fallback_uki="/efi/EFI/Linux/Archlinux-linux-fallback.efi"
```
Create `/efi/EFI/Linux` folder and regenerate `initramfs`:
```
mkdir /efi && mkdir /efi/EFI && mkdir /efi/EFI/Linux && mkinitcpio -P
```
Finally, remove any leftover `initramfs-*.img` from `/boot` or `/efi`. 

## Configure Secure Boot

Create keys:
```
sbctl create-keys
```
Enroll keys (sometimes `--microsoft` option is needed):
```
sbctl enroll-keys
```
Sign both unified kernel images:
```
sbctl sign --save /efi/EFI/Linux/ArchLinux-linux.efi
sbctl sign --save /efi/EFI/Linux/ArchLinux-linux-fallback.efi
```

## Add UEFI boot entries

```
efibootmgr --create --disk /dev/sdX --part 1 --label "ArchLinux-linux" --loader "EFI\\Linux\\ArchLinux-linux.efi"
efibootmgr --create --disk /dev/sdX --part 1 --label "ArchLinux-linux-fallback" --loader "EFI\\Linux\\ArchLinux-linux-fallback.efi"
```
Option `--disk` denotes the physical disk containing boot loader (`/dev/sdX` not `/dev/sdX1`), option `--part` specifies the partition number (`1` for `/dev/sdX1`). 

Display current boot options. Change boto order, if necessary:
```console
$ efibootmgr
BootCurrent: 0004
BootNext: 0003
BootOrder: 0004,0000,0001,0002,0003
Timeout: 30 seconds
Boot0000* Diskette Drive(device:0)
Boot0001* CD-ROM Drive(device:FF)
Boot0002* Hard Drive(Device:80)/HD(Part1,Sig00112233)
Boot0003* PXE Boot: MAC(00D0B7C15D91)
Boot0004* Linux
Boot0005* Linux
$ efibootmgr --bootorder 0003,0004,0005
```

## Reboot into BIOS and enable Secure Boot
```console
umount -R /mnt
systemctl reboot --firmware-setup
```

## Software

- [firefox](https://archlinux.org/packages/extra/x86_64/firefox/) -- FOSS non-Chromium based browser. The default settings are not security/privacy-friendly. One needs to set up the following:
   * go through settings, opt out of telemetry, set permissions
   * install BitWarden and uBlock Origin extensions

- **Mozilla Firefox**
  * set up privacy-friendly settings
  * instal Bitwarden and uBlock Origin extensions
  * enable most of the filter lists, install Legitimate URLs list
  * Additional reading: [1](https://www.reddit.com/r/privacy/comments/d3obxq/firefox_privacy_guide/), [2](https://www.reddit.com/r/privacytoolsIO/comments/ldrhso/firefox_privacy_extensions/gm8g1x2/?context=3), [3](https://anonyome.com/2020/04/why-compartmentalization-is-the-most-powerful-data-privacy-strategy/) and [4](https://github.com/arkenfox/user.js/wiki/4.1-Extensions)
  
- [torbrowser-launcher](https://archlinux.org/packages/extra/any/torbrowser-launcher/) -- Internet browser for anonymous Internet surfing. Do **not** change default settings to avoid fingerprinting.

- [transmission-gtk](https://archlinux.org/packages/extra/x86_64/transmission-gtk/) -- Bittorrent client. Use GTK version for better GNOME compatibility.

- [vscodium-bin](https://aur.archlinux.org/packages/vscodium-bin) -- Code editor. FOSS version of VS Code without Microsoft telemetry.
  * custom settings.json
  * Latex workshop extension
  * Jupyter extension
  * Code Runner extension
  * Wolfram language extension
- [zoom](https://aur.archlinux.org/packages/zoom) -- **proprietary** video conferencing.<br>
(to enable screen sharing: `Settings -> Share Screen -> Advanced -> PipeWire Mode`)

 
## Setting up backup storage

Set up a luks-encrypted external drive at `<DISK-PATH>` (like `/dev/sda`):
```
sgdisk <DISK-PATH> -Zo -I -n 1:0:0 -t 1:8300 -c 1:CRBK
cryptsetup luksFormat --cipher=aes-xts-plain64 --key-size=512 --verify-passphrase <DISK-PATH>
cryptsetup open <DISK-PATH> cryptbackup
mkfs.ext4 /dev/mapper/cryptbackup
cryptsetup close cryptbackup
```

Use `lsblk -f` to determine `<DISK-UUID>` of `<DISK-PATH>`, then add an entry to `/etc/crypttab`:
```console
$ nano /etc/crypttab
#  <name>         <device>          <password>    <options>
   cryptbackup    UUID=<DISK-UUID>  none          luks,noauto
```
Create target folder to mount backup storage in your `<USER>`'s folder:
```
sudo mkdir /run/media/<USER>/cryptbackup
sudo chown <USER> /run/media/<USER>/cryptbackup
sudo chmod 777 /run/media/<USER>/cryptbackup
```
Add an entry to `/etc/fstab`:
```console
$ nano /etc/fstab
#  <filesystem>               <dir>                           <type>  <options>  <dump>  <pass>
   /dev/mapper/cryptbackup    /run/media/<USER>/cryptbackup   ext4    rw,noauto  0       0
```

To synchronize folders, use `rsync`:
```
rsync -a --delete --progress /source/path/ /target/path
```


## Comments
[^C1]: Without a properly synchronized clock many essential tools won't work. For instance, `pacman -Syu` will fail due to time inconsistencies in GPG signatures (*"GPG key from the future"* error), which may subsequently lead to a non-bootable system if `pacman` fails to regenerate `initramfs`.
