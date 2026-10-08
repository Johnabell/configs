#!/usr/bin/env bash
# Coder / local bootstrap for this configs repo.
# macOS and Linux: Homebrew + Brewfile, then shared cargo/asdf/shell setup.
set -u

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OS="$(uname -s)"
ARCH="$(uname -m)"
LOG_PREFIX="[configs]"

log() { printf '%s %s\n' "$LOG_PREFIX" "$*"; }
warn() { printf '%s WARN: %s\n' "$LOG_PREFIX" "$*" >&2; }

have() { command -v "$1" >/dev/null 2>&1; }

link_file() {
  local src="$1"
  local dest="$2"
  mkdir -p "$(dirname "$dest")"
  if [[ -e "$dest" || -L "$dest" ]]; then
    local current
    current="$(readlink "$dest" 2>/dev/null || true)"
    if [[ "$current" == "$src" ]]; then
      log "already linked $dest"
      return 0
    fi
    if [[ ! -L "$dest" ]]; then
      local bak="${dest}.pre-configs.bak"
      if [[ ! -e "$bak" ]]; then
        mv "$dest" "$bak"
        log "backed up $dest -> $bak"
      else
        rm -f "$dest"
      fi
    else
      rm -f "$dest"
    fi
  fi
  ln -sfn "$src" "$dest"
  log "linked $dest -> $src"
}

# Put brew on PATH for this script (and future shells via zprofile)
eval_brew_shellenv() {
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  elif [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  elif have brew; then
    eval "$(brew shellenv)"
  fi
}

# Homebrew on Linux needs a compiler toolchain before brew itself is useful
ensure_linux_brew_deps() {
  [[ "$OS" == "Linux" ]] || return 0
  have apt-get || return 0

  local need=()
  local pkg
  for pkg in build-essential curl file git procps; do
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then
      need+=("$pkg")
    fi
  done
  [[ ${#need[@]} -eq 0 ]] && return 0

  log "installing Homebrew prerequisites: ${need[*]}"
  if have sudo; then
    sudo apt-get update -y || warn "apt-get update failed"
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${need[@]+"${need[@]}"}" || warn "apt prerequisite install failed"
  else
    apt-get update -y || warn "apt-get update failed"
    DEBIAN_FRONTEND=noninteractive apt-get install -y "${need[@]+"${need[@]}"}" || warn "apt prerequisite install failed"
  fi
}

ensure_homebrew() {
  eval_brew_shellenv
  if have brew; then
    log "Homebrew already present ($(command -v brew))"
    return 0
  fi

  ensure_linux_brew_deps

  log "installing Homebrew"
  NONINTERACTIVE=1 CI=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || {
    warn "Homebrew install failed"
    return 0
  }
  eval_brew_shellenv
  if ! have brew; then
    warn "brew still not on PATH after install"
    return 0
  fi
  log "Homebrew installed ($(command -v brew))"
}

install_brew_packages() {
  ensure_homebrew
  if ! have brew; then
    warn "skipping brew bundle (brew unavailable)"
    return 0
  fi
  log "brew bundle --file=$REPO_DIR/Brewfile"
  brew bundle --file="$REPO_DIR/Brewfile" || warn "brew bundle reported errors (continuing)"
}

ensure_oh_my_zsh() {
  if [[ -d "$HOME/.oh-my-zsh" ]]; then
    log "oh-my-zsh already present"
    return 0
  fi
  log "installing oh-my-zsh"
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" || {
      warn "oh-my-zsh install failed"
      return 0
    }
}

ensure_rustup() {
  if have rustc && have cargo; then
    log "rust/cargo already present"
    return 0
  fi
  if [[ -f "$HOME/.cargo/env" ]]; then
    # shellcheck disable=SC1091
    . "$HOME/.cargo/env"
  fi
  if have rustc && have cargo; then
    return 0
  fi
  log "installing rustup"
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y || {
    warn "rustup install failed"
    return 0
  }
  # shellcheck disable=SC1091
  . "$HOME/.cargo/env"
}

install_cargo_tools() {
  ensure_rustup
  if ! have cargo; then
    warn "cargo unavailable; skipping cargo tools"
    return 0
  fi

  rustup component add rustfmt clippy llvm-tools-preview 2>/dev/null || true
  rustup component add rust-analyzer 2>/dev/null || true

  local crate bin
  while IFS= read -r crate || [[ -n "$crate" ]]; do
    case "$crate" in
      ''|\#*) continue ;;
    esac
    bin="$crate"
    case "$crate" in
      taplo-cli) bin=taplo ;;
    esac
    if have "$bin" || [[ -x "$HOME/.cargo/bin/$bin" ]]; then
      log "cargo tool already present: $crate"
      continue
    fi
    log "cargo install $crate"
    if have cargo-binstall; then
      cargo binstall -y "$crate" 2>/dev/null || cargo install "$crate" --locked 2>/dev/null || cargo install "$crate" || warn "failed: $crate"
    else
      cargo install "$crate" --locked 2>/dev/null || cargo install "$crate" || warn "failed: $crate"
    fi
  done <"$REPO_DIR/cargo-tools.txt"
}

ensure_asdf() {
  # Prefer brew-installed asdf from Brewfile; fall back to git clone
  if have asdf || [[ -x "$HOME/.asdf/bin/asdf" ]]; then
    log "asdf already present"
  else
    log "installing asdf (git clone fallback)"
    git clone https://github.com/asdf-vm/asdf.git "$HOME/.asdf" --branch v0.15.0 || {
      warn "asdf clone failed"
      return 0
    }
  fi

  # shellcheck disable=SC1091
  if [[ -f "$HOME/.asdf/asdf.sh" ]]; then
    . "$HOME/.asdf/asdf.sh"
  fi
  export PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:${ASDF_DATA_DIR:-$HOME/.asdf}/bin:$PATH"

  if ! have asdf; then
    warn "asdf not on PATH after install"
    return 0
  fi

  local plugin
  for plugin in nodejs java maven; do
    if asdf plugin list 2>/dev/null | grep -qx "$plugin"; then
      log "asdf plugin present: $plugin"
    else
      log "adding asdf plugin: $plugin"
      case "$plugin" in
        java) asdf plugin add java https://github.com/halcyon/asdf-java.git || warn "plugin add failed: java" ;;
        *) asdf plugin add "$plugin" || warn "plugin add failed: $plugin" ;;
      esac
    fi
  done

  if [[ -f "$REPO_DIR/.tool-versions" ]]; then
    log "asdf install from .tool-versions"
    (
      cd "$REPO_DIR" || exit 0
      asdf install || warn "asdf install had errors"
    )
    if [[ ! -f "$HOME/.tool-versions" ]]; then
      cp "$REPO_DIR/.tool-versions" "$HOME/.tool-versions"
      log "copied .tool-versions to \$HOME"
    fi
  fi
}

