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

# Configure zsh shell (user).
chsh -s /bin/zsh
mkdir ${HOME}/.zsh_plugins
(cd ${HOME}/.zsh_plugins; git clone --depth 1 --\
  https://github.com/marlonrichert/zsh-autocomplete.git)
curl "${RES}/user.zshrc" > "${HOME}/.zshrc"
source ${HOME}/.zshrc

# Configure zsh shell (root).
su -c "chsh -s /bin/zsh"
sudo mkdir /root/.zsh_plugins
su -c "(cd /root/.zsh_plugins; git clone --depth 1 --\
  https://github.com/marlonrichert/zsh-autocomplete.git)"
curl "${RES}/root.zshrc" > ".temp_zshrc"
sudo mv ".temp_zshrc" "/root/.zshrc"

# Install yay AUR helper.
mkdir temp && cd temp
git clone https://aur.archlinux.org/yay.git
cd yay && makepkg -si --noconfirm && cd .. && cd .. && rm -rf temp

# Install software from AUR.
archupdate
yes | yay -S --answerclean All --answerdiff None --removemake\
  numix-icon-theme-git numix-square-icon-theme forticlient-vpn \
  protonvpn-cli zoom skypeforlinux-stable-bin seafile-client \
  gnome-browser-connector

# Configure nvim text editor (user and root).
curl "${RES}/.vimrc" > ".temp_vimrc"
cp ".temp_vimrc" "${HOME}/.vimrc"
sudo mv ".temp_vimrc" "/root/.vimrc"
curl "${RES}/init.vim" > "temp_init.vim"
mkdir -p ${HOME}/.config/nvim
cp "temp_init.vim" "${HOME}/.config/nvim/init.vim"
sudo mkdir -p /root/.config/nvim
sudo mv "temp_init.vim" "/root/.config/nvim/init.vim"

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
