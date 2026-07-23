# ── History ──────────────────────────────────────────────────────────
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt SHARE_HISTORY          # sync across sessions
setopt HIST_IGNORE_ALL_DUPS   # remove older duplicates
setopt HIST_REDUCE_BLANKS     # trim whitespace
setopt HIST_IGNORE_SPACE      # prefix with space = private
setopt INC_APPEND_HISTORY     # write immediately, not on exit

# Compile sourced scripts once; later shells reuse the .zwc file.
function _zcompile_if_needed() {
  local file=$1
  local zwc="${file}.zwc"
  [[ -s "$file" ]] || return 1
  if [[ ! -s "$zwc" || "$file" -nt "$zwc" ]]; then
    zcompile "$file" 2>/dev/null || return 1
  fi
  return 0
}

function _source_compiled_if_present() {
  local file=$1
  [[ -f "$file" ]] || return 1
  _zcompile_if_needed "$file" || return 1
  source "$file"
}

# Cache generated shell init scripts so startup avoids repeated subprocesses.
function _source_cached_init() {
  local cmd_name=$1
  local cache_file=$2
  shift 2

  (( $+commands[$cmd_name] )) || return

  if [[ ! -s "$cache_file" || ${commands[$cmd_name]} -nt "$cache_file" ]]; then
    command "$cmd_name" "$@" >| "$cache_file"
  fi

  _zcompile_if_needed "$cache_file"
  source "$cache_file"
}

# Let compinit autoload bun completion instead of sourcing it every shell.
[[ -d "$HOME/.bun" ]] && fpath=("$HOME/.bun" $fpath)

