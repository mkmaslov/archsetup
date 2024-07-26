#!/bin/zsh

set -e

# -----------------------------------------------------------------------------
# This script installs and configures applications.
# It should be run on an already booted fresh Arch Linux installation.
# The installation includes:
# - yay helper for Arch User Repository (AUR)
# - full GNOME configuration
# - useful applications
# --  configures nvim text editor
# --  sets up an isolated python environment with Jupyter Notebook 
# --  performs minimal TexLive installation
# -----------------------------------------------------------------------------

# Output formatting.

# Highlight the output.
YELLOW="\e[1;33m" && GREEN="\e[1;32m" && COLOR_OFF="\e[0m"
cprint() { echo -e "${YELLOW}${1}${COLOR_OFF}"; }
success() { echo -e "${GREEN}${1}${COLOR_OFF}"; }

# Confirm continuing.
confirm() { 
  cprint "\nPress \"Enter\" to continue, \"Ctrl+c\" to cancel ..."
  read -s -k "?"
}

# Create directory for temporary files.
TEMP_ROOT="${HOME}/.post_install" && mkdir ${TEMP_ROOT} && cd ${TEMP_ROOT}

# Links to GitHub repository.
RES="https://raw.githubusercontent.com/mkmaslov/archsetup/main/resources"
SCRIPTS="https://raw.githubusercontent.com/mkmaslov/archsetup/main/scripts"

# -----------------------------------------------------------------------------
# Install software.
# -----------------------------------------------------------------------------

cprint "Installing software ..."
cprint "You may be prompted for a sudo password. (required to use pacman)"
sudo pacman -Syu
PKGS=""
# CLI tools.
PKGS+="tmux neovim btop git go jq rsync powertop fwupd "
PKGS+="zsh zsh-completions zsh-syntax-highlighting zsh-autosuggestions "
# File system management tools.
PKGS+="exfatprogs dosfstools "
# Image/video viewing/editing.
PKGS+="gimp inkscape vlc guvcview "
# GUI libraries/tools.
PKGS+="xorg-xeyes qt5-wayland qt6-wayland "
# Text editing.
PKGS+="calibre xournalpp pdfarranger gedit "
PKGS+="libreoffice-fresh libreoffice-extension-texmaths "
PKGS+="hunspell hunspell-en_us hunspell-de otf-montserrat "
PKGS+="adobe-source-code-pro-fonts adobe-source-sans-fonts adobe-source-serif-fonts "
# Messaging apps.
PKGS+="signal-desktop telegram-desktop "
# Internet.
PKGS+="firefox torbrowser-launcher transmission-gtk "
# Virtualization software.
PKGS+="qemu-base libvirt virt-manager iptables-nft dnsmasq "
PKGS+="dmidecode qemu-hw-display-qxl "
sudo pacman -S --needed ${PKGS}
success "Successfully installed software!"

# -----------------------------------------------------------------------------
# Install "yay" - an AUR helper.
# -----------------------------------------------------------------------------

cprint "Installing \"yay\" - an AUR helper ..."
TEMP_DIR="${TEMP_ROOT}/yay" && mkdir ${TEMP_DIR} && cd ${TEMP_DIR}
git clone https://aur.archlinux.org/yay.git
cd yay && makepkg -si --noconfirm && cd ${TEMP_ROOT}
success "Successfully installed \"yay\" - an AUR helper!"

# -----------------------------------------------------------------------------
# Install AUR packages.
# -----------------------------------------------------------------------------

cprint "Installing software from AUR ..."
yay -Syu --answerclean All --answerdiff None --removemake
yay -S --answerclean All --answerdiff None --removemake \
  numix-icon-theme-git numix-square-icon-theme protonvpn-cli seafile-client \
  vscodium-bin zoom skypeforlinux-stable-bin forticlient-vpn
success "Successfully installed software from AUR!"

# -----------------------------------------------------------------------------
# Configure GNOME.
# -----------------------------------------------------------------------------

curl "${SCRIPTS}/configure_gnome.sh" > "${TEMP_ROOT}/configure_gnome.sh"
bash ${TEMP_ROOT}/configure_gnome.sh

# -----------------------------------------------------------------------------
# Install Python and JupyterLab.
# -----------------------------------------------------------------------------

