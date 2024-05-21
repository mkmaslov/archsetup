#!/bin/bash

set -e

# This script provides Inkscape installation.
# It includes TexText extension for rendering LaTeX.

# Highlight the output.
YELLOW="\e[1;33m" && COLOR_OFF="\e[0m"
cprint() { echo -e "${YELLOW}${1}${COLOR_OFF}"; }

cprint "Installing Inkscape ..."
cprint "You may be prompted for a sudo-user password."
cprint "(this permission is required to use pacman)"

sudo pacman -S --needed inkscape gtksourceview3 jq

# Install TexText extension for Inkscape.
TEMPDIR="${HOME}/.textext_install_temp"
mkdir ${TEMPDIR} && cd ${TEMPDIR}
VERSION=$(\
  curl -sL https://api.github.com/repos/textext/textext/releases/latest | \
  jq -r ".tag_name")
LINK="https://github.com/textext/textext/releases/download/"
LINK+="${VERSION}/TexText-Linux-${VERSION}.tar.gz"
curl -LO "${LINK}"
tar -xvzf TexText-*
cd textext-*
python3 setup.py
echo -E "\usepackage{physics,bm,xcolor,amsmath,amssymb}" >> \
  "${HOME}/.config/inkscape/extensions/textext/default_packages.tex"
cd .. && cd .. && rm -rf ${TEMPDIR}

cprint "Installed Inkscape."