install_cursor_agent() {
  if have agent || have cursor-agent; then
    log "cursor agent already present"
    return 0
  fi
  log "installing Cursor Agent CLI"
  curl https://cursor.com/install -fsS | bash || warn "Cursor Agent install failed"
}

link_dotfiles() {
  link_file "$REPO_DIR/zsh/zshrc" "$HOME/.zshrc"
  link_file "$REPO_DIR/zsh/zshenv" "$HOME/.zshenv"
  link_file "$REPO_DIR/zsh/zprofile" "$HOME/.zprofile"
  link_file "$REPO_DIR/git/gitconfig" "$HOME/.gitconfig"
  mkdir -p "$HOME/.config"
  link_file "$REPO_DIR/nvim" "$HOME/.config/nvim"

  if [[ ! -f "$HOME/.gitconfig.local" ]]; then
    cat >"$HOME/.gitconfig.local" <<'EOF'
# Local git identity — edit me (not tracked in the configs repo)
# [user]
# 	name = Your Name
# 	email = you@example.com
EOF
    log "created ~/.gitconfig.local stub — set your name/email there"
  fi
}

main() {
  log "repo=$REPO_DIR os=$OS arch=$ARCH"

  mkdir -p "$HOME/.local/bin"
  export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

  install_brew_packages
  install_cargo_tools
  install_cursor_agent
  ensure_asdf
  ensure_oh_my_zsh
  link_dotfiles

  log "done. Open a new shell. First nvim launch: run :PackerSync"
  log "Put secrets in ~/.zshrc.local (never commit them)."
  if [[ ! -f "$HOME/.zshrc.local" ]]; then
    cat >"$HOME/.zshrc.local" <<'EOF'
# Machine-local env (secrets, tokens). Not managed by the configs repo.
# export CURSOR_API_KEY=...
# export GITHUB_ACCESS_TOKEN=...
EOF
    log "created ~/.zshrc.local stub"
  fi
}

main "$@"
exit 0
