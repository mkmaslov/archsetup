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
  read -p ""
  clear
}

# Enable pipewire.
systemctl enable --user pipewire-pulse.service

# Install software.
cprint "Installing packages:"
sudo pacman -Syu
sudo pacman -S \
  calibre gimp vlc guvcview signal-desktop telegram-desktop \
  transmission-gtk torbrowser-launcher \
  qemu-base libvirt virt-manager iptables-nft dnsmasq 
confirm

# Installing yay AUR helper
cprint "Installing yay AUR helper"
mkdir temp && cd temp
git clone https://aur.archlinux.org/yay.git
cd yay && makepkg -si --noconfirm && cd .. && cd .. && rm -rf temp

cprint "Installing software from AUR"
archupdate
yes | yay -S --answerclean All --answerdiff None --removemake\
  numix-icon-theme-git numix-square-icon-theme forticlient-vpn \
  protonvpn-cli zoom skypeforlinux-stable-bin seafile-client \
  gnome-browser-connector
confirm

# Configuring GNOME
cprint "Configuring GNOME"
gsettings set \
  org.gnome.desktop.wm.preferences button-layout ':minimize,maximize,close'
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
gsettings set org.gnome.desktop.interface icon-theme 'Numix-Square'
gsettings set org.gnome.mutter dynamic-workspaces false
gsettings set org.gnome.desktop.wm.preferences num-workspaces 5

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
confirm

# Configure zsh shell (user).
chsh -s /bin/zsh
curl "${RES}/user.zshrc" > "${HOME}/.zshrc"
source ${HOME}/.zshrc

# Configure zsh shell (root).
su -c "chsh -s /bin/zsh"
curl "${RES}/root.zshrc" > ".temp_zshrc"
sudo mv ".temp_zshrc" "/root/.zshrc"

# Configure nvim text editor (user and root).
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
  jupyter_contrib_nbextensions jupyter_nbextensions_configurator\
  --require-virtualenv
${JUPYTER} contrib nbextension install --sys-prefix
${JUPYTER} nbextensions_configurator enable --sys-prefix
mkdir "${PYDIR}/etc/jupyter/custom"
curl "${RES}/custom.css" > "${PYDIR}/etc/jupyter/custom/custom.css"
curl "${RES}/notebook.json" > "${PYDIR}/etc/jupyter/nbconfig/notebook.json"
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
tlmgr install revtex physics bm graphics\
  latex-bin geometry amsmath underscore dvipng
# fix-cm type1cm latex tools
cd .. && rm -rf ${TEMPDIR}

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