#!/bin/zsh

# Load zsh modules.
source "${HOME}/.zsh_plugins/zsh-autocomplete/zsh-autocomplete.plugin.zsh"
autoload -Uz colors && colors

# Set command history settings
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=10000

PS1_USER=$'%{\e[30;46m%} %n [%T] %{\e[36;42m%}'
PS1_DIR=$'%{\e[30;42m%}%~ %{\e[0;32m%} %{\e[0m%}'
export PS1="${PS1_USER} ${PS1_DIR}"

export EDITOR=nvim
export PYDEVD_DISABLE_FILE_VALIDATION=1
export MOZ_ENABLE_WAYLAND=1
export PATH="${PATH}:${HOME}/.texlive/bin/x86_64-linux"
export JUPYTER_CONFIG_DIR="${HOME}/.python_venv/etc/jupyter"
export JUPYTER_DATA_DIR="${HOME}/.python_venv/share/jupyter"
export JUPYTER_RUNTIME_DIR="${HOME}/.python_venv/share/jupyter/runtime"
export IPYTHONDIR="${HOME}/.python_venv/etc/ipython"

alias ls='ls -l -A --color=auto --group-directories-first'
alias grep='grep --color=auto'
alias archupdate="yay -Syu --answerclean All --answerdiff None --removemake"
export PYTHON_VENV_BIN="${HOME}/.python_venv/bin"
alias jupyter="${PYTHON_VENV_BIN}/jupyter"
alias venvpip="${PYTHON_VENV_BIN}/pip --require-virtualenv"
alias yt-dlp-video="${PYTHON_VENV_BIN}/yt-dlp \
  -f \"bv*+ba/b\" --embed-thumbnail -o \"${HOME}/Downloads/%(title)s.%(ext)s\""
alias yt-dlp-music="${PYTHON_VENV_BIN}/yt-dlp \
  -f \"ba/b\" --embed-thumbnail -o \"${HOME}/Downloads/%(title)s.%(ext)s\""

# Turn off all beeps
unsetopt BEEP
