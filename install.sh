#!/usr/bin/env bash
set -e

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

backup_and_link() {
    local src="$1"
    local dest="$2"
    mkdir -p "$(dirname "$dest")"
    if [ -e "$dest" ] && [ ! -L "$dest" ]; then
        echo "  backing up existing $dest → $dest.bak"
        mv "$dest" "$dest.bak"
    fi
    ln -sf "$src" "$dest"
    echo "  linked $dest"
}

echo "==> Linking vim config"
backup_and_link "$DOTFILES/vim/.vimrc"                   "$HOME/.vimrc"
backup_and_link "$DOTFILES/vim/UltiSnips/tex.snippets"   "$HOME/.vim/UltiSnips/tex.snippets"
backup_and_link "$DOTFILES/vim/colors/molokai.vim"        "$HOME/.vim/colors/molokai.vim"

echo "==> Linking tmux config"
backup_and_link "$DOTFILES/tmux/.tmux.conf" "$HOME/.tmux.conf"

echo "==> Sourcing bash functions"
if ! grep -qF "dotfiles/bash/functions.sh" "$HOME/.bashrc" 2>/dev/null; then
    echo "source \"$DOTFILES/bash/functions.sh\"" >> "$HOME/.bashrc"
    echo "  added to ~/.bashrc"
else
    echo "  already in ~/.bashrc"
fi

echo "==> Installing vim-plug"
if [ ! -f "$HOME/.vim/autoload/plug.vim" ]; then
    curl -fLo "$HOME/.vim/autoload/plug.vim" --create-dirs \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
    echo "  vim-plug installed"
else
    echo "  vim-plug already present"
fi

echo ""
echo "==> Done. Open vim and run :PlugInstall to install plugins."
echo ""
echo "    YouCompleteMe needs a one-time compile after :PlugInstall:"
echo "    cd ~/.vim/plugged/YouCompleteMe && python3 install.py --clangd-completer"
echo ""
echo "    fzf binary is auto-installed by :PlugInstall via fzf#install()."
