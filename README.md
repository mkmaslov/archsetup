# Arch Linux installation guide

This document provides detailed instructions for Arch Linux installation. It covers the following use cases:
- a machine with AArch64 architecture used as a *server* (headless node with Docker containers)
- a machine with x86-64 architecture used as a *personal computer* (desktop environment, internet browser, etc)


The contents are organised as follows: 

- [Installing Arch Linux ARM on a server](#installing-arch-linux-arm-on-a-server)
  * [Maintenance USB drive](#maintenance-usb-drive)
    + [RaspberryPi OS CLI Setup](#raspberrypi-os-cli-setup)
  * [Partitioning storage device and configuring full-disk non-AES encryption](#partitioning-storage-device-and-configuring-full-disk-non-aes-encryption)
  * [Performing initial server setup and installing basic software](#performing-initial-server-setup-and-installing-basic-software)
    + [Fixing U-Boot bootloader](#fixing-u-boot-bootloader)
    + [Replacing U-Boot bootloader](#replacing-u-boot-bootloader)
    + [CLI configuration of Wi-Fi connection](#cli-configuration-of-wi-fi-connection)
    + [Setting up time synchronization](#setting-up-time-synchronization)
    + [Configuring package managers](#configuring-package-managers)
    + [Additional configuration and post-install](#additional-configuration-and-post-install)

- [Instal Arch Linux on x64 machine](#instal-arch-linux-on-x64-machine)
  * [Create installation medium](#create-installation-medium)
  * [Check Secure Boot mode and UEFI mode](#check-secure-boot-mode-and-uefi-mode)
  * [Activate network connection](#activate-network-connection)
  * [Partition disks and configure full-disk encryption](#partition-disks-and-configure-full-disk-encryption)
  * [Install packages and change root](#install-packages-and-change-root)
  * [Configure the system](#configure-the-system)
  * [Configure disk mapping](#configure-disk-mapping)
  * [Create Unified Kernel Image](#create-unified-kernel-image)
  * [Configure Secure Boot](#configure-secure-boot)
  * [Add UEFI boot entries](#add-uefi-boot-entries)
  * [Reboot into BIOS and enable Secure Boot](#reboot-into-bios-and-enable-secure-boot)
  
- [Recommended software](#recommended-software)
  * [Personal computer](#personal-computer)
  * [Server](#server)
  
 **DISCLAIMER:** author does not take responsibility for the problems that you may face while following this guide. In case you notice an error, have a suggestion or feel that a certain statement is unclear, you could provide feedback [here](https://github.com/mkmaslov/archlinux_setup_guide/issues). This guide does not contain any novel information, instead it represents a structured compilation of advice and tricks from Internet as well as some personal knowledge. Where possible, a reference to the original material or additional information is provided.
 
# Installing Arch Linux ARM on a server

This section covers installation of [Arch Linux ARM operating system](https://archlinuxarm.org/) on [Raspberry Pi 4 Model B](https://www.raspberrypi.com/products/raspberry-pi-4-model-b/specifications/) **with [C0 stepping](https://www.jeffgeerling.com/blog/2021/raspberry-pi-4-model-bs-arriving-newer-c0-stepping)**.

*References:*
- [Arch Linux ARM64](https://archlinuxarm.org/forum/viewtopic.php?f=65&t=15994)
- [Arch Linux ARM Encryption](https://gist.github.com/XSystem252/d274cd0af836a72ff42d590d59647928)
- [Arch Linux Encryption](https://www.coded-with-love.com/blog/install-arch-linux-encrypted/)
- [Linux hardening](https://www.pluralsight.com/blog/it-ops/linux-hardening-secure-server-checklist)

## Maintenance USB drive

### RaspberryPi OS CLI Setup
To set up larger font size in console:
```
sudo dpkg-reconfigure console-setup
```

## Partitioning storage device and configuring full-disk non-AES encryption
```
sudo fdisk /dev/sda
o (new partition table)
n (new partition)
+512M
t (type)
c (FAT32)
n (new partition)
t (type)
8e (Linux LVM)
w (write changes)
```
Host system needs to have `lvm2` enabled.
```
>> sudo mkfs.vfat /dev/sda1
>> modprobe dm-crypt
>> cryptsetup luksFormat -c xchacha12,aes-adiantum-plain64 /dev/sda2
>> cryptsetup open --type luks /dev/sda2 lvm
>>  pvcreate /dev/mapper/lvm
>>  vgcreate main /dev/mapper/lvm
>>  lvcreate -L10G main -n swap
>>  lvcreate -l 100%FREE main -n root
>>  mkswap /dev/mapper/main-swap
>>  mkfs.ext4 /dev/mapper/main-root
>>  mount /dev/sda1 boot
>>  mount /dev/mapper/main-root root
```

```
>>  bsdtar -xpf <arch_linux_ARM_installer>.tar.gz -C root
>>  sync
>>  mv root/boot/* boot
>>  sync
>>  umount boot root
>>  vgchange -a n main [to close lvm]
>>  cryptsetup close lvm [to lock luks]
```

## Performing initial server setup and installing basic software

### Fixing U-Boot bootloader

*References*: [how to fix U-Boot in Arch Linux ARM on RPi4b with C0 stepping](https://archlinuxarm.org/forum/viewtopic.php?f=67&t=15422&start=20#p67299).

C0 stepping [breaks some bootloaders](https://raspberrypi.stackexchange.com/questions/119356/differences-between-b0-and-c0-steppings-of-the-bcm2711).

At the moment of writing, the default boot manager in Arch Linux ARM (U-Boot) is outdated. Out-of-the-box it does not support C0 stepping of Broadcom BCM2711. Thus said, if just following the [AArch64 installation instructions](https://archlinuxarm.org/platforms/armv8/broadcom/raspberry-pi-4) the system won't boot. Fixing U-Boot requires an external Linux machine.

First, one needs to change all instances of `fdt_addr_r` to `fdt_addr` in `boot/boot.txt`.
Secondly, one needs to install `uboot-tools` and recompile the boot script (`boot/boot.scr`):
```
cd boot
mkimage -A arm -T script -O linux -d boot.txt boot.scr
```

### Replacing U-Boot bootloader

On Debian hosts:
```
sudo apt-get install systemd-container
systemd-nspawn --bind-ro=/etc/resolv.conf --bind=/home/<user>/boot:/boot -D root -M archroot
```

```
pacman -S --needed linux-rpi raspberrypi-bootloader raspberrypi-firmware
```


### Setting up correct fstab

Finally, one needs to use correct `/etc/fstab`:
```console
$ cat /etc/fstab

# Static information about the filesystems.
# See fstab(5) for details.

# <file system>  <dir>  <type>  <options>  <dump>  <pass>
/dev/sda1        /boot  vfat    defaults   0       0
/dev/sda2        /      ext4    defaults   0       0
```

### CLI configuration of Wi-Fi connection
Requires packages: `wpa_supplicant`, `dhcpcd`.
* * * 
List all network interfaces:
```bash
ip a
```
Set the state of a chosen interface `<interface>` to `up`:
```bash
ip link set <interface> up
```
Scan `<interface>` for available Wi-Fi networks:
```bash
iwlist <interface> scan | grep ESSID
```
Connect to a chosen network `<ESSID>` with password `<password>`:
```bash
wpa_passphrase <ESSID> <password> | tee /etc/wpa_supplicant.conf
```
By default `wpa_passphrase` saves `<password>` in plain text. Open `/etc/wpa_supplicant.conf` using: 
```bash
nano /etc/wpa_supplicant.conf
```
and remove the line `#psk="<password>"`.

Activate `wpa_supplicant` on the interface `<interface>`:
```bash
wpa_supplicant -c /etc/wpa_supplicant.conf -i <interface> -B
```
Argument `-B` makes the daemon run in the background.

Activate `dhcpcd` on the interface `<interface>`:
```bash
dhcpcd <interface>
``` 

* * * 
To automatically connect to Wi-Fi at boot, configure `dhcpcd@<interface>` daemon with `10-wpa_supplicant` hook.

Add `ctrl_interface=DIR=/var/run/wpa_supplicant` at the very beginning of `/etc/wpa_supplicant.conf`:
```bash
nano /etc/wpa_supplicant.conf
```
Add `env wpa_supplicant_conf=/etc/wpa_supplicant.conf` line to `/etc/dhcpcd.conf`:
```bash
nano /etc/dhcpcd.conf
```
Create a symbolic link, which ensures that the latest version of `10-wpa_supplicant` hook is used:
```bash
ln -s /usr/share/dhcpcd/hooks/10-wpa_supplicant /usr/lib/dhcpcd/dhcpcd-hooks/
```
Enable `systemctl` daemon:
```bash
systemctl enable dhcpcd@<interface>.service
```
* * * 
**Disclaimer:** this guide was written for the ease-of-access purposes only. 

All the information is taken from: [wpa_supplicant (ArchWiki)](https://wiki.archlinux.org/title/Wpa_supplicant) and [dhcpcd (ArchWiki)](https://wiki.archlinux.org/title/Dhcpcd).


### Setting up time synchronization

The very first thing that needs to be set up after the network is functioning is [time synchronization](https://wiki.archlinux.org/title/Systemd-timesyncd)[^C1]. 

In Arch Linux ARM, by default, `systemd-networkd.service` is enabled, while this guide suggests using `wpa_supplicant.service` and `dhcpcd.service`. When both of these options are enabled, `systemd-timesyncd.service` fails to update the clock at boot. Therefore, if following this guide, make sure to disable the `systemd-networkd.service`:
```
systemctl disable systemd-networkd.service
```

Automatic time-synchronization via `systemd-timesyncd.service` can be enabled by running:
```
systemctl enable systemd-timesyncd.service
timedatectl set-ntp true
```
The configuration file containing addresses of time servers is stored in `/etc/systemd/timesyncd.conf`.

If set up correctly, one should see:
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
For the information about current time server that may be relevant for debugging:
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

### Basic configuration
```console
$ nano /etc/locale.gen
en_US.UTF-8 UTF-8
$ locale-gen
$ ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime
$ nano /etc/locale.conf
LANG=en_US.UTF-8
$ nano /etc/vconsole.conf
KEYMAP=en
FONT=ter-132b
```


### Configuring package managers

*References*: [official Arch Linux ARM installation guide](https://archlinuxarm.org/platforms/armv8/broadcom/raspberry-pi-4)

Automatic choice of pacman mirrors based on geolocation does not work, so one needs to edit `/etc/pacman.d/mirrorlist` and uncomment the desired mirror, i.e.:
```console
$ nano /etc/pacman.d/mirrorlist
# Server = http://mirror...
Server = http://eu.mirror...
```

```
pacman-key --init
pacman-key --populate archlinuxarm
pacman -Syu
```

### Additional configuration and post-install
```
pacman -S lvm2 terminus-font
setfont ter-132b
```


    
# Instal Arch Linux on x64 machine

*References:* [guide](https://wiki.archlinux.org/title/User:Bai-Chiang/Installation_notes#Reboot_into_BIOS) by [Bai-Chiang](https://github.com/Bai-Chiang) and [guide](https://www.coded-with-love.com/blog/install-arch-linux-encrypted/) by [Florian Brinker](https://github.com/fbrinker).

The instructions below were tested on several Lenovo Thinkpad laptops, [which usually offer great hardware support in Linux](https://www.lenovo.com/linux), and on Lenovo Yoga Pro X (Intel version), which required some tinkering.

## Create installation medium

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

The aforementioned instructions are also available in the form of [**a shell script**](https://github.com/mkmaslov/archlinux_setup_guide/blob/main/create_USB.sh).

To wipe the storage device after Arch Linux installation, the ISO 9660 filesystem signature needs to be removed:
```
sudo wipefs --all /dev/sdX
```

## Check Secure Boot mode and UEFI mode

Enter BIOS (`Fn+F2` key combination on Lenovo laptops), navigate to the `Security` section, restore Factory Keys (PK,KEK,db and dbx), reset Secure Boot to `Setup Mode` and disable Secure Boot. Boot into Live ISO (`Fn+F12` key combination on Lenovo laptops), select keyboard layout and font (use `ter-132b` for HiDPI displays):
```
loadkeys us && setfont ter-132b
```
Then, verify Secure Boot status:
```console
$ bootctl status | grep "Secure Boot"
...
Secure Boot: disabled (setup)
...
```
Verify current boot options:
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
and remove unused options if necessary:
```
efibootmgr -b 0004 -B
```

Verify that the system is booted in UEFI mode. Output of:
```
ls /sys/firmware/efi/efivars
```
should be non-empty.

## Activate network connection

Either connect via network cable or connect using `iwctl`:
```
iwctl
device list
station wlan0 connect <YOUR-SSID>
dhcpcd wlan0
ping archlinux.org
```
Synchronize system clock[^C1]:
```
timedatectl set-ntp true
```

## Partition disks and configure full-disk encryption

Use `gdisk` to create GPT partition table with two partitions -- EFI-type boot partition and LVM-type root partition:
```console
$ lsblk
NAME            MAJ:MIN RM   SIZE RO TYPE  MOUNTPOINTS 
sdX      8:16   1 119.5G  0 disk
$ gdisk /dev/sdX
GPT fdisk (gdisk) version 1.0.9.1

Partition table scan:
  MBR: protective
  BSD: not present
  APM: not present
  GPT: present

Found valid GPT with protective MBR; using GPT.

Command (? for help): o
This option deletes all partitions and creates a new protective MBR.
Proceed? (Y/N): Y

Command (? for help): n
Partition number (1-128, default 1): 
First sector (34-62668766, default = 2048) or {+-}size{KMGTP}: 
Last sector (2048-62668766, default = 62666751) or {+-}size{KMGTP}: +512M
Current type is 8300 (Linux filesystem)
Hex code or GUID (L to show codes, Enter = 8300): ef00
Changed type of partition to 'EFI system partition'

Command (? for help): n
Partition number (2-128, default 2): 
First sector (34-62668766, default = 1050624) or {+-}size{KMGTP}: 
Last sector (1050624-62668766, default = 62666751) or {+-}size{KMGTP}: -18G
Current type is 8300 (Linux filesystem)
Hex code or GUID (L to show codes, Enter = 8300):
Changed type of partition to 'Linux filesystem'

Command (? for help): n
Partition number (3-128, default 3): 
First sector (34-62668766, default = 24920064) or {+-}size{KMGTP}: 
Last sector (24920064-62668766, default = 62666751) or {+-}size{KMGTP}: 
Current type is 8300 (Linux filesystem)
Hex code or GUID (L to show codes, Enter = 8300): 8200
Changed type of partition to 'Linux swap'

Command (? for help): p
Disk /dev/sdX: 62668800 sectors, 29.9 GiB
Model: Flash Drive     
Sector size (logical/physical): 512/512 bytes
Disk identifier (GUID): B021BC12-F035-4191-A7AA-02E8C2085556
Partition table holds up to 128 entries
Main partition table begins at sector 2 and ends at sector 33
First usable sector is 34, last usable sector is 62668766
Partitions will be aligned on 2048-sector boundaries
Total free space is 4062 sectors (2.0 MiB)

Number  Start (sector)    End (sector)  Size       Code  Name
   1            2048         1050623   512.0 MiB   EF00  EFI system partition
   2         1050624        24920030   11.4 GiB    8300  Linux filesystem
   3        24920064        62666751   18.0 GiB    8200  Linux swap

Command (? for help): w

Final checks complete. About to write GPT data. THIS WILL OVERWRITE EXISTING
PARTITIONS!!

Do you want to proceed? (Y/N): Y
OK; writing new GUID partition table (GPT) to /dev/sdX.
Warning: The kernel is still using the old partition table.
The new table will be used at the next reboot or after you
run partprobe(8) or kpartx(8)
The operation has completed successfully.
```
Load `dm-crypt` kernel module and benchmark encryption algorithms:
```
modprobe dm-crypt && cryptsetup benchmark
```
Usually, `aes-xts-plain64` will be the fastest method (on hardware that supports AES accelaration). Set `4096 bytes` as sector size (if using NVMe), `512 byte` key length and encrypt the second partition:
```
cryptsetup luksFormat --cipher=aes-xts-plain64 --keysize=512 --sector-size 4096 --verify-passphrase --verbose /dev/sdX2
```
Now, open the partition:
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
cryptroot  UUID=<ROOT-UUID>  -  password-echo=no,no-read-workqueue,no-write-workqueue,discard
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

## Create Unified Kernel Image

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
mkdir /efi/EFI/Linux && mkinitcpio -P
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

# Recommended software

## Personal computer

- **Mozilla Firefox**
  * set up privacy-friendly settings
  * instal Bitwarden and uBlock Origin extensions
  * enable most of the filter lists, install Legitimate URLs list
  * Additional reading: [1](https://www.reddit.com/r/privacy/comments/d3obxq/firefox_privacy_guide/), [2](https://www.reddit.com/r/privacytoolsIO/comments/ldrhso/firefox_privacy_extensions/gm8g1x2/?context=3), [3](https://anonyome.com/2020/04/why-compartmentalization-is-the-most-powerful-data-privacy-strategy/) and [4](https://github.com/arkenfox/user.js/wiki/4.1-Extensions)
  
- **Tor Browser** -- for anonymous Internet surfing

- **Proton VPN** -- Linux application, Open VPN profile leaks IPv6 address

- **qBitTorrent**

- **VSCodium**
  * custom settings.json
  * Latex workshop extension
  * Jupyter extension
  * Code Runner extension
  * Wolfram language extension

## Server
- **Seafile** is end-to-end encrypted open source file synchronization service.
 See [server manual](https://manual.seafile.com/deploy/) and [download for ARM](https://github.com/haiwen/seafile-rpi/releases).
 - **EteBase** is end-to-end encrypted open source contact and calendar service. See [GitHub page](https://github.com/etesync/server).
 - **Standard notes** is end-to-end encrypted open source note taking service. See [self-hosting guide](https://docs.standardnotes.com/self-hosting/docker).
 - **Bitwarden**
 - **Navidrome**
 - **PiHole**
 - [Other options](https://github.com/pluja/awesome-privacy)
 

# Comments
[^C1]: Without a properly synchronized clock many essential tools won't work. For instance, `pacman -Syu` will fail due to time inconsistencies in GPG signatures (*"GPG key from the future"* error), which may subsequently lead to a non-bootable system if `pacman` fails to regenerate `initramfs`.
