# ── History ──────────────────────────────────────────────────────────
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt SHARE_HISTORY          # sync across sessions
setopt HIST_IGNORE_ALL_DUPS   # remove older duplicates
setopt HIST_REDUCE_BLANKS     # trim whitespace
setopt HIST_IGNORE_SPACE      # prefix with space = private
setopt INC_APPEND_HISTORY     # write immediately, not on exit

# ── Completion (cached, rebuild once per day) ────────────────────────
autoload -Uz compinit
if [[ -n ~/.zcompdump(#qN.mh+24) ]]; then
  compinit
else
  compinit -C
fi

# Cache brew prefix to avoid repeated slow calls
BREW_PREFIX=$(brew --prefix)

# ── fzf-tab (must be after compinit, before other plugins) ──────────
if [[ -d "$BREW_PREFIX/opt/fzf-tab" ]]; then
  source "$BREW_PREFIX/opt/fzf-tab/share/fzf-tab/fzf-tab.zsh"
  zstyle ':fzf-tab:*' fzf-flags --height=~50%
  zstyle ':fzf-tab:complete:cd:*' fzf-preview 'lsd --color=always $realpath'
  zstyle ':fzf-tab:complete:z:*' fzf-preview 'lsd --color=always $realpath'
  zstyle ':fzf-tab:complete:*:*' fzf-preview 'bat --color=always --line-range=:50 $realpath 2>/dev/null || lsd --color=always $realpath'
  zstyle ':completion:*:descriptions' format '[%d]'
fi

# ── Plugins ──────────────────────────────────────────────────────────
[[ -f "$BREW_PREFIX/opt/zsh-fast-syntax-highlighting/share/zsh-fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh" ]] && \
    source "$BREW_PREFIX/opt/zsh-fast-syntax-highlighting/share/zsh-fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh"

[[ -f "$BREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]] && \
    source "$BREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh"

command -v atuin >/dev/null && eval "$(atuin init zsh)"

# ── Prompt (Starship) ───────────────────────────────────────────────
eval "$(starship init zsh)"

# ── OLD PROMPT (robbyrussell recreation) ─────────────────────────────
# Uncomment below and comment out the starship line above to revert:
# autoload -Uz vcs_info
# precmd() { vcs_info }
# zstyle ':vcs_info:git:*' actionformats '%F{blue}git:(%F{red}%b|%a%F{blue})%f '
# zstyle ':vcs_info:*' check-for-changes true
# zstyle ':vcs_info:*' unstagedstr ' %F{yellow}●%f'
# zstyle ':vcs_info:git:*' formats '%F{blue}git:(%F{red}%b%F{blue})%f%u '
# setopt PROMPT_SUBST
# PROMPT='%(?:%B%F{green}➜%f%b :%B%F{red}➜%f%b ) %F{cyan}%c%f ${vcs_info_msg_0_}'

# ── Smart cd (zoxide) ───────────────────────────────────────────────
eval "$(zoxide init zsh)"

# ── PATH (high priority → low priority) ──────────────────────────────
export GOPATH=$HOME/go
export ANDROID_HOME=/opt/homebrew/share/android-commandlinetools

path=(
    $HOME/.antigravity/antigravity/bin
    $HOME/.cargo/bin
    $HOME/.docker/bin
    $HOME/.npm-global/bin
    $HOME/work/prince/bin
    $path
    $GOPATH/bin
    $HOME/.bun/bin
    $HOME/.maestro/bin
    $ANDROID_HOME/cmdline-tools/latest/bin
    $ANDROID_HOME/platform-tools
)
typeset -U path  # deduplicate

# ── Aliases ──────────────────────────────────────────────────────────
alias v="nvim"
alias ts="tailscale --socket=\$HOME/.local/share/tailscale/tailscaled.sock"
alias tsd="tailscaled --tun=userspace-networking --state=\$HOME/.local/share/tailscale/tailscaled.state --socket=\$HOME/.local/share/tailscale/tailscaled.sock"
alias ls="lsd"
alias l='ls -l'
alias la="ls -l --git -a"
alias lt="ls --tree --depth=2 --long --git"
alias docker-compose="docker compose"
alias grep="rg"

# ── Keybindings ──────────────────────────────────────────────────────
if [[ -o interactive ]]; then
    function run_tmux_sessionizer() {
        BUFFER='tmux new $HOME/.config/tmux/scripts/tmux-sessionizer'
        zle accept-line
    }
    zle -N run_tmux_sessionizer
    bindkey '^f' run_tmux_sessionizer
fi

# ── mise (node, java, and more) ─────────────────────────────────────
eval "$(mise activate zsh)"

# ── Lazy-load: wt (Windmill) ────────────────────────────────────────
function wt {
    unfunction wt
    eval "$(command wt config shell init zsh)"
    wt "$@"
}

# ── Secrets ──────────────────────────────────────────────────────────
[[ -f ~/.env.secrets ]] && source ~/.env.secrets

# ── AsyncAPI autocomplete ────────────────────────────────────────────
ASYNCAPI_AC_ZSH_SETUP_PATH=$HOME/Library/Caches/@asyncapi/cli/autocomplete/zsh_setup
[[ -f $ASYNCAPI_AC_ZSH_SETUP_PATH ]] && source $ASYNCAPI_AC_ZSH_SETUP_PATH
export DYLD_LIBRARY_PATH=$HOME/lib
