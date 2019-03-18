#!/bin/bash

# TODO: we need tmux, make, git, autoconf, ncurses, pkgconfig, keychain, pathogen...

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
AUTOLOAD_DIR="$HOME/.vim/autoload"

if [ -d "$BUNDLE_DIR" ]
then
	rm -rf "$BUNDLE_DIR"
fi

if [ -d "$AUTOLOAD_DIR" ]
then
	rm -rf "$AUTOLOAD_DIR"
fi

mkdir -p "$AUTOLOAD_DIR" "$BUNDLE_DIR" && curl -LSso $HOME/.vim/autoload/pathogen.vim https://tpo.pe/pathogen.vim

echo -ne "execute pathogen#infect()\nsyntax on\nfiletype plugin indent on" > "$HOME/.vimrc"

git clone https://github.com/scrooloose/nerdtree.git "$BUNDLE_DIR/nerdtree"

git clone https://github.com/majutsushi/tagbar "$BUNDLE_DIR/tagbar"

git clone https://github.com/altercation/vim-colors-solarized "$BUNDLE_DIR/vim-colors-solarized"

echo -ne "\n\nsyntax enable\nset background=dark\ncolorscheme solarized\n\nset number" >> "$HOME/.vimrc"
