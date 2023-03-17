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

- [Installing Arch Linux on x64 machine](#installing-arch-linux-on-x64-machine)
  * [Creating installation medium](#creating-installation-medium)
  * [Partitioning hard drive and configuring full-disk AES encryption](#partitioning-hard-drive-and-configuring-full-disk-aes-encryption)
  * [Performing initial PC setup and installing basic software](#performing-initial-pc-setup-and-installing-basic-software)
  
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

The very first thing that needs to be set up after the network is functioning is [time synchronization](https://wiki.archlinux.org/title/Systemd-timesyncd). Without a properly synchronized clock many essential tools may not work. For instance, `pacman -Syu` may fail due to time inconsistencies in GPG signatures, which may subsequently lead to a non-bootable setup[^C1].

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


    
# Installing Arch Linux on x64 machine

The instructions below were tested on several Lenovo Thinkpad laptops, [which usually offer great hardware support in Linux](https://www.lenovo.com/linux).

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

The aforementioned instructions are also available in the form of [**a shell script**](https://github.com/mkmaslov/archlinux_setup_guide/blob/main/create_USB.sh).

To wipe the storage device after Arch Linux installation, the ISO 9660 filesystem signature needs to be removed:
```
sudo wipefs --all /dev/sdX
```

## Check Secure Boot mode and UEFI mode

Enter BIOS, e.g., using Fn+F2 button combination on Lenovo laptops. Navigate to "Security" section, disable Secure Boot, reset Secure Boot to Setup Mode and restore Factory Keys (PK,KEK,db and dbx).

## Partitioning hard drive and configuring full-disk AES encryption

Installation on x86-64 requires EFI boot partition

Check if EFI is enabled:
```
ls /sys/firmware/efi/efivars
```
output should be non-empty.

Partition drive: 
```
fdisk /dev/nvme0n1
g
n
+512M
t
1
n
t
43
w
```
note that PC setup requires GPT partition table and EFI-type boot partition.

Fastest algorithm on hardware with AES acelaration:
```
cryptsetup luksFormat --cipher=aes-xts-plain64 --keysize=512 /dev/nvme0n1p2
```

## Performing initial PC setup and installing basic software

```
pacstrap -something wpa_supplicant dhcpcd lvm2
```

## DUMP
```
>>  pacman -S lvm2 man-db man-pages texinfo terminus-font
>>  nano /etc/fstab
/dev/sda1   /boot   vfat  defaults   0   0
/dev/mapper/main-root   /root   ext4   defaults   0   0
/dev/mapper/main-swap   none   swap   defaults   0   0
>>  nano /etc/mkinitcpio.conf
HOOKS=(base udev autodetect modconf block keyboard encrypt lvm2 filesystems fsck)
>>  mkinitcpio -P
>>  passwd
<root password>
>>  nano /boot/cmdline.txt
cryptdevice=/dev/sda2:main root=/dev/mapper/main-root resume=/dev/mapper/main-swap
>>  nano /etc/hostname
<hostname>
>>  nano /etc/hosts
127.0.0.1  localhost my-laptop
::1        localhost my-laptop
127.0.1.1  my-laptop.localdomain my-laptop
>>  setfont ter-132b
```

# Recommended software

## Personal computer

- **Mozilla Firefox**
  * change settings for privacy
  * Bitwarden extension
  * uBlock Origin extension with Legitimate URLs list
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

- **Seafile** -- end-to-end encrypted open source file synchronization service.
 See [server manual](https://manual.seafile.com/deploy/) and [download for ARM](https://github.com/haiwen/seafile-rpi/releases).
 
 - **EteBase** -- end-to-end encrypted open source contact and calendar service. See [GitHub page](https://github.com/etesync/server).
 
 - **Standard notes** -- end-to-end encrypted open source note taking service. See [self-hosting guide](https://docs.standardnotes.com/self-hosting/docker).
 
 - **Bitwarden**
 
 - **Navidrome**
 
 - **PiHole**
 
 [Other ideas](https://github.com/pluja/awesome-privacy#photo-storage)
 
 


# Comments
[^C1]: I once broke my installation by running `pacman -Syu` on a system with an unsynchronized clock. The operation freezed with "GPG key from the future" error. After reboot, `initramfs.img` was corrupted and the system was not booting.


