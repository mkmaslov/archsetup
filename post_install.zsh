#!/bin/zsh

# This script installs and configures applications.
# It should be run on an already booted fresh Arch Linux installation.
# This script:
# --  configures zsh shell
# --  configures nvim text editor
# --  sets up an isolated python environment with Jupyter Notebook 

set -e
RES="https://raw.githubusercontent.com/mkmaslov/archsetup/main/resources"

# Configure USB Guard.
gsettings set org.gnome.desktop.privacy usb-protection true
gsettings set org.gnome.desktop.privacy usb-protection-level always

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
(sudo cd /root/.zsh_plugins; sudo git clone --depth 1 --\
  https://github.com/marlonrichert/zsh-autocomplete.git)
sudo curl "${RES}/root.zshrc" > "/root/.zshrc"

# Install yay AUR helper.
mkdir temp && cd temp
git clone https://aur.archlinux.org/yay.git
cd yay && makepkg -si --noconfirm && cd .. && cd .. && rm -rf temp

# Install software from AUR.
archupdate
yay -S --answerclean All --answerdiff None --removemake\
  numix-icon-theme-git numix-square-icon-theme forticlient-vpn\
  protonvpn-cli zoom skypeforlinux-stable-bin seafile-client

# Configure nvim text editor.
curl "${RES}/.vimrc" > "${HOME}/.vimrc"
mkdir -p ${HOME}/.config/nvim
curl "${RES}/init.vim" > "${HOME}/.config/nvim/init.vim" 
curl -fLo ${HOME}/.local/share/nvim/site/autoload/plug.vim --create-dirs \
  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
nvim +'PlugInstall --sync' +qa

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
${PIP} install numpy scipy sympy matplotlib notebook\
  jupyter_contrib_nbextensions jupyter_nbextensions_configurator\
  --require-virtualenv
${JUPYTER} contrib nbextension install --sys-prefix
${JUPYTER} nbextensions_configurator enable --sys-prefix
curl "${RES}/custom.css" > "${PYDIR}/etc/jupyter/custom.css"
curl "${RES}/notebook.json" > "${PYDIR}/etc/jupyter/nbconfig/notebook.json"