# ── Completion (cached, rebuild once per day) ────────────────────────
autoload -Uz compinit
if [[ -n ~/.zcompdump(#qN.mh+24) ]]; then
  compinit -d ~/.zcompdump
else
  compinit -C -d ~/.zcompdump
fi
_zcompile_if_needed ~/.zcompdump

# Reuse Homebrew shellenv from ~/.zprofile instead of spawning brew on every shell.
BREW_PREFIX=${HOMEBREW_PREFIX:-/opt/homebrew}
FZF_TAB_SCRIPT=$BREW_PREFIX/opt/fzf-tab/share/fzf-tab/fzf-tab.zsh
ZSH_SYNTAX_HIGHLIGHTING_SCRIPT=$BREW_PREFIX/opt/zsh-syntax-highlighting/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
if [[ ! -f "$ZSH_SYNTAX_HIGHLIGHTING_SCRIPT" ]]; then
  ZSH_SYNTAX_HIGHLIGHTING_SCRIPT=$BREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi
if [[ ! -f "$ZSH_SYNTAX_HIGHLIGHTING_SCRIPT" ]]; then
  ZSH_SYNTAX_HIGHLIGHTING_SCRIPT=$BREW_PREFIX/opt/zsh-fast-syntax-highlighting/share/zsh-fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh
fi
ZSH_AUTOSUGGESTIONS_SCRIPT=$BREW_PREFIX/opt/zsh-autosuggestions/share/zsh-autosuggestions/zsh-autosuggestions.zsh

# ── fzf-tab (must be after compinit, before other plugins) ──────────
if _source_compiled_if_present "$FZF_TAB_SCRIPT"; then
  zstyle ':fzf-tab:*' fzf-flags --height=~50%
  zstyle ':fzf-tab:complete:cd:*' fzf-preview 'lsd --color=always $realpath'
  zstyle ':fzf-tab:complete:z:*' fzf-preview 'lsd --color=always $realpath'
  zstyle ':fzf-tab:complete:*:*' fzf-preview 'bat --color=always --line-range=:50 $realpath 2>/dev/null || lsd --color=always $realpath'
  zstyle ':completion:*:descriptions' format '[%d]'
fi

# ── Plugins ──────────────────────────────────────────────────────────
_source_compiled_if_present "$ZSH_SYNTAX_HIGHLIGHTING_SCRIPT"
_source_compiled_if_present "$ZSH_AUTOSUGGESTIONS_SCRIPT"

# ── Prompt (Starship) ───────────────────────────────────────────────
export STARSHIP_CONFIG=$HOME/.config/starship.toml
_source_cached_init starship "$HOME/.cache/starship-init.zsh" init zsh

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
_source_cached_init zoxide "$HOME/.cache/zoxide-init.zsh" init zsh

# ── Shell history (atuin) — fuzzy Ctrl-R, synced across sessions ─────
_source_cached_init atuin "$HOME/.cache/atuin-init.zsh" init zsh

# ── PATH (high priority → low priority) ──────────────────────────────
export GOPATH=$HOME/go
export ANDROID_HOME=/opt/homebrew/share/android-commandlinetools
export MISE_SHIMS_DIR=${MISE_SHIMS_DIR:-$HOME/.local/share/mise/shims}

path=(
    $HOME/.antigravity/antigravity/bin
    $HOME/.antigravity-ide/antigravity-ide/bin
    $HOME/.cargo/bin
    $HOME/.docker/bin
    $HOME/.dotfiles/scripts
    $HOME/.local/bin
    $HOME/.npm-global/bin
    $MISE_SHIMS_DIR
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
if (( $+commands[mise] )); then
  function mise() {
    unfunction mise
    _source_cached_init mise "$HOME/.cache/mise-init.zsh" activate zsh
    mise "$@"
  }
fi

# ── Lazy-load: wt (Windmill) ────────────────────────────────────────
function wt {
    unfunction wt
    eval "$(command wt config shell init zsh)"
    wt "$@"
}

# ── SDKMAN (java, etc.) ─────────────────────────────────────────────
SDKMAN_DIR="$BREW_PREFIX/opt/sdkman-cli/libexec"
[[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]] || SDKMAN_DIR="$HOME/.sdkman"
export SDKMAN_DIR
[[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]] && source "$SDKMAN_DIR/bin/sdkman-init.sh"

# ── Secrets ──────────────────────────────────────────────────────────
ENV_SECRETS_FILE=$HOME/.env.secrets
[[ -r $ENV_SECRETS_FILE && -s $ENV_SECRETS_FILE ]] && _source_compiled_if_present "$ENV_SECRETS_FILE"

# ── AsyncAPI autocomplete ────────────────────────────────────────────
ASYNCAPI_AC_ZSH_SETUP_PATH=$HOME/Library/Caches/@asyncapi/cli/autocomplete/zsh_setup
_source_compiled_if_present "$ASYNCAPI_AC_ZSH_SETUP_PATH"

export DYLD_LIBRARY_PATH=$HOME/lib

# ── tmux window name = repo / worktree branch ────────────────────────
# Cache a per-window tmux option (@win_name) read by automatic-rename-format
# (see tmux.conf). Linked worktree → branch (what's checked out); main repo
# → repo dir name; not a repo → empty (format falls back to the cwd basename).
# git-dir != git-common-dir is what distinguishes a linked worktree from the
# main checkout. Runs on dir change (covers `wt`) and each prompt.
if [[ -n $TMUX ]]; then
    autoload -Uz add-zsh-hook
    _tmux_win_name() {
        local name; local -a r
        r=("${(@f)$(git rev-parse --git-dir --git-common-dir --show-toplevel 2>/dev/null)}")
        if (( $#r >= 3 )); then
            if [[ ${r[1]} != ${r[2]} ]]; then
                name=$(git symbolic-ref --quiet --short HEAD 2>/dev/null) \
                    || name=$(git rev-parse --short HEAD 2>/dev/null)
            else
                name=${r[3]:t}
            fi
        fi
        tmux set-option -w -q "@win_name" "$name"
    }
    add-zsh-hook chpwd _tmux_win_name
    add-zsh-hook precmd _tmux_win_name
fi

# gib
export GIB_INSTALL=/Users/dozken/.gib
export PATH=/Users/dozken/.gib/bin:$PATH
