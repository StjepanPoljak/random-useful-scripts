#!/bin/bash

HEADER_CHECK='###stjepan-hack###'

if ! [ -f ~/.bash_profile ]
then
	echo "(i) Creating ~/.bash_profile file..."
	touch ~/.bash_profile
fi

grep "$HEADER_CHECK" ~/.bash_profile > /dev/null

if [ $? -ne 0 ]
then
	echo "(i) Hacking ~/.bash_profile file..."
	echo "" >> ~/.bash_profile
	echo "$HEADER_CHECK" >> ~/.bash_profile
	echo "parse_git_branch() {" >> ~/.bash_profile
	echo -ne "\t" >> ~/.bash_profile
	echo "git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ (\1)/'" >> ~/.bash_profile
	echo "}" >> ~/.bash_profile
	echo 'PS1="\u@\h:\w\$(error=\$?; test=\$(parse_git_branch); if ! [ -z \"\$test\" ]; then echo -n \"\$test\"; fi; if [ \$error -ne 0 ]; then echo -ne \" \033[1m(\$error)\033[0m\"; fi)$ "' >> ~/.bash_profile

fi

if ! [ -f ~/.bashrc ]
then
	echo "(!) Creating ~/.bashrc file..."
	touch ~/.bashrc
fi

grep "source ~/.bash_profile" ~/.bashrc > /dev/null

if [ $? -ne 0 ]
then
	echo "(i) Hacking ~/.bashrc file..."
	echo "source ~/.bash_profile" >> ~/.bashrc
fi

exit 0
