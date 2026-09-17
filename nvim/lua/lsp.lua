--- Create key binding for the buffer
local function buf_map(bufnr, mode, lhs, rhs, opts)
  vim.api.nvim_buf_set_keymap(bufnr, mode, lhs, rhs, opts or { noremap = true, silent = true })
end

--- Show documentation
local function show_documentation()
  local filetype = vim.bo.filetype
  if vim.tbl_contains({ 'vim', 'help' }, filetype) then
    vim.cmd('h ' .. vim.fn.expand('<cword>'))
  elseif vim.tbl_contains({ 'man' }, filetype) then
    vim.cmd('Man ' .. vim.fn.expand('<cword>'))
  elseif vim.fn.expand('%:t') == 'Cargo.toml' and require('crates').popup_available() then
    require('crates').show_popup()
  else
    vim.lsp.buf.hover()
  end
end

vim.keymap.set('n', 'K', show_documentation, { silent = true })
--- `on_attach` callback will be called after a language server
--- instance has been attached to an open buffer with matching filetype
--- here we're setting key mappings for hover documentation, goto definitions, goto references, etc
--- you may set those key mappings based on your own preference
local function on_attach(_, bufnr)
  buf_map(bufnr, 'n', 'gd', '<cmd>lua vim.lsp.buf.definition()<CR>')
  buf_map(bufnr, 'n', '<leader>gt', '<cmd>lua vim.lsp.buf.type_definition()<CR>')
  buf_map(bufnr, 'n', 'gr', '<cmd>lua vim.lsp.buf.references()<CR>')
  buf_map(bufnr, 'n', 'gD', '<cmd>lua vim.lsp.buf.declaration()<CR>')
  buf_map(bufnr, 'n', 'gi', '<cmd>lua vim.lsp.buf.implementation()<CR>')
  --buf_map(bufnr, 'n', 'K', show_documentation)
  buf_map(bufnr, 'n', '<C-k>', '<cmd>lua vim.lsp.buf.signature_help()<CR>')
  buf_map(bufnr, 'n', '<leader>cr', '<cmd>lua vim.lsp.buf.rename()<CR>')
  buf_map(bufnr, 'v', '<leader>ca', '<cmd>lua vim.lsp.buf.code_action()<CR>')
  buf_map(bufnr, 'n', '<leader>ca', '<cmd>lua vim.lsp.buf.code_action()<CR>')
  buf_map(bufnr, 'n', '<leader>cf', '<cmd>lua vim.lsp.buf.format()<CR>')
  buf_map(bufnr, 'n', '<leader>cd', '<cmd>lua vim.diagnostic.open_float()<CR>')
  buf_map(bufnr, 'n', '<leader>cdl', '<cmd>lua vim.diagnostic.setqflist()<CR>')
  buf_map(bufnr, 'n', '[d', '<cmd>lua vim.diagnostic.jump({ count = -1, float = true })<CR>')
  buf_map(bufnr, 'n', ']d', '<cmd>lua vim.diagnostic.jump({ count = 1, float = true })<CR>')
end

-- Attach to every buffer
local lsp_cmds = vim.api.nvim_create_augroup('lsp_cmds', { clear = true })
vim.api.nvim_create_autocmd('LspAttach', {
  group = lsp_cmds,
  desc = 'My global on_attach',
  callback = function(event)
    local bufnr = event.buf
    local client = vim.lsp.get_client_by_id(event.data.client_id)
    on_attach(client, bufnr)
  end
})

local capabilities = vim.tbl_deep_extend("force",
  vim.lsp.protocol.make_client_capabilities(),
  require('cmp_nvim_lsp').default_capabilities()
)
capabilities.textDocument.completion.completionItem.snippetSupport = true
capabilities.workspace.didChangeWatchedFiles.dynamicRegistration = false
vim.lsp.config('lua_ls', { capabilities = capabilities })

