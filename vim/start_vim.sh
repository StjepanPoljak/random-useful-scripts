#!/bin/bash

SESSION_TAG=vim-stjepan
SESSION_NAME="Stjepan's vim"
SIDE_WINDOWS_SIZE=40

if ! [ "$1" = "--continue" ]
then
	tmux kill-session -t $SESSION_TAG
fi

tmux has-session -t $SESSION_TAG

if [ $? != 0 ]
then
	tmux new-session -s $SESSION_TAG -n "$SESSION_NAME" -d

	tmux split-window -v -t $SESSION_TAG:0

	tmux resize-pane -t $SESSION_TAG:0.1 -y 17

	tmux set mouse on

	tmux send-keys -t $SESSION_TAG:0.0 "vim -c \"set mouse=a\" -c NERDTree -c \"wincmd h\" -c \"vertical resize $SIDE_WINDOWS_SIZE\" -c TagbarToggle -c \"wincmd l\" -c \"wincmd l\" -c \"vertical resize $SIDE_WINDOWS_SIZE\" -c \"wincmd h\"" C-m
  
	if [ -f "/usr/bin/keychain" ] && [ -f "$HOME/.ssh/id_rsa" ]
  then
    tmux send-keys -t $SESSION_TAG:0.1 'keychain --eval --agents ssh id_rsa' C-m
  fi

	tmux select-pane -t $SESSION_TAG:0.0
fi

tmux attach -t $SESSION_TAG
