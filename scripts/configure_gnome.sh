#!/bin/bash

set -e

# This script configures GNOME desktop environment.
# It includes appindicators and dash-to-panel extensions.

# Highlight the output.
YELLOW="\e[1;33m" && COLOR_OFF="\e[0m"
cprint() { echo -e "${YELLOW}${1}${COLOR_OFF}"; }

# Configuring GNOME
cprint "Configuring GNOME ..."
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


# Installing GNOME extensions.
# Code taken from: https://unix.stackexchange.com/a/762174
cprint "Installing GNOME extensions ..."
TEMPDIR="${HOME}/.gnome_config_temp" ; mkdir ${TEMPDIR}
EXTENSION_LIST=(dash-to-panel@jderose9.github.com
  appindicatorsupport@rgcjonas.gmail.com)
GNOME_SHELL_OUTPUT=$(gnome-shell --version)
GNOME_SHELL_VERSION=${GNOME_SHELL_OUTPUT:12:2}
for i in "${EXTENSION_LIST[@]}"
do
    VERSION_LIST_TAG=$(\
      curl -Lfs "https://extensions.gnome.org/extension-query/?search=${i}" | \
      jq '.extensions[] | select(.uuid=="'"${i}"'")') 
    VERSION_TAG="$(echo "$VERSION_LIST_TAG" | \
      jq '.shell_version_map |."'"${GN_SHELL}"'" | ."pk"')"
    LINK="https://extensions.gnome.org/download-extension/"
    LINK+="${i}.shell-extension.zip?version_tag=$VERSION_TAG"
    FILE="${TEMPDIR}/${i}.zip"
    curl -o "${FILE}" "${LINK}"
    gnome-extensions install --force "${FILE}"
done
rm -rf "${TEMPDIR}"
gnome-extensions enable user-theme@gnome-shell-extensions.gcampax.github.com

cprint "Configured GNOME. (changes may require a reboot)"