#!/bin/zsh
emulate -L zsh
setopt err_exit
#setopt xtrace

typeset NEW="nohup.out"
typeset OLD="$NEW.1"

cd "$HOME"/ibutton2uid
cp "$NEW" "$OLD"
printf "" > "$NEW"
gzip -f "$OLD"
