#!/bin/bash

set -e

PKGS=""
PKGS+="git "
PKGS+="go "
sudo pacman -S --needed ${PKGS}