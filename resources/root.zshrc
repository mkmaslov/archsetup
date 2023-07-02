#!/bin/zsh

# Load zsh modules.
source ~/.zsh_plugins/zsh-autocomplete/zsh-autocomplete.plugin.zsh
autoload -Uz colors && colors

# Set command history settings
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=10000

export PS1=$'%{\e[30;41m%} %n [%T] %{\e[31;42m%}%{\e[30;42m%} %~ %{\e[0;32m%} %{\e[0m%}'

export EDITOR=nvim

alias ls='ls -A --color=auto --group-directories-first'
alias grep='grep --color=auto'

# Turn off all beeps
unsetopt BEEP
