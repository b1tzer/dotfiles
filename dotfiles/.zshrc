# =============================================================================
# .zshrc - Common Zsh configuration (all platforms)
# Managed by dotfiles repo. Edit here, changes auto-reflect via symlink.
# =============================================================================

# Oh My Zsh
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME=""  # Using starship prompt instead

plugins=(
  git
  docker
  fzf
  zsh-autosuggestions
  zsh-syntax-highlighting
  z
)

source $ZSH/oh-my-zsh.sh

# Starship prompt
if command -v starship &>/dev/null; then
  eval "$(starship init zsh)"
fi

# ---------------------------------------------------------------------------
# Environment variables
# ---------------------------------------------------------------------------
export EDITOR=vim
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Load local secrets (not committed to git)
if [ -f "$HOME/.secrets.local.env" ]; then
  set -a
  source "$HOME/.secrets.local.env"
  set +a
fi

# ---------------------------------------------------------------------------
# Path additions
# ---------------------------------------------------------------------------
# nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && source "$NVM_DIR/bash_completion"

# pyenv
if command -v pyenv &>/dev/null; then
  export PYENV_ROOT="$HOME/.pyenv"
  export PATH="$PYENV_ROOT/bin:$PATH"
  eval "$(pyenv init -)"
fi

# Local bin
export PATH="$HOME/.local/bin:$PATH"

# ---------------------------------------------------------------------------
# Aliases - Common
# ---------------------------------------------------------------------------
alias ll='ls -lah'
alias la='ls -A'
alias ..='cd ..'
alias ...='cd ../..'
alias grep='grep --color=auto'
alias df='df -h'
alias du='du -h'

# Use eza if available, fallback to ls
if command -v eza &>/dev/null; then
  alias ls='eza --icons'
  alias ll='eza -lah --icons'
  alias lt='eza --tree --icons'
elif command -v exa &>/dev/null; then
  alias ls='exa'
  alias ll='exa -lah'
fi

# Use bat if available
if command -v bat &>/dev/null; then
  alias cat='bat --paging=never'
fi

# Use ripgrep if available
if command -v rg &>/dev/null; then
  alias grep='rg'
fi

# Git shortcuts
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git pull'
alias glog='git log --oneline --graph --decorate --all'

# Docker shortcuts
alias dps='docker ps'
alias dpa='docker ps -a'
alias di='docker images'
alias dex='docker exec -it'

# ---------------------------------------------------------------------------
# fzf integration
# ---------------------------------------------------------------------------
if command -v fzf &>/dev/null; then
  [ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
  export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'
  if command -v rg &>/dev/null; then
    export FZF_DEFAULT_COMMAND='rg --files --hidden --follow --glob "!.git"'
  fi
fi

# ---------------------------------------------------------------------------
# Load platform-specific config
# ---------------------------------------------------------------------------
DOTFILES_DIR="$(dirname "$(readlink -f "${(%):-%x}")")"
case "$(uname -s)" in
  Darwin)
    [ -f "$DOTFILES_DIR/.zshrc.macos" ] && source "$DOTFILES_DIR/.zshrc.macos"
    ;;
  Linux)
    [ -f "$DOTFILES_DIR/.zshrc.ubuntu" ] && source "$DOTFILES_DIR/.zshrc.ubuntu"
    ;;
esac
