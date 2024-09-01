local execute = vim.api.nvim_command
local fn = vim.fn
local fmt = string.format

local pack_path = fn.stdpath("data") .. "/site/pack"

-- ensure a given plugin from github.com/<user>/<repo> is cloned in the pack/packer/start directory
local function ensure (user, repo)
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
  use {'wbthomason/packer.nvim'}

  -- vimagit
  use {'jreybert/vimagit'}

  -- Fuzzy finder
  use {'airblade/vim-rooter'}
  use {'junegunn/fzf.vim'}
  use {'junegunn/fzf'}

  -- colorscheme
  -- There was an issue with this color scheme after updating to nvim 0.8.
  -- I found a work around here.
  -- https://stackoverflow.com/questions/74051866/colorscheme-broken-after-upgrading-to-nvim-v0-8-0-why-did-t-co-change
  use {'arzg/vim-colors-xcode'}

  use {'binhtran432k/dracula.nvim'}

  -- lsp config for elixir-ls support
  use {'neovim/nvim-lspconfig'}

  -- cmp framework for auto-completion support
  use {'hrsh7th/nvim-cmp'}

  use {'towolf/vim-helm'}

  -- install different completion source
  use {'hrsh7th/cmp-nvim-lsp'}
  use {'hrsh7th/cmp-buffer'}
  use {'hrsh7th/cmp-path'}
  use {'hrsh7th/cmp-cmdline'}

  -- git plugins
  use {'APZelos/blamer.nvim'}
  
  -- Flutter support
  use {'akinsho/flutter-tools.nvim', requires = 'nvim-lua/plenary.nvim'}

  -- Typescript support
  use {'jose-elias-alvarez/nvim-lsp-ts-utils'}

  -- Rust
  -- use {'rust-lang/rust.vim'}
  use {'simrat39/rust-tools.nvim'}
  use {'saecki/crates.nvim'}

  -- Spell checher
  use {'kamykn/spelunker.vim'}

  -- Debugging
  use {'nvim-lua/plenary.nvim'}
  use {'mfussenegger/nvim-dap'}

  -- you need a snippet engine for snippet support
  -- here I'm using vsnip which can load snippets in vscode format
  use {'hrsh7th/vim-vsnip'}
  use {'hrsh7th/cmp-vsnip'}

  -- treesitter for syntax highlighting and more
  use {'nvim-treesitter/nvim-treesitter'}
end)

local buf_map = function(bufnr, mode, lhs, rhs, opts)
  vim.api.nvim_buf_set_keymap(bufnr, mode, lhs, rhs, opts or { noremap=true, silent = true })
end

local function show_documentation()
    local filetype = vim.bo.filetype
    if vim.tbl_contains({ 'vim','help' }, filetype) then
        vim.cmd('h '..vim.fn.expand('<cword>'))
    elseif vim.tbl_contains({ 'man' }, filetype) then
        vim.cmd('Man '..vim.fn.expand('<cword>'))
    elseif vim.fn.expand('%:t') == 'Cargo.toml' and require('crates').popup_available() then
        require('crates').show_popup()
    else
        vim.lsp.buf.hover()
    end
end

