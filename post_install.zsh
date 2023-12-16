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
  gnome-disk-utility gvfs-mtp gnome-tweaks gnome-themes-extra eog gedit \
  gnome-shell-extensions gnome-calculator xdg-user-dirs-gtk \
  fwupd gimp vlc firefox adobe-source-code-pro-fonts adobe-source-sans-fonts \
  calibre transmission-gtk exfatprogs guvcview signal-desktop telegram-desktop \
  torbrowser-launcher qemu-base libvirt virt-manager iptables-nft dnsmasq 
confirm

# Configure zsh shell (root).
cprint "Configuring zsh shell for root user. You will be prompted for password."
su -c "chsh -s /bin/zsh"
curl "${RES}/root.zshrc" > ".temp_zshrc"
sudo mv ".temp_zshrc" "/root/.zshrc"

# Enable pipewire.
systemctl enable --user pipewire-pulse

# Installing yay AUR helper
cprint "Installing yay AUR helper"
mkdir temp && cd temp
git clone https://aur.archlinux.org/yay.git
cd yay && makepkg -si --noconfirm && cd .. && cd .. && rm -rf temp

cprint "Installing software from AUR"
yes | yay -Syu --answerclean All --answerdiff None --removemake
yes | yay -S --answerclean All --answerdiff None --removemake\
  numix-icon-theme-git numix-square-icon-theme forticlient-vpn \
  protonvpn-cli seafile-client gnome-browser-connector vscodium-bin
# zoom skypeforlinux-stable-bin 
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
gsettings set org.gnome.nautilus.window-state initial-size (960,960)

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
gnome-extensions enable user-theme@gnome-shell-extensions.gcampax.github.com
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

# Setting up virtual environment for Python
cprint "Setting up Python virtual environment:"
PYDIR="${HOME}/.python_venv"
PIP="${PYDIR}/bin/pip"
JUPYTER="${PYDIR}/bin/jupyter"
mkdir ${PYDIR} && mkdir ${PYDIR}/cache
cat > ${PYDIR}/pip.conf <<EOF
[global]
cache-dir=${PYDIR}/cache
EOF
python -m venv ${PYDIR}
${PIP} install --upgrade pip --require-virtualenv
${PIP} install h5py numpy scipy sympy matplotlib notebook\
  --require-virtualenv
# nbextensions don't work with notebook 7.0
#${PIP} install h5py numpy scipy sympy matplotlib notebook\
#  jupyter_contrib_nbextensions jupyter_nbextensions_configurator\
#  --require-virtualenv
#${JUPYTER} contrib nbextension install --sys-prefix
#${JUPYTER} nbextensions_configurator enable --sys-prefix
mkdir "${PYDIR}/etc/jupyter/custom"
curl "${RES}/custom.css" > "${PYDIR}/etc/jupyter/custom/custom.css"
# They changed location.
#curl "${RES}/notebook.json" > "${PYDIR}/etc/jupyter/nbconfig/notebook.json"
confirm

# Configure git to use keyring
git config --global credential.helper libsecret

# Minimal TeXLive installation
TEMPDIR="${HOME}/.tex_install_temp"
mkdir ${TEMPDIR} && cd ${TEMPDIR}
curl -LO https://mirror.ctan.org/systems/texlive/tlnet/install-tl-unx.tar.gz
tar -xvzf install-tl-unx.tar.gz
rm install-tl-unx.tar.gz
cd install-tl-*
curl "${RES}/texlive.profile" > "texlive.profile"
perl install-tl -profile texlive.profile
tlmgr update --all
tlmgr install revtex physics graphics tools\
  latex-bin geometry amsmath underscore dvipng
cd .. && rm -rf ${TEMPDIR}
confirm

# Install LaTex extension for Inkscape.
sudo pacman -S --needed inkscape gtksourceview3
TEMPDIR="${HOME}/.textext_temp"
mkdir ${TEMPDIR} && cd ${TEMPDIR}
curl -LO https://github.com/textext/textext/releases/download/1.10.0/TexText-Linux-1.10.0.tar.gz
tar -xvzf TexText-Linux-1.10.0.tar.gz
cd textext-*
python3 setup.py
echo -E "\usepackage{physics,bm}" >> \
  "${HOME}/.config/inkscape/extensions/textext/default_packages.tex"
cd .. && cd .. && rm -rf ${TEMPDIR}