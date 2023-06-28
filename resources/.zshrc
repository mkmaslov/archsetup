#!/bin/zsh

autoload -U colors && colors
autoload -U promptinit

# Autocompletion
zstyle ':autocomplete:*' groups always
zstyle ':autocomplete:list-choices:*' max-lines 40%
zstyle ':autocomplete:*' min-delay 0.05
zstyle ':autocomplete:*' ignored-input '..##'
zstyle ':completion:*' completer _complete _ignored _match _correct _approximate
zstyle ':completion:*' menu select=50 search

# Set command history settings
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=10000

export PS1=$'%{\033[1m%}%{\033[38;2;0;0;0;48;2;166;189;219m%} %n [%T] %{\033[38;2;166;189;219;48;2;56;108;176m%}%{\033[38;2;215;215;215;48;2;56;108;176m%} %~ %{\033[0m%}%{\033[38;2;56;108;176m%} %{\033[0m%}'

export PYDEVD_DISABLE_FILE_VALIDATION=1
export MOZ_ENABLE_WAYLAND=1
export JUPYTER_CONFIG_DIR="${HOME}/.python_venv/etc/jupyter"
export JUPYTER_DATA_DIR="${HOME}/.python_venv/share/jupyter"
export JUPYTER_RUNTIME_DIR="${HOME}/.python_venv/share/jupyter/runtime"

alias ls='ls --color=auto --group-directories-first'
alias grep='grep --color=auto'

# Turn off all beeps
unsetopt BEEP