vim.keymap.set('n', 'K', show_documentation, { silent = true })
-- `on_attach` callback will be called after a language server
-- instance has been attached to an open buffer with matching filetype
-- here we're setting key mappings for hover documentation, goto definitions, goto references, etc
-- you may set those key mappings based on your own preference
local on_attach = function(client, bufnr)

  buf_map(bufnr, 'n', 'gd', '<cmd>lua vim.lsp.buf.definition()<CR>')
  buf_map(bufnr, 'n', '<leader>gt', '<cmd>lua vim.lsp.buf.type_definition()<CR>')
  buf_map(bufnr, 'n', 'gr', '<cmd>lua vim.lsp.buf.references()<CR>')
  buf_map(bufnr, 'n', 'gD', '<cmd>lua vim.lsp.buf.declaration()<CR>')
  buf_map(bufnr, 'n', 'gi', '<cmd>lua vim.lsp.buf.implementation()<CR>')
  --buf_map(bufnr, 'n', 'K', show_documentation)
  buf_map(bufnr, 'n', '<C-k>', '<cmd>lua vim.lsp.buf.signature_help()<CR>')
  buf_map(bufnr, 'n', '<leader>cr', '<cmd>lua vim.lsp.buf.rename()<CR>')
  buf_map(bufnr, 'n', '<leader>ca', '<cmd>lua vim.lsp.buf.code_action()<CR>')
  buf_map(bufnr, 'n', '<leader>cf', '<cmd>lua vim.lsp.buf.format()<CR>')
  buf_map(bufnr, 'n', '<leader>cd', '<cmd>lua vim.diagnostic.open_float()<CR>')
  buf_map(bufnr, 'n', '<leader>cdl', '<cmd>lua vim.diagnostic.setqflist()<CR>')
  buf_map(bufnr, 'n', '[d', '<cmd>lua vim.diagnostic.goto_prev()<CR>')
  buf_map(bufnr, 'n', ']d', '<cmd>lua vim.diagnostic.goto_next()<CR>')
end

local capabilities = require('cmp_nvim_lsp').default_capabilities(vim.lsp.protocol.make_client_capabilities())
capabilities.textDocument.completion.completionItem.snippetSupport = true

local path_to_elixirls = vim.fn.expand("~/repos/elixir-ls/release/language_server.sh")

local lsp = require('lspconfig')

