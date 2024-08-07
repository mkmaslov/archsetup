#!/bin/bash

set -e

# -----------------------------------------------------------------------------
# This script provides minimal Python installation.
# It sets up virtual environment at ~/.python_venv.
# It includes JupyterLab and some packages.
# -----------------------------------------------------------------------------

# Highlight the output.
YELLOW="\e[1;33m" && GREEN="\e[1;32m" && COLOR_OFF="\e[0m"
cprint() { echo -e "${YELLOW}${1}${COLOR_OFF}"; }
success() { echo -e "${GREEN}${1}${COLOR_OFF}"; }

cprint "Installing Python and JupyterLab ..."

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
${PIP} install jupyterlab numpy scipy matplotlib sympy h5py \
    pandas tabulate pypdf yt-dlp --require-virtualenv

success "Successfully installed Python and JupyterLab!"
