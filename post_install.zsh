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

# Configuring GNOME
cprint "Configuring GNOME"
gsettings set \
  org.gnome.desktop.wm.preferences button-layout ':minimize,maximize,close'
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'
gsettings set org.gnome.desktop.interface icon-theme 'Numix-Square'
gsettings set org.gnome.mutter dynamic-workspaces false
gsettings set org.gnome.desktop.wm.preferences num-workspaces 5
gsettings set org.gnome.desktop.interface show-battery-percentage true
gsettings set org.gnome.desktop.interface enable-hot-corners false
gsettings set org.gnome.desktop.interface enable-animations false
gsettings set org.gnome.desktop.interface clock-format '24h'
gsettings set org.gnome.desktop.interface clock-show-date true
gsettings set org.gnome.desktop.interface clock-show-seconds true
gsettings set org.gnome.desktop.interface clock-show-weekday true
gsettings set org.gnome.desktop.privacy send-software-usage-stats false
gsettings set org.gnome.desktop.privacy report-technical-problems false
gsettings set org.gnome.desktop.privacy remove-old-temp-files true
gsettings set org.gnome.desktop.privacy remove-old-trash-files true
gsettings set org.gnome.desktop.privacy remember-recent-files false
gsettings set org.gnome.desktop.privacy remember-app-usage false
gsettings set org.gnome.desktop.privacy old-files-age 30
gsettings set \
  org.gnome.settings-daemon.plugins.power power-button-action 'suspend'
gsettings set \
  org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'
gsettings set \
  org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 900
gsettings set \
  org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'suspend'
gsettings set \
  org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout 900
gsettings set org.gnome.settings-daemon.plugins.power idle-dim true
gsettings set \
  org.gnome.settings-daemon.plugins.power idle-brightness 30
# Gedit configuration.
gsettings set org.gnome.gedit.preferences.editor scheme 'oblivion'
gsettings set org.gnome.gedit.preferences.editor use-default-font false
gsettings set org.gnome.gedit.preferences.editor tabs-size 4
gsettings set org.gnome.gedit.preferences.editor syntax-highlighting true
gsettings set org.gnome.gedit.preferences.editor display-right-margin true
gsettings set org.gnome.gedit.preferences.editor right-margin-position 80
gsettings set org.gnome.gedit.preferences.editor editor-font 'Source Code Pro 14'
gsettings set org.gnome.gedit.plugins.spell highlight-misspelled true
# Nautilus configuration.
gsettings set org.gnome.nautilus.preferences show-hidden-files true
gsettings set org.gnome.nautilus.window-state initial-size "(960,960)"

# Installing GNOME extensions
cprint "Installing GNOME extensions (ignore errors, choose \"Install\")"
EXTENSION_LIST=(
dash-to-panel@jderose9.github.com
appindicatorsupport@rgcjonas.gmail.com
)
for EXTENSION in "${EXTENSION_LIST[@]}"
do
  busctl --user call org.gnome.Shell.Extensions \
  /org/gnome/Shell/Extensions org.gnome.Shell.Extensions \
  InstallRemoteExtension s ${EXTENSION} || true
done
#gnome-extensions enable user-theme@gnome-shell-extensions.gcampax.github.com
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

# Configure VScodium
# ${HOME}/.config/VSCodium/User/settings.json

# Install LaTex extension for Inkscape.
sudo pacman -S --needed inkscape gtksourceview3
cd ${TEMPDIR}
curl -LO https://github.com/textext/textext/releases/download/1.10.0/TexText-Linux-1.10.0.tar.gz
tar -xvzf TexText-Linux-1.10.0.tar.gz
cd textext-*
python3 setup.py
echo -E "\usepackage{physics,bm}" >> \
  "${HOME}/.config/inkscape/extensions/textext/default_packages.tex"
cd .. && cd ..

rm -rf ${TEMPDIR}

cprint "Post-installation finished."