-- setting up the elixir language server
-- you have to manually specify the entrypoint cmd for elixir-ls
lsp.elixirls.setup {
  cmd = { path_to_elixirls },
  on_attach = function(client, bufnr) 
    buf_map(bufnr, 'n', '<leader>tt', 'O@tag jb: true<C-[>:w<CR>')
    buf_map(bufnr, 'n', '<leader>tuf', ':! mix test.unit %<cr>')
    buf_map(bufnr, 'n', '<leader>tif', ':! mix test.integration %<cr>')
    buf_map(bufnr, 'n', '<leader>tus', ':! mix test.unit % --only jb<cr>')
    buf_map(bufnr, 'n', '<leader>tis', ':! mix test.integration % --only jb<cr>')
    buf_map(bufnr, 'n', '<leader>tua', ':! mix test.unit<CR>')
    buf_map(bufnr, 'n', '<leader>tia', ':! mix test.integration<CR>')
    on_attach(client, bufnr)
  end,
  capabilities = capabilities,
  root_dir = lsp.util.root_pattern('mix.lock', '.formatter.exs')
}
-- Requires zls
lsp.zls.setup {
  capabilities = capabilities,
  on_attach = on_attach,
  cmd = { "zls" }
}
-- The following 4 LSPs requires `npm i -g vscode-langservers-extracted`
lsp.jsonls.setup {
  capabilities = capabilities,
  on_attach = on_attach,
}
lsp.phpactor.setup {
  capabilities = capabilities,
  on_attach = on_attach,
  cmd = { "phpactor", "language-server" },
  filetypes = { "php" },
  root_dir = lsp.util.root_pattern('composer.json', '.git'),
}
lsp.html.setup{
  capabilities = capabilities,
  on_attach = on_attach,
}
lsp.cssls.setup{
  capabilities = capabilities,
  on_attach = on_attach,
}
-- Requires `cargo install --features lsp --locked taplo-cli`
lsp.taplo.setup{
  capabilities = capabilities,
  on_attach = on_attach,
}
-- Requires `npm install --global yaml-language-server`
-- For other schemas see https://www.schemastore.org/json/
lsp.yamlls.setup{
  capabilities = capabilities,
  on_attach = function(client, bufnr)
    on_attach(client, bufnr)
    -- Short-circuit for Helm template files
    if vim.bo[bufnr].buftype ~= '' or vim.bo[bufnr].filetype == 'helm' then
      vim.diagnostic.disable(bufnr)
      vim.defer_fn(function()
        vim.diagnostic.reset(nil, bufnr)
      end, 1000)
      return
    end
  end,
  settings = {
    yaml = {
      schemas = {
        ["https://json.schemastore.org/github-workflow.json"] = "/.github/workflows/*",
        ["https://raw.githubusercontent.com/compose-spec/compose-spec/master/schema/compose-spec.json"] = "/docker-compose.yml",
        ["https://json.schemastore.org/pubspec.json"] = "/pubspec.yaml",
        ["https://json.schemastore.org/drone.json"] = "/.drone.yml",
      }
    }
  }
}
-- Requires npm install -g elm elm-test elm-format @elm-tooling/elm-language-server
lsp.elmls.setup {
  capabilities = capabilities,
  on_attach = on_attach,
}
-- Requires go install github.com/bufbuild/buf-language-server/cmd/bufls@latest
lsp.bufls.setup{
  capabilities = capabilities,
  on_attach = on_attach,
}
-- Requires `npm install -g dockerfile-language-server-nodejs`
lsp.dockerls.setup{
  capabilities = capabilities,
  on_attach = on_attach,
}
-- Requires https://github.com/artempyanykh/marksman
lsp.marksman.setup{
  capabilities = capabilities,
  on_attach = on_attach,
}
--  Requires `npm install -g typescript typescript-language-server`
lsp.tsserver.setup {
  capabilities = capabilities,
  on_attach = function(client, bufnr)
    buf_map(bufnr, 'n', 'go', ':TSLspImportAll<CR>')
    local ts_utils = require("nvim-lsp-ts-utils")
      ts_utils.setup({})
      ts_utils.setup_client(client)
    on_attach(client, bufnr)
  end
}
lsp.eslint.setup {
  capabilities = capabilities,
  on_attach = on_attach,
  settings = {
    format = {
      enable = true,
    },
  }
}
-- requires `npm install -g elm elm-test elm-format @elm-tooling/elm-language-server`
lsp.elmls.setup{
  capabilities = capabilities,
  on_attach = on_attach,
}
require('rust-tools').setup({
  capabilities = capabilities,
  tools = {
    hover_actions = {
      auto_focus = true
    },
    inlay_hints = {
      only_current_line = true
    },
  },
  server = {
    on_attach = function(client, bufnr)
      client.server_capabilities.semanticTokensProvider = nil
      buf_map(bufnr, 'n', '<leader>cha', ':RustHoverActions<CR>')
      on_attach(client, bufnr)
    end,
    settings = {
      ["rust-analyzer"] = {
        cargo = {
          allFeatures = true,
          buildScripts = {
            enable = true,
          },
          extraEnv = { CARGO_PROFILE_RUST_ANALYZER_INHERITS = 'dev', },
        },
        procMacro = {
          enable = true,
        },
        checkOnSave = {
          command = "clippy",
        },
      },
    },
  }
})
require("flutter-tools").setup({
  flutter_lookup_cmd = "asdf where flutter",
  lsp = {
    on_attach = on_attach
  }
})
require("crates").setup({
  completion = {
    cmp = {
      enable = true
    }
  },
  -- null_ls = {
  --   enabled = true,
  -- },
})
vim.api.nvim_set_hl(0, "CratesNvimVersion", { default = true, link = "Comment" })

local cmp = require'cmp'

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

require('nvim-treesitter.configs').setup {
  ensure_installed = {'rust', 'dart', 'elixir', 'typescript', 'javascript', 'python', 'lua', 'php', 'zig'},
  sync_install = false,
  ignore_install = { },
  highlight = {
    enable = true,
    disable = { },
  },
  indent = {
    enable = true
  }
}

require("dracula").setup {
  styles = {
    keywords = { italic = false },
  },
}


vim.g.rooter_patterns = {'.git'}

vim.wo.number = true
vim.cmd('colorscheme dracula-soft')
vim.cmd('map <C-p> :Files<CR>')
vim.cmd('map <C-b> :Buffers<CR>')
vim.cmd('set colorcolumn=80')
vim.cmd('set tabstop=2 shiftwidth=2 expandtab')

vim.g.blamer_enabled = 1

-- Make bracket matching more subtle
vim.cmd('hi MatchParen cterm=none ctermbg=none ctermfg=green')
