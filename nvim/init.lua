local execute = vim.api.nvim_command
local fn = vim.fn
local fmt = string.format

local pack_path = fn.stdpath("data") .. "/site/pack"

-- ensure a given plugin from github.com/<user>/<repo> is cloned in the pack/packer/start directory
local function ensure(user, repo)
  local install_path = fmt("%s/packer/start/%s", pack_path, repo)
  if fn.empty(fn.glob(install_path)) > 0 then
    execute(fmt("!git clone https://github.com/%s/%s %s", user, repo, install_path))
    execute(fmt("packadd %s", repo))
  end
end

-- ensure the plugin manager is installed
ensure("wbthomason", "packer.nvim")

require('packer').startup(function(use)
  -- install all the plugins you need here

  -- the plugin manager can manage itself
  use { 'wbthomason/packer.nvim' }

  -- vimagit
  use { 'jreybert/vimagit' }

  -- Fuzzy finder
  use { 'airblade/vim-rooter' }
  use { 'junegunn/fzf.vim' }
  use { 'junegunn/fzf' }

  -- colorscheme
  -- There was an issue with this color scheme after updating to nvim 0.8.
  -- I found a work around here.
  -- https://stackoverflow.com/questions/74051866/colorscheme-broken-after-upgrading-to-nvim-v0-8-0-why-did-t-co-change
  use { 'arzg/vim-colors-xcode' }

  use { 'binhtran432k/dracula.nvim' }

  -- lsp config for elixir-ls support
  use { 'neovim/nvim-lspconfig' }

  -- cmp framework for auto-completion support
  use { 'hrsh7th/nvim-cmp' }

  use { 'towolf/vim-helm' }

  -- install different completion source
  use { 'hrsh7th/cmp-nvim-lsp' }
  use { 'hrsh7th/cmp-buffer' }
  use { 'hrsh7th/cmp-path' }
  use { 'hrsh7th/cmp-cmdline' }

  -- git plugins
  use { 'APZelos/blamer.nvim' }
  -- Flutter support
  use { 'nvim-flutter/flutter-tools.nvim', requires = 'nvim-lua/plenary.nvim' }

  -- Typescript support DEPRECATED
  -- use { 'jose-elias-alvarez/nvim-lsp-ts-utils' }

  -- Copilot
  use { 'github/copilot.vim' }

  -- Rust
  -- use {'rust-lang/rust.vim'}
  use { 'saecki/crates.nvim' }

  -- Spell checher
  use { 'kamykn/spelunker.vim' }

  -- Debugging
  use { 'nvim-lua/plenary.nvim' }
  use { 'mfussenegger/nvim-dap' }

  -- you need a snippet engine for snippet support
  -- here I'm using vsnip which can load snippets in vscode format
  use { 'hrsh7th/vim-vsnip' }
  use { 'hrsh7th/cmp-vsnip' }

  -- treesitter for syntax highlighting and more
  use { 'nvim-treesitter/nvim-treesitter', branch = 'main', run = ':TSUpdate' }

  -- hurl
  -- use { "pfeiferj/nvim-hurl", branch = "main" }
end)

-- Setup all the lsp config
require('lsp')

vim.api.nvim_set_hl(0, "CratesNvimVersion", { default = true, link = "Comment" })

local cmp = require 'cmp'

-- helper functions
local has_words_before = function()
  local line, col = unpack(vim.api.nvim_win_get_cursor(0))
  return col ~= 0 and vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]:sub(col, col):match("%s") == nil
end

local feedkey = function(key, mode)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(key, true, true, true), mode, true)
end

cmp.setup({
  snippet = {
    expand = function(args)
      -- setting up snippet engine
      -- this is for vsnip, if you're using other
      -- snippet engine, please refer to the `nvim-cmp` guide
      vim.fn["vsnip#anonymous"](args.body)
    end,
  },
  mapping = {
    ['<CR>'] = cmp.mapping.confirm({ select = true }),
    ["<Tab>"] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_next_item()
      elseif vim.fn["vsnip#available"](1) == 1 then
        feedkey("<Plug>(vsnip-expand-or-jump)", "")
      elseif has_words_before() then
        cmp.complete()
      else
        fallback()
      end
    end, { "i", "s" }),

    ["<S-Tab>"] = cmp.mapping(function()
      if cmp.visible() then
        cmp.select_prev_item()
      elseif vim.fn["vsnip#jumpable"](-1) == 1 then
        feedkey("<Plug>(vsnip-jump-prev)", "")
      end
    end, { "i", "s" }),
  },
  sources = cmp.config.sources({
    { name = 'nvim_lsp' },
    { name = 'vsnip' }, -- For vsnip users.
    { name = 'buffer' },
    { name = "crates" },
  })
})

local treesitter = require('nvim-treesitter')

treesitter.setup {
  -- highlight = {
  --   enable = true,
  --   disable = {},
  -- },
  -- indent = {
  --   enable = true
  -- }
}
treesitter.install {
    'dart',
    'elixir',
    -- 'hurl',
    'javascript',
    'lua',
    'php',
    'python',
    'rust',
    'typescript',
    'zig',
}

vim.api.nvim_create_autocmd('FileType', {
  pattern = { 'dart', 'elixir', 'javascript', 'lua', 'php', 'python', 'rust', 'typescript', 'zig' },
  callback = function()
    pcall(vim.treesitter.start)
  end,
})

require("dracula").setup {
  styles = {
    keywords = { italic = false },
  },
}

vim.exrc = true

vim.g.rooter_patterns = { '.git' }

vim.wo.number = true
vim.cmd('colorscheme dracula-soft')
vim.cmd('map <C-p> :Files<CR>')
vim.cmd('map <C-b> :Buffers<CR>')
vim.cmd('set colorcolumn=80')
vim.cmd('set tabstop=2 shiftwidth=2 expandtab')

vim.g.blamer_enabled = 1

-- Make bracket matching more subtle
vim.cmd('hi MatchParen cterm=none ctermbg=none ctermfg=green')

vim.api.nvim_create_user_command(
  'InsertBranch',
  function()
    local branch = vim.fn.system("git branch --show-current 2> /dev/null | tr -d '\n'")
    if branch ~= "" then
      vim.api.nvim_paste(branch, false, -1)
    end
  end,
  { desc = 'Insert the current git branch at the cursor' }
)

-- Copilot settings
vim.g.copilot_no_tab_map = true
vim.api.nvim_set_keymap('i', '<C-c>', 'copilot#Accept("\\<CR>")', { expr = true, silent = true, noremap = true })

if vim.fn.has('maxunix') then
  vim.g.mapleader = "\\"
end

-- Automatically resize all Neovim windows when the terminal is resized
vim.api.nvim_create_autocmd("VimResized", {
  pattern = "*",
  command = "tabdo wincmd =",
})
