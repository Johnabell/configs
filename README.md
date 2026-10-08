# configs

Personal dotfiles for macOS and Linux (Coder workspaces).

Coder applies this repo by running `install.sh` at the root:

```bash
coder dotfiles --yes git@github.com:Johnabell/configs.git
```

Or locally:

```bash
./install.sh
```

## What it sets up

| Area           | How                                                                                                       |
| -------------- | --------------------------------------------------------------------------------------------------------- |
| Shell          | Oh My Zsh + tracked `zsh/` files symlinked into `$HOME`                                                   |
| Git            | `git/gitconfig` (aliases, editor); identity in `~/.gitconfig.local`                                       |
| Editor         | `nvim/` → `~/.config/nvim`                                                                                |
| Mac packages   | Homebrew `Brewfile`                                                                                       |
| Linux packages | `apt` via `packages-apt.txt` + release/npm installs matching the Brewfile — **no Homebrew**               |
| Rust tools     | `cargo-tools.txt` (nextest, llvm-cov, deny, expand, make, udeps, taplo, tokei)                            |
| LLM CLIs       | Cursor Agent (`curl https://cursor.com/install`), opencode                                                |
| Languages      | asdf + `.tool-versions` (nodejs, java, maven); rustup for Rust                                            |

### Brewfile ↔ Linux parity

| Tool | Mac | Linux |
|------|-----|-------|
| asdf, bat, cmake, curl, gnupg, jq, neovim, protobuf, ripgrep, tree | brew | apt (+ asdf clone) |
| gh, helm, k9s, skaffold, yq | brew | GitHub / official install scripts |
| ruff | brew | Astral install script |
| tree-sitter-cli (`tree-sitter`) | brew | GitHub release (npm fallback) |
| lua-language-server | brew | GitHub release |
| openapi-generator | brew | npm `@openapitools/openapi-generator-cli` (+ `openapi-generator` symlink) |
| opencode | brew tap | official install script |

Not installed: Flutter / Elixir / Haskell / Zig SDKs, private path crates (`pipeline-cli`, `cargo-sanitize`), GUI apps.

## First-time notes

1. **Symlinks replace** `~/.zshrc`, `~/.zshenv`, `~/.zprofile`, `~/.gitconfig`, and `~/.config/nvim`. Back up first if needed.
2. Put **secrets** in `~/.zshrc.local` (created as a stub). Examples: `CURSOR_API_KEY`, GitHub tokens, npm auth. Never commit that file.
3. Set git name/email in `~/.gitconfig.local`.
4. In nvim, run `:PackerSync` once to install plugins.
5. Cursor Agent: `agent login` or set `CURSOR_API_KEY`.

## Layout

```
install.sh           # entrypoint (Coder + local)
Brewfile             # macOS only
packages-apt.txt     # Linux apt packages
cargo-tools.txt      # cargo install list
.tool-versions       # asdf pins
zsh/                 # portable shell config
git/gitconfig
nvim/                # Neovim config
```

## Security

Do not put passwords or PATs in tracked shell files. If they previously lived in `~/.zshrc`, rotate them and move values to `~/.zshrc.local` or your secret store.
