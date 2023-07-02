#!/bin/zsh

# Load zsh modules.
source ~/.zsh_plugins/zsh-autocomplete/zsh-autocomplete.plugin.zsh
autoload -Uz colors && colors

# Set command history settings
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=10000

export PS1=$'%{\e[30;46m%} %n [%T] %{\e[36;42m%}%{\e[30;42m%} %~ %{\e[0;32m%} %{\e[0m%}'

export EDITOR=nvim
export PYDEVD_DISABLE_FILE_VALIDATION=1
export MOZ_ENABLE_WAYLAND=1
export JUPYTER_CONFIG_DIR="${HOME}/.python_venv/etc/jupyter"
export JUPYTER_DATA_DIR="${HOME}/.python_venv/share/jupyter"
export JUPYTER_RUNTIME_DIR="${HOME}/.python_venv/share/jupyter/runtime"

alias ls='ls -A --color=auto --group-directories-first'
alias grep='grep --color=auto'
alias archupdate='yay -Syu --answerclean All --answerdiff None'
alias jupyter="${HOME}/.python_venv/bin/jupyter"
alias venvpip="${HOME}/.python_venv/bin/pip --require-virtualenv"

# Turn off all beeps
unsetopt BEEP