vim.lsp.config('lua_ls', {
  on_init = function(client)
    if client.workspace_folders then
      local path = client.workspace_folders[1].name
      if
          path ~= vim.fn.stdpath('config')
          and (vim.uv.fs_stat(path .. '/.luarc.json') or vim.uv.fs_stat(path .. '/.luarc.jsonc'))
      then
        return
      end
    end

    client.config.settings.Lua = vim.tbl_deep_extend('force', client.config.settings.Lua, {
      runtime = {
        -- Tell the language server which version of Lua you're using (most
        -- likely LuaJIT in the case of Neovim)
        version = 'LuaJIT',
        -- Tell the language server how to find Lua modules same way as Neovim
        -- (see `:h lua-module-load`)
        path = {
          'lua/?.lua',
          'lua/?/init.lua',
        },
      },
      -- Make the server aware of Neovim runtime files
      workspace = {
        checkThirdParty = false,
        library = {
          vim.env.VIMRUNTIME
          -- Depending on the usage, you might want to add additional paths
          -- here.
          -- '${3rd}/luv/library'
          -- '${3rd}/busted/library'
        }
        -- Or pull in all of 'runtimepath'.
        -- NOTE: this is a lot slower and will cause issues when working on
        -- your own configuration.
        -- See https://github.com/neovim/nvim-lspconfig/issues/3189
        -- library = {
        --   vim.api.nvim_get_runtime_file('', true),
        -- }
      }
    })
  end,
  on_attach = on_attach,
  settings = {
    Lua = {}
  }
})
vim.lsp.enable('lua_ls')
-- setting up the elixir language server
-- you have to manually specify the entrypoint cmd for elixir-ls
local path_to_elixirls = vim.fn.expand("~/repos/elixir-ls/release/language_server.sh")
vim.lsp.config('elixirls', {
  cmd = { path_to_elixirls },
  on_attach = function(_, bufnr)
    buf_map(bufnr, 'n', '<leader>tt', 'O@tag jb: true<C-[>:w<CR>')
    buf_map(bufnr, 'n', '<leader>tuf', ':! mix test.unit %<cr>')
    buf_map(bufnr, 'n', '<leader>tif', ':! mix test.integration %<cr>')
    buf_map(bufnr, 'n', '<leader>tus', ':! mix test.unit % --only jb<cr>')
    buf_map(bufnr, 'n', '<leader>tis', ':! mix test.integration % --only jb<cr>')
    buf_map(bufnr, 'n', '<leader>tua', ':! mix test.unit<CR>')
    buf_map(bufnr, 'n', '<leader>tia', ':! mix test.integration<CR>')
    -- on_attach(client, bufnr)
  end,
  -- root_dir = lsp.util.root_pattern('mix.lock', '.formatter.exs')
})
-- vim.lsp.enable('elixirls')

-- Requires zls
vim.lsp.enable('zls')

-- Requires haskell language-server
vim.lsp.config('hls', {
  settings = {
    haskell = {
      formattingProvider = 'stylish-haskell',
    },
  },
})
vim.lsp.enable('hls')

-- The following 4 LSPs requires `npm i -g vscode-langservers-extracted`
vim.lsp.enable('jsonls')
vim.lsp.enable('html')
vim.lsp.enable('cssls')

-- Requires `cargo install --features lsp --locked taplo-cli`
vim.lsp.enable('taplo')
-- Requires `npm install --global yaml-language-server`
-- For other schemas see https://www.schemastore.org/json/
vim.lsp.config('yamlls', {
  settings = {
    yaml = {
      schemas = {
        ["https://json.schemastore.org/github-workflow.json"] = "/.github/workflows/*",
        ["https://raw.githubusercontent.com/compose-spec/compose-spec/master/schema/compose-spec.json"] =
        "/docker-compose.yml",
        ["https://json.schemastore.org/pubspec.json"] = "/pubspec.yaml",
        ["https://json.schemastore.org/drone.json"] = "/.drone.yml",
      }
    }
  }
})
vim.lsp.enable('yamlls')

-- Requires npm install -g elm elm-test elm-format @elm-tooling/elm-language-server
vim.lsp.enable('elmls')

-- Requires go install github.com/bufbuild/buf-language-server/cmd/bufls@latest
vim.lsp.enable('buf_ls')

-- Requires `npm install -g dockerfile-language-server-nodejs`
vim.lsp.enable('dockerls')

-- Requires https://github.com/artempyanykh/marksman
vim.lsp.enable('marksman')

-- Requires `pip install ruff-lsp` or `brew install ruff`
vim.lsp.enable('ruff')

-- Requires `pip install python-lsp-server`
vim.lsp.enable('pylsp')

--  Requires `npm install -g typescript typescript-language-server`
vim.lsp.config('ts_ls', {
  -- capabilities = capabilities,
  on_attach = function(_, bufnr)
    buf_map(bufnr, 'n', 'go', ':TSLspImportAll<CR>')
    -- on_attach(client, bufnr)
  end
})
vim.lsp.enable('ts_ls')
vim.lsp.config('eslint', {
  settings = {
    format = {
      enable = true,
    },
  }
})
vim.lsp.enable('eslint')

-- require("hurl").setup() -- add hurl to the nvim-treesitter config

vim.lsp.config('rust_analyzer', {
  on_attach = function(client, bufnr)
    client.server_capabilities.semanticTokensProvider = nil
    buf_map(bufnr, 'n', '<leader>cha', ':RustHoverActions<CR>')
    -- on_attach(client, bufnr)
  end,
  settings = {
    ["rust-analyzer"] = {
      cargo = {
        -- allFeatures = true,
        buildScripts = {
          enable = true,
        },
        extraEnv = {
          CARGO_PROFILE_RUST_ANALYZER_INHERITS = 'dev',
          CARGO_TARGET_DIR = 'target/lsp',
        },
      },
      procMacro = {
        enable = true,
      },
      check = {
        command = 'clippy',
        onSave = true,
      },
    },
  },
})
vim.lsp.enable('rust_analyzer')

require("flutter-tools").setup({})
require("crates").setup({})
