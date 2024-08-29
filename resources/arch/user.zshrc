#!/bin/zsh

# Enable colors
autoload -Uz colors && colors

# Set command history settings
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=10000

# Set custom prompt
PS1_USER="%F{000}%K{012} %n [%T] %F{012}%K{010}"
PS1_DIR="%F{000}%K{010}%~ %F{010}%K{reset_color}%F{reset_color} "
export PS1="${PS1_USER} ${PS1_DIR}"

export PYDEVD_DISABLE_FILE_VALIDATION=1
export MOZ_ENABLE_WAYLAND=1
export PATH="${PATH}:${HOME}/.texlive/bin/x86_64-linux"
export JUPYTER_CONFIG_DIR="${HOME}/.python_venv/etc/jupyter"
export JUPYTER_DATA_DIR="${HOME}/.python_venv/share/jupyter"
export JUPYTER_RUNTIME_DIR="${HOME}/.python_venv/share/jupyter/runtime"
export IPYTHONDIR="${HOME}/.python_venv/etc/ipython"

# Set shortcuts for CLI commands
alias ls='ls -l -A --color=auto --group-directories-first'
alias grep='grep --color=auto'
alias archupdate="yes | yay -Syu \
  --answerclean All --answerdiff None --removemake"
alias archbackup="rsync -a --delete --progress"
export PYTHON_VENV_BIN="${HOME}/.python_venv/bin"
alias jupyter="${PYTHON_VENV_BIN}/jupyter"
alias venvpip="${PYTHON_VENV_BIN}/pip --require-virtualenv"
alias venvpython="${PYTHON_VENV_BIN}/python"

# This should be saved to Downloads
alias yt-dlp-video="${PYTHON_VENV_BIN}/yt-dlp \
  -f \"bv*+ba/b\" --embed-thumbnail -o \"${HOME}/Downloads/%(title)s.%(ext)s\""
alias yt-dlp-music="${PYTHON_VENV_BIN}/yt-dlp \
  -f \"ba/b\" --embed-thumbnail -o \"${HOME}/Downloads/%(title)s.%(ext)s\""

# Turn off all beeps
unsetopt BEEP

# Load zsh modules.
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh