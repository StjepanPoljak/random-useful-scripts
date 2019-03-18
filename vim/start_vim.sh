#!/bin/bash

SESSION_TAG=vim-epljstj
SESSION_NAME="EPLJSTJ's vim"
SIDE_WINDOWS_SIZE=40

if ! [ "$1" = "--continue" ]
then
	tmux kill-session -t $SESSION_TAG
fi

tmux has-session -t $SESSION_TAG

if [ $? != 0 ]
then
	tmux new-session -s $SESSION_TAG -n "$SESSION_NAME" -d -x "$(tput cols)" -y "$(tput lines)"

	tmux split-window -v -t $SESSION_TAG:0

	tmux set mouse on

	tmux send-keys -t $SESSION_TAG:0.1 'keychain --eval --agents ssh id_rsa' C-m

	tmux send-keys -t $SESSION_TAG:0.0 "sleep 1; vim -c \"set mouse=a\" -c NERDTree -c \"wincmd h\" -c \"vertical resize $SIDE_WINDOWS_SIZE\" -c \"wincmd l\" -c TagbarToggle -c \"wincmd l\" -c \"vertical resize $SIDE_WINDOWS_SIZE\" -c \"wincmd h\"" C-m

	tmux select-pane -t $SESSION_TAG:0.0

	tmux resize-pane -t $SESSION_TAG:0.1 -D 15
fi

tmux attach -t $SESSION_TAG
