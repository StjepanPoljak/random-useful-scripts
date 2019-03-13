#!/bin/bash

VIM_INSTALL_DIR="$HOME/vim-install"

if ! [ -d "$VIM_INSTALL_DIR" ]
then
	mkdir "$VIM_INSTALL_DIR"
fi

cd "$VIM_INSTALL_DIR"

git clone https://github.com/vim/vim

cd vim

make
make install

git clone https://github.com/universal-ctags/ctags "$VIM_INSTALL_DIR/ctags"

cd "$VIM_INSTALL_DIR/ctags"

./autogen.sh
./configure
make
make install

cd "$HOME"

if [ -d "$VIM_INSTALL_DIR" ]
then
	rm -rf "$VIM_INSTALL_DIR"
fi

BUNDLE_DIR="$HOME/.vim/bundle"

git clone https://github.com/scrooloose/nerdtree.git "$BUNDLE_DIR/nerdtree"

git clone https://github.com/majutsushi/tagbar "$BUNDLE_DIR/tagbar"

git clone https://github.com/altercation/vim-colors-solarized "$BUNDLE_DIR/vim-colors-solarized"

echo "syntax enable\nset background=dark\ncolorscheme solarized\n\nset number" > "$HOME/.vimrc"
