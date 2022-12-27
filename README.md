This guide is a collection of useful commands while installing Arch Linux onto your PC.

- [General](#general)
  * [CLI configuration of Wi-Fi connection](#cli-configuration-of-wi-fi-connection)

- [Arch Linux on PC](#arch-linux-on-pc)
  * [Installation medium](#installation-medium)
  
- [Arch Linux ARM](#arch-linux-arm)
  * [Firmware maintenance drive](#firmware-maintenance-drive)
    + [RaspberryPi OS CLI Setup](#raspberrypi-os-cli-setup)
  * [Maintenance drive](#maintenance-drive)
  * [Time synchronization](#time-synchronization)
  
## General

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

## Arch Linux on PC

### Installation medium
List all connected drives:
```
lsblk
```
Wipe filesystem on the selected drive (`/dev/sdX`):
```
wipefs --all /dev/sdX
```
Get Arch Linux .iso and write it to the drive:
```
cp ./arch.iso /dev/sdX
```
After installation, wipe the drive with:
```
wipefs --all /dev/sdX
```

### Partitioning drive
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

### Full-disk encryption
```
cryptsetup luksFormat --cipher=aes-xts-plain64 --keysize=512 /dev/nvme0n1p2
```

### Installing packages
```
pacstrap -something wpa_supplicant dhcpcd
```

## Arch Linux ARM

### Firmware maintenance drive

#### RaspberryPi OS CLI Setup
To set up larger font size in console:
```
sudo dpkg-reconfigure console-setup
```

### Maintenance drive

### Partitioning drive

### Time synchronization

The very first thing that needs to be set up after the network is functioning is [time synchronization](https://wiki.archlinux.org/title/Systemd-timesyncd). Without a properly synchronized clock many essential tools may not work. For instance, `pacman -Syu` may fail due to time inconsistencies in GPG signatures, which may subsequently lead to a non-bootable setup[¹](#comment-1).

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

## Comments
### Comment 1
I once broke my installation by running `pacman -Syu` on a system with an unsynchronized clock. The operation freezed with "GPG key from the future" error. After reboot, `initramfs.img` was corrupted and the system was not booting.