curl "${SCRIPTS}/install_python.sh" > "${TEMP_ROOT}/install_python.sh"
bash ${TEMP_ROOT}/install_python.sh

# -----------------------------------------------------------------------------
# Install TeX Live.
# -----------------------------------------------------------------------------

curl "${SCRIPTS}/install_tex.sh" > "${TEMP_ROOT}/install_tex.sh"
bash ${TEMP_ROOT}/install_tex.sh

# -----------------------------------------------------------------------------
# Install Julia.
# -----------------------------------------------------------------------------

curl "${SCRIPTS}/install_julia.sh" > "${TEMP_ROOT}/install_julia.sh"
bash ${TEMP_ROOT}/install_julia.sh

# -----------------------------------------------------------------------------
# Install Inkscape.
# -----------------------------------------------------------------------------

curl "${SCRIPTS}/install_inkscape.sh" > "${TEMP_ROOT}/install_inkscape.sh"
bash ${TEMP_ROOT}/install_inkscape.sh

# -----------------------------------------------------------------------------
# Configure nvim.
# -----------------------------------------------------------------------------

cprint "Configuring nvim ..."
cprint "You may be prompted for a sudo password. (to edit /root folder)"
curl "${RES}/nvim/.vimrc" > "${TEMP_ROOT}/.temp_vimrc"
cp "${TEMP_ROOT}/.temp_vimrc" "${HOME}/.vimrc"
sudo mv "${TEMP_ROOT}/.temp_vimrc" "/root/.vimrc"
curl "${RES}/nvim/init.vim" > "${TEMP_ROOT}/temp_init.vim"
mkdir -p ${HOME}/.config/nvim
cp "${TEMP_ROOT}/temp_init.vim" "${HOME}/.config/nvim/init.vim"
sudo mkdir -p /root/.config/nvim
sudo mv "${TEMP_ROOT}/temp_init.vim" "/root/.config/nvim/init.vim"
success "Successfully configured nvim!"

# -----------------------------------------------------------------------------
# Configure VS Codium.
# -----------------------------------------------------------------------------

cprint "Configuring VS Codium ..."
curl "${RES}/vscodium/settings.json" > "${HOME}/.config/VSCodium/User/settings.json"
curl "${RES}/vscodium/keybindings.json" > "${HOME}/.config/VSCodium/User/keybindings.json"
codium --install-extension james-yu.latex-workshop
codium --install-extension streetsidesoftware.code-spell-checker
success "Successfully configured VS Codium!"




# -----------------------------------------------------------------------------
# To-do's:
# - vscodium configuration (extensions?)
# - USBGuard setup
# - apparmor + audit setup
# - firejail + firetools setup

# Install and configure USBGuard.
#pacman -S --needed usbguard
#systemctl enable usbguard-dbus.service --root=/mnt &>/dev/null

# Grant GNOME access to USBGuard.
#curl "${RESOURCES}/arch/usbguard.rules" > \
#  "/mnt/etc/polkit-1/rules.d/70-allow-usbguard.rules"

# apparmor, audit, firejail, firetools, usbguard
#systemctl enable apparmor.service --root=/mnt &>/dev/null
#systemctl enable auditd.service --root=/mnt &>/dev/null
# Enable AppArmor rules cashing.
#sed -i 's,#write-cache,write-cache,g' /mnt/etc/apparmor/parser.conf

# Kernel parameters: security
#CMDLINE+="lsm=landlock,lockdown,yama,integrity,apparmor,bpf audit=1 "

# -----------------------------------------------------------------------------








# -----------------------------------------------------------------------------
# Miscelaneous tasks.
# -----------------------------------------------------------------------------
cprint "Finishing touches ..."

# Enable services.
systemctl enable --user pipewire-pulse
systemctl enable --user libvirtd

# Install and configure Seafile.
cp /usr/share/applications/seafile.desktop ${HOME}/.config/autostart/

# Set Firefox as default browser.
xdg-settings set default-web-browser firefox.desktop

# Configure git to use keyring
git config --global credential.helper libsecret

# Remove directory for temporary files.
rm -rf ${TEMP_ROOT}

success "Post-installation finished!"
