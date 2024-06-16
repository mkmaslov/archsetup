#!/bin/bash

set -e

# -----------------------------------------------------------------------------
# This script provides minimal Julia installation.
# It includes packages relevant for physics.
# -----------------------------------------------------------------------------

# Highlight the output.
YELLOW="\e[1;33m" && GREEN="\e[1;32m" && COLOR_OFF="\e[0m"
cprint() { echo -e "${YELLOW}${1}${COLOR_OFF}"; }
success() { echo -e "${GREEN}${1}${COLOR_OFF}"; }

cprint "Installing Julia ..."

# Check if yay is installed. If not - quit.
if ! [ -x "$(command -v yay)" ]; then
  cprint "Please install \"yay\" before proceeding."
  exit
fi

# Check if Python virtual environment and jupyter are set up. If not - quit.
PYTHON_VENV="${HOME}/.python_venv"
if [ ! -d "${PYTHON_VENV}" ]; then
  cprint "Cannot find ${PYTHON_VENV}. Please set up Python virtual environment."
  exit
fi

# Install Julia from AUR.
yay -S --answerclean All --answerdiff None --removemake --needed julia-bin

# Create Julia script that installs packages and run it. 
TEMP_DIR="${HOME}/.temp_julia_install"
mkdir ${TEMP_DIR}
cat > ${TEMP_DIR}/install.jl <<EOF
  using Pkg
  ENV["PYTHON"]="${PYTHON_VENV}/bin/python"
  ENV["JUPYTER"]="${PYTHON_VENV}/bin/jupyter"
  Pkg.add("IJulia")
  Pkg.add("PyPlot")
  Pkg.add("LinearAlgebra")
  Pkg.add("Printf")
  Pkg.add("ProgressMeter")
  Pkg.add("Unitful")
  Pkg.add("UnitfulAtomic")
  Pkg.add("SparseArrays")
  Pkg.add("WignerSymbols")
  Pkg.add("KrylovKit")
  Pkg.add("Hungarian")
  Pkg.add("HDF5")
  Pkg.build("PyPlot")
EOF
julia ${TEMP_DIR}/install.jl
rm -rf ${TEMP_DIR}

success "Successfully installed Julia!"