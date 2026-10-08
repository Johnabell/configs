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

| Area       | How                                                                            |
| ---------- | ------------------------------------------------------------------------------ |
| Shell      | Oh My Zsh + tracked `zsh/` files symlinked into `$HOME`                        |
| Git        | `git/gitconfig` (aliases, editor); identity in `~/.gitconfig.local`            |
| Editor     | `nvim/` → `~/.config/nvim`                                                     |
| CLI tools  | Homebrew + shared `Brewfile` on **both** macOS and Linux                       |
| Rust tools | `cargo-tools.txt` (nextest, llvm-cov, deny, expand, make, udeps, taplo, tokei) |
| LLM CLIs   | Cursor Agent (`curl https://cursor.com/install`); opencode via Brewfile        |
| Languages  | asdf + `.tool-versions` (nodejs, java, maven); rustup for Rust                 |

`install.sh` installs Homebrew if missing (on Linux it first ensures apt build deps: `build-essential`, `curl`, `file`, `git`, `procps`), then runs `brew bundle`. First Linux run is heavier than apt-only setups.

Not installed: Flutter / Elixir / Haskell / Zig SDKs, private path crates (`pipeline-cli`, `cargo-sanitize`), GUI apps.

## First-time notes

1. **Symlinks replace** `~/.zshrc`, `~/.zshenv`, `~/.zprofile`, `~/.gitconfig`, and `~/.config/nvim`. Existing files are backed up as `*.pre-configs.bak`.
2. Put **secrets** in `~/.zshrc.local` (created as a stub). Examples: `CURSOR_API_KEY`, GitHub tokens, npm auth. Never commit that file.
3. Set git name/email in `~/.gitconfig.local`.
4. In nvim, run `:PackerSync` once to install plugins.
5. Cursor Agent: `agent login` or set `CURSOR_API_KEY`.
6. Linuxbrew lives under `/home/linuxbrew/.linuxbrew`; `zsh/zprofile` runs `brew shellenv` for that prefix.

## Layout

```
install.sh           # entrypoint (Coder + local)
Brewfile             # shared macOS + Linux formulae
cargo-tools.txt      # cargo install list
.tool-versions       # asdf pins
zsh/                 # portable shell config (includes brew shellenv)
git/gitconfig
nvim/                # Neovim config
```

## Security

Do not put passwords or PATs in tracked shell files. If they previously lived in `~/.zshrc`, rotate them and move values to `~/.zshrc.local` or your secret store.
