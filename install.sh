#!/usr/bin/env bash
# Coder / local bootstrap for this configs repo.
# Darwin: Homebrew + Brewfile. Linux: apt + release binaries (no Homebrew).
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

install_mac_packages() {
  if ! have brew; then
    warn "Homebrew not found; install from https://brew.sh then re-run"
    return 0
  fi
  log "brew bundle"
  brew bundle --file="$REPO_DIR/Brewfile" || warn "brew bundle reported errors (continuing)"
}

install_linux_apt() {
  if ! have apt-get; then
    warn "apt-get not found; skipping apt packages"
    return 0
  fi
  local pkgs=()
  local pkg
  while IFS= read -r pkg || [[ -n "$pkg" ]]; do
    case "$pkg" in
      ''|\#*) continue ;;
    esac
    pkgs+=("$pkg")
  done <"$REPO_DIR/packages-apt.txt"

  if [[ ${#pkgs[@]} -eq 0 ]]; then
    return 0
  fi

  log "apt-get update + install (${#pkgs[@]} packages)"
  if have sudo; then
    sudo apt-get update -y || warn "apt-get update failed"
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${pkgs[@]+"${pkgs[@]}"}" || warn "apt-get install failed"
  else
    apt-get update -y || warn "apt-get update failed"
    DEBIAN_FRONTEND=noninteractive apt-get install -y "${pkgs[@]+"${pkgs[@]}"}" || warn "apt-get install failed"
  fi

  # Debian/Ubuntu often ship bat as batcat
  if ! have bat && have batcat; then
    mkdir -p "$HOME/.local/bin"
    ln -sfn "$(command -v batcat)" "$HOME/.local/bin/bat"
    log "symlinked bat -> batcat"
  fi
}

github_latest_asset_url() {
  # Args: owner/repo regex_for_asset_name
  local repo="$1"
  local pattern="$2"
  curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" \
    | grep -oE "https://[^\"]+/download/[^\"]+" \
    | grep -E "$pattern" \
    | head -n1
}

install_binary_from_url() {
  local name="$1"
  local url="$2"
  local dest="$HOME/.local/bin/$name"
  if have "$name"; then
    log "$name already on PATH"
    return 0
  fi
  if [[ -z "$url" ]]; then
    warn "no download URL for $name"
    return 0
  fi
  mkdir -p "$HOME/.local/bin"
  local tmp
  tmp="$(mktemp -d)"
  log "installing $name from $url"
  if [[ "$url" == *.tar.gz ]] || [[ "$url" == *.tgz ]]; then
    curl -fsSL "$url" | tar -xz -C "$tmp" || { warn "extract failed: $name"; rm -rf "$tmp"; return 0; }
    local found
    found="$(find "$tmp" -type f -name "$name" | head -n1)"
    if [[ -n "$found" ]]; then
      install -m 0755 "$found" "$dest"
    else
      warn "could not find $name in archive"
    fi
  elif [[ "$url" == *.zip ]]; then
    curl -fsSL "$url" -o "$tmp/asset.zip" || { warn "download failed: $name"; rm -rf "$tmp"; return 0; }
    unzip -q "$tmp/asset.zip" -d "$tmp" || true
    found="$(find "$tmp" -type f -name "$name" | head -n1)"
    if [[ -n "$found" ]]; then
      install -m 0755 "$found" "$dest"
    else
      warn "could not find $name in zip"
    fi
  else
    curl -fsSL "$url" -o "$dest" && chmod +x "$dest" || warn "download failed: $name"
  fi
  rm -rf "$tmp"
}

linux_arch_tag() {
  case "$ARCH" in
    x86_64|amd64) echo "amd64" ;;
    aarch64|arm64) echo "arm64" ;;
    *) echo "$ARCH" ;;
  esac
}

install_linux_extras() {
  local a
  a="$(linux_arch_tag)"

  # k9s
  if ! have k9s; then
    local url
    url="$(github_latest_asset_url "derailed/k9s" "k9s_Linux_${a}\\.tar\\.gz")"
    # fallback naming used by some releases
    if [[ -z "$url" ]]; then
      url="$(github_latest_asset_url "derailed/k9s" "k9s_Linux_.*${a}.*\\.tar\\.gz")"
    fi
    install_binary_from_url "k9s" "$url"
  else
    log "k9s already present"
  fi

  # yq
  if ! have yq; then
    local yq_arch="$a"
    [[ "$yq_arch" == "amd64" ]] && yq_arch="amd64"
    [[ "$ARCH" == "x86_64" ]] && yq_arch="amd64"
    [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]] && yq_arch="arm64"
    local yq_url
    yq_url="$(github_latest_asset_url "mikefarah/yq" "yq_linux_${yq_arch}\$")"
    install_binary_from_url "yq" "$yq_url"
  else
    log "yq already present"
  fi

  # gh
  if ! have gh; then
    local gh_url
    gh_url="$(github_latest_asset_url "cli/cli" "gh_.*_linux_${a}\\.tar\\.gz")"
    install_binary_from_url "gh" "$gh_url"
  else
    log "gh already present"
  fi

  # helm
  if ! have helm; then
    log "installing helm"
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash || warn "helm install failed"
  else
    log "helm already present"
  fi

  # skaffold
  if ! have skaffold; then
    local sk_url="https://storage.googleapis.com/skaffold/releases/latest/skaffold-linux-${a}"
    install_binary_from_url "skaffold" "$sk_url"
  else
    log "skaffold already present"
  fi

  # opencode — try common install script / npm-free binary
  if ! have opencode && ! have opencode-v2; then
    log "installing opencode"
    if curl -fsSL https://opencode.ai/install 2>/dev/null | bash; then
      log "opencode install script finished"
    else
      warn "opencode auto-install failed; install manually from https://opencode.ai"
    fi
  else
    log "opencode already present"
  fi
}

ensure_asdf() {
  if have asdf || [[ -x "$HOME/.asdf/bin/asdf" ]]; then
    log "asdf already present"
  else
    log "installing asdf"
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
    # Also place a copy in HOME so shims resolve outside the repo
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

  case "$OS" in
    Darwin)
      install_mac_packages
      ;;
    Linux)
      install_linux_apt
      install_linux_extras
      ;;
    *)
      warn "unsupported OS: $OS (continuing with portable steps)"
      ;;
  esac

  mkdir -p "$HOME/.local/bin"
  export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

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
