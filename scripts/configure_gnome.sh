#!/bin/bash

set -e

# -----------------------------------------------------------------------------
# This script configures GNOME desktop environment.
# It includes appindicators and dash-to-panel extensions.
# -----------------------------------------------------------------------------

# Highlight the output.
YELLOW="\e[1;33m" && COLOR_OFF="\e[0m"
cprint() { echo -e "${YELLOW}${1}${COLOR_OFF}"; }

# -----------------------------------------------------------------------------
# Configure GNOME.
# -----------------------------------------------------------------------------

cprint "Configuring GNOME ..."
# User interface.
gsettings set org.gnome.desktop.calendar show-weekdate true
gsettings set org.gnome.desktop.interface clock-format '24h'
gsettings set org.gnome.desktop.interface clock-show-date true
gsettings set org.gnome.desktop.interface clock-show-seconds true
gsettings set org.gnome.desktop.interface clock-show-weekday true
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
gsettings set org.gnome.desktop.interface enable-animations false
gsettings set org.gnome.desktop.interface enable-hot-corners false
gsettings set org.gnome.desktop.interface font-antialiasing 'rgba'
gsettings set org.gnome.desktop.interface font-hinting 'none'
gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'
gsettings set org.gnome.desktop.interface icon-theme 'Numix-Square'
gsettings set org.gnome.desktop.interface monospace-font-name 'Source Code Pro 12'
gsettings set org.gnome.desktop.interface show-battery-percentage true
gsettings set org.gnome.mutter dynamic-workspaces false
gsettings set org.gnome.desktop.wm.preferences num-workspaces 6
gsettings set \
  org.gnome.desktop.wm.preferences button-layout ':minimize,maximize,close'
gsettings set org.gnome.desktop.wm.preferences focus-new-windows 'strict'
gsettings set org.gnome.desktop.wm.preferences focus-mode 'sloppy'
gsettings set org.gnome.gnome-session logout-prompt false
# Media handling.
gsettings set org.gnome.desktop.media-handling automount-open false
gsettings set org.gnome.desktop.media-handling autorun-never true
# Keyboard layout.
gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us+intl'), ('xkb', 'ru')]"
gsettings set org.gnome.desktop.peripherals.keyboard numlock-state true
# Privacy.
gsettings set org.gnome.desktop.privacy send-software-usage-stats false
gsettings set org.gnome.desktop.privacy report-technical-problems false
gsettings set org.gnome.desktop.privacy remove-old-temp-files true
gsettings set org.gnome.desktop.privacy remove-old-trash-files true
gsettings set org.gnome.desktop.privacy remember-recent-files false
gsettings set org.gnome.desktop.privacy remember-app-usage false
gsettings set org.gnome.desktop.privacy old-files-age 30
# USBGuard.
gsettings set org.gnome.desktop.privacy usb-protection true
gsettings set org.gnome.desktop.privacy usb-protection-level 'always'
gsettings set org.gnome.login-screen enable-fingerprint-authentication false
gsettings set org.gnome.login-screen enable-smartcard-authentication false
# Power settings.
gsettings set org.gnome.settings-daemon.plugins.power power-button-action 'suspend'
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 900
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'suspend'
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout 900
gsettings set org.gnome.settings-daemon.plugins.power idle-dim true
gsettings set org.gnome.settings-daemon.plugins.power idle-brightness 30
# Night light.
gsettings set org.gnome.settings-daemon.plugins.color night-light-enabled true
gsettings set org.gnome.settings-daemon.plugins.color night-light-schedule-automatic false
gsettings set org.gnome.settings-daemon.plugins.color night-light-schedule-from 22
gsettings set org.gnome.settings-daemon.plugins.color night-light-schedule-to 7
gsettings set org.gnome.settings-daemon.plugins.color night-light-temperature 3200
# GNOME File Chooser.
gsettings set org.gtk.settings.file-chooser show-hidden true
gsettings set org.gtk.settings.file-chooser sort-directories-first true
gsettings set org.gtk.settings.file-chooser show-type-column false
gsettings set org.gtk.settings.file-chooser date-format 'with-time'
gsettings set org.gtk.settings.file-chooser window-size "(960,960)"
gsettings set org.gtk.gtk4.settings.file-chooser show-hidden true
gsettings set org.gtk.gtk4.settings.file-chooser sort-directories-first true
gsettings set org.gtk.gtk4.settings.file-chooser show-type-column false
gsettings set org.gtk.gtk4.settings.file-chooser date-format 'with-time'
gsettings set org.gtk.gtk4.settings.file-chooser window-size "(960,960)"
# Gedit.
gsettings set org.gnome.gedit.preferences.editor scheme 'oblivion'
gsettings set org.gnome.gedit.preferences.editor use-default-font false
gsettings set org.gnome.gedit.preferences.editor tabs-size 4
gsettings set org.gnome.gedit.preferences.editor syntax-highlighting true
gsettings set org.gnome.gedit.preferences.editor display-line-numbers true
gsettings set org.gnome.gedit.preferences.editor highlight-current-line false
gsettings set org.gnome.gedit.preferences.editor display-right-margin true
gsettings set org.gnome.gedit.preferences.editor right-margin-position 80
gsettings set org.gnome.gedit.preferences.editor editor-font 'Source Code Pro 14'
gsettings set org.gnome.gedit.preferences.ui.theme-variant open-recent true
gsettings set org.gnome.gedit.plugins.spell highlight-misspelled true
gsettings set org.gnome.gedit.state.file-chooser open-recent true
# Nautilus.
gsettings set org.gnome.nautilus.preferences show-hidden-files true
gsettings set org.gnome.nautilus.preferences open-folder-on-dnd-hover false
gsettings set org.gnome.nautilus.preferences mouse-use-extra-buttons false
gsettings set org.gnome.nautilus.preferences date-time-format 'detailed'
gsettings set org.gnome.nautilus.window-state initial-size "(960,960)"
gsettings set org.gnome.nautilus.icon-view default-zoom-level 'medium'
# Eye of GNOME.
gsettings set org.gnome.eog.ui image-gallery true
gsettings set org.gnome.eog.ui statusbar true
gsettings set org.gnome.eog.ui image-gallery-position 'left'
# Location.
gsettings set org.gnome.system.location enabled false
gsettings set org.gnome.eog.ui max-accuracy-level 'country'
# GNOME Terminal.
gsettings set org.gnome.terminal.legacy theme-variant 'dark'
gsettings set org.gnome.terminal.legacy confirm-close true

# -----------------------------------------------------------------------------
# Install GNOME extensions.
# -----------------------------------------------------------------------------

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