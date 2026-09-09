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

echo "==> Linking kitty config"
backup_and_link "$DOTFILES/kitty/kitty.conf" "$HOME/.config/kitty/kitty.conf"

echo "==> Sourcing bash functions"
if ! grep -qF "dotfiles/bash/functions.sh" "$HOME/.bashrc" 2>/dev/null; then
    echo "source \"$DOTFILES/bash/functions.sh\"" >> "$HOME/.bashrc"
    echo "  added to ~/.bashrc"
else
    echo "  already in ~/.bashrc"
fi

echo "==> Linking Claude Code config"
mkdir -p "$HOME/.claude/commands"
for cmd in "$DOTFILES"/claude/commands/*.md; do
    [ -e "$cmd" ] || continue
    backup_and_link "$cmd" "$HOME/.claude/commands/$(basename "$cmd")"
done
if [ -d "$DOTFILES/claude/skills" ]; then
    mkdir -p "$HOME/.claude/skills"
    for skill in "$DOTFILES"/claude/skills/*/; do
        [ -d "$skill" ] || continue
        name="$(basename "${skill%/}")"
        dest="$HOME/.claude/skills/$name"
        # Back up OUTSIDE ~/.claude/skills: a *.bak left in place is still a
        # valid skill directory, and Claude Code loads it as a second, stale
        # copy of the same skill.
        if [ -e "$dest" ] && [ ! -L "$dest" ]; then
            mkdir -p "$HOME/.claude/skill-backups"
            mv "$dest" "$HOME/.claude/skill-backups/$name.$(date +%Y%m%d%H%M%S)"
            echo "  backed up existing $name → ~/.claude/skill-backups/"
        fi
        ln -sfn "${skill%/}" "$dest"
        echo "  linked $dest"
    done
fi

echo "==> Cluster-specific setup"
# Deliberately not tracked in git: partitions, module preludes and per-workflow
# resources differ per cluster. `espresso cluster config` regenerates them, and
# the project conventions are templated rather than copied so $WORK can differ.
if [ -n "$WORK" ] && [ -d "$WORK" ]; then
    if [ ! -e "$WORK/CLAUDE.md" ]; then
        cp "$DOTFILES/claude/WORK-CLAUDE.md.template" "$WORK/CLAUDE.md"
        echo "  wrote $WORK/CLAUDE.md"
    else
        echo "  $WORK/CLAUDE.md exists, left alone"
    fi
else
    echo "  \$WORK unset or missing; skipping project conventions"
    echo "  set \$WORK, then: cp $DOTFILES/claude/WORK-CLAUDE.md.template \$WORK/CLAUDE.md"
fi
if [ ! -f "$HOME/.config/espresso/espresso-cluster.json" ]; then
    echo "  no espresso cluster config; run: espresso cluster config"
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
