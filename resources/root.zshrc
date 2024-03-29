#!/bin/zsh

# Load zsh modules.
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
autoload -Uz colors && colors

# Set command history settings
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=10000

PS1_USER=$'%{\e[30;41m%} %n [%T] %{\e[31;42m%}'
PS1_DIR=$'%{\e[30;42m%}%~ %{\e[0;32m%} %{\e[0m%}'
export PS1="${PS1_USER} ${PS1_DIR}"

alias ls='ls -l -A --color=auto --group-directories-first'
alias grep='grep --color=auto'

# Turn off all beeps
unsetopt BEEP
