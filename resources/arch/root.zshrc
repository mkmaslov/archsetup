#!/bin/zsh

# Enable colors
autoload -Uz colors && colors

# Set command history settings
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=10000

# Set custom prompt
PS1_USER="%F{000}%K{009} %n [%T] %F{009}%K{010}"
PS1_DIR="%F{000}%K{010}%~ %F{010}%K{reset_color}%F{reset_color} "
export PS1="${PS1_USER} ${PS1_DIR}"

# Set shortcuts for CLI commands
alias ls='ls -l -A --color=auto --group-directories-first'
alias grep='grep --color=auto'

# Turn off all beeps
unsetopt BEEP

# Load zsh modules.
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh