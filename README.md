# Arch Linux installation guide

This document provides detailed instructions for Arch Linux installation. It covers the following use cases:
- a machine with x86-64 architecture used as a *personal computer* (desktop environment, internet browser, etc)
- a machine with AArch64 architecture used as a *server* (headless node with Docker containers)

The contents are organised as follows: 

- [Installing Arch Linux on x64 machine](#installing-arch-linux-on-x64-machine)
  * [Creating installation medium](#creating-installation-medium)
- [Arch Linux ARM](#arch-linux-arm)
  * [Firmware maintenance drive](#firmware-maintenance-drive)
    + [RaspberryPi OS CLI Setup](#raspberrypi-os-cli-setup)
  * [Maintenance drive](#maintenance-drive)
  * [Time synchronization](#time-synchronization)
 - [General tools](#general-tools)
   * [CLI configuration of Wi-Fi connection](#cli-configuration-of-wi-fi-connection)
 - [Recommended software](#recommended-software)
   * [Personal computer](#personal-computer)
   * [Server](#server)
  
 **DISCLAIMER:** author does not take responsibility for the problems that you may face while following this guide. In case you notice an error, have a suggestion or feel that a certain statement is unclear, you could provide feedback [here](https://github.com/mkmaslov/archlinux_setup_guide/issues). This guide does not contain any novel information, instead it represents a structured compilation of advice and tricks from Internet as well as some personal knowledge. Where possible, a reference to the original material or additional information is provided.
    
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

## Partitioning drive
Installation on x86-64 requires EFI boot partition
```
fdisk /dev/nvme0n1
```
```
g
```
```
n
```
```
+512M
```
```
t
```
```
1
```
```
n
```
```
t
```
```
43
```
```
w
```

## Full-disk encryption
```
cryptsetup luksFormat --cipher=aes-xts-plain64 --keysize=512 /dev/nvme0n1p2
```

## Installing packages
```
pacstrap -something wpa_supplicant dhcpcd
```

# Arch Linux ARM

## Firmware maintenance drive

### RaspberryPi OS CLI Setup
To set up larger font size in console:
```
sudo dpkg-reconfigure console-setup
```

## Maintenance drive

## Partitioning drive

## Time synchronization

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

# General tools

## CLI configuration of Wi-Fi connection
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


