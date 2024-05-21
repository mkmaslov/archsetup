#!/bin/zsh

# This script installs and configures applications.
# It should be run on an already booted fresh Arch Linux installation.
# This script:
# --  configures zsh shell
# --  installs yay helper for AUR, installs software from AUR
# --  configures nvim text editor
# --  sets up an isolated python environment with Jupyter Notebook 
# --  performs minimal TexLive installation

set -e
RES="https://raw.githubusercontent.com/mkmaslov/archsetup/main/resources"
SCRIPTS="https://raw.githubusercontent.com/mkmaslov/archsetup/main/scripts"
TEMPDIR=${HOME}/.post_install
mkdir ${TEMPDIR}

# Highlight the output.
YELLOW="\e[1;33m" && COLOR_OFF="\e[0m"
cprint() { echo -e "${YELLOW}${1}${COLOR_OFF}"; }

# Confirm continuing
confirm() { 
  cprint "Press \"Enter\" to continue, \"Ctrl+c\" to cancel ..."
  read -s -k "?"
}

# Install software.
cprint "Installing packages:"
sudo pacman -Syu
sudo pacman -S --needed \
  gnome-disk-utility gvfs-mtp gvfs-gphoto2 gnome-tweaks gnome-themes-extra eog \
  gnome-shell-extensions gnome-calculator xdg-user-dirs-gtk \
  fwupd gimp vlc firefox adobe-source-code-pro-fonts adobe-source-sans-fonts \
  calibre transmission-gtk exfatprogs guvcview signal-desktop telegram-desktop \
  torbrowser-launcher qemu-base libvirt virt-manager iptables-nft dnsmasq \
  dosfstools xorg-xeyes xournalpp pdfarranger rsync gedit powertop \
  qt5-wayland qt6-wayland
confirm

# Packages for virtualization:
# libvirt virt-manager qemu-base iptables-nft dnsmasq dmidecode qemu-hw-display-qxl

# Enable services.
systemctl enable --user pipewire-pulse
systemctl enable --user libvirtd

# Configure zsh shell (root).
cprint "Configuring zsh shell for root user."
cprint "Please enter ROOT password:"
su -c "chsh -s /bin/zsh"
curl "${RES}/root.zshrc" > ".temp_zshrc"
sudo mv ".temp_zshrc" "/root/.zshrc"

# Installing yay AUR helper
cprint "Installing yay AUR helper"
mkdir temp && cd temp
git clone https://aur.archlinux.org/yay.git
cd yay && makepkg -si --noconfirm && cd .. && cd .. && rm -rf temp

cprint "Installing software from AUR"
yes | yay -Syu --answerclean All --answerdiff None --removemake
yes | yay -S --answerclean All --answerdiff None --removemake\
  numix-icon-theme-git numix-square-icon-theme \
  protonvpn-cli seafile-client vscodium-bin
# zoom skypeforlinux-stable-bin gnome-browser-connector
confirm

# Configure GNOME.
curl "${SCRIPTS}/configure_gnome.sh" > "${TEMPDIR}/configure_gnome.sh"
bash ${TEMPDIR}/configure_gnome.sh
confirm

# Configure nvim text editor (user and root).
cprint "Configuring nvim:"
curl "${RES}/.vimrc" > ".temp_vimrc"
cp ".temp_vimrc" "${HOME}/.vimrc"
sudo mv ".temp_vimrc" "/root/.vimrc"
curl "${RES}/init.vim" > "temp_init.vim"
mkdir -p ${HOME}/.config/nvim
cp "temp_init.vim" "${HOME}/.config/nvim/init.vim"
sudo mkdir -p /root/.config/nvim
sudo mv "temp_init.vim" "/root/.config/nvim/init.vim"
confirm

# Configure git to use keyring
git config --global credential.helper libsecret

# Install Python and JupyterLab.
curl "${SCRIPTS}/install_python.sh" > "${TEMPDIR}/install_python.sh"
bash ${TEMPDIR}/install_python.sh

# Install TeX Live.
curl "${SCRIPTS}/install_tex.sh" > "${TEMPDIR}/install_tex.sh"
bash ${TEMPDIR}/install_tex.sh

# Install Julia.
curl "${SCRIPTS}/install_julia.sh" > "${TEMPDIR}/install_julia.sh"
bash ${TEMPDIR}/install_julia.sh

# Install Inkscape.
curl "${SCRIPTS}/install_inkscape.sh" > "${TEMPDIR}/install_inkscape.sh"
bash ${TEMPDIR}/install_inkscape.sh

# Configure VScodium
# ${HOME}/.config/VSCodium/User/settings.json



rm -rf ${TEMPDIR}

cprint "Post-installation finished."