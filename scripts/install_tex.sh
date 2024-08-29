#!/bin/bash
 
set -e

# -----------------------------------------------------------------------------
# This script provides minimal TeX Live installation.
# It includes packages required for writing physics papers.
# -----------------------------------------------------------------------------

# Highlight the output.
YELLOW="\e[1;33m" && GREEN="\e[1;32m" && COLOR_OFF="\e[0m"
cprint() { echo -e "${YELLOW}${1}${COLOR_OFF}"; }
success() { echo -e "${GREEN}${1}${COLOR_OFF}"; }

cprint "Installing TeX Live ..."

# Check if curl and perl are installed. If not - quit.
if ! [ -x "$(command -v curl)" ]; then
  cprint "Please install \"curl\" before proceeding."
  exit
fi
if ! [ -x "$(command -v perl)" ]; then
  cprint "Please install \"perl\" before proceeding."
  exit
fi
  
# Download and install TeX Live.
TEMP_DIR="${HOME}/.temp_tex_install"
mkdir ${TEMP_DIR} && cd ${TEMP_DIR}
curl -LO https://mirror.ctan.org/systems/texlive/tlnet/install-tl-unx.tar.gz
tar -xvzf install-tl-unx.tar.gz
rm install-tl-unx.tar.gz
cd install-tl-*
cat > texlive.profile <<EOF
  selected_scheme scheme-minimal
  binary_x86_64-linux 1
  TEXDIR ~/.texlive/
  TEXMFCONFIG ~/.texlive/texmf-config
  TEXMFSYSCONFIG ~/.texlive/texmf-config
  TEXMFLOCAL ~/.texlive/texmf-local
  TEXMFHOME ~/.texlive/texmf-local
  TEXMFVAR ~/.texlive/texmf-var
  TEXMFSYSVAR ~/.texlive/texmf-var
EOF
perl install-tl -profile texlive.profile
cd ${HOME} && rm -rf ${TEMP_DIR}

# Update tlmgr and install necessary packages.
tlmgr update --all
tlmgr install revtex physics graphics tools latex-bin geometry \
  amsmath underscore dvipng type1cm cm-super url textcase natbib \
  hyperref pdftexcmds infwarerr kvoptions etoolbox ulem amscls \
  l3packages xcolor embedfile comment adjustbox epstopdf-pkg
  
# Add LaTeX binaries to $PATH.
sudo \
  echo "PATH=\"\${PATH}:${HOME}/.texlive/bin/x86_64-linux\"" >> /etc/environment
  
success "Successfully installed TeX Live!"
