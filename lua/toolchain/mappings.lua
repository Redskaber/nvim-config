-- ~/.config/nvim/lua/toolchain/mappings.lua
-- Strategy layer: tool-name → mason-package-name (single source of truth).
--
-- Rules:
--   • lsp_to_mason: only entries whose mason pkg DIFFERS from server name.
--   • tool_to_mason: only entries whose mason pkg DIFFERS from tool name.
--   • system_tools: NEVER install via mason.
--   • resolve() priority: user overrides → system_tools → Nix → mappings → identity.

local M = {}

-- ── LSP server → mason package ────────────────────────────────────────────────
-- Used ONLY by runtime/adapters/mason.lua to look up mason package names.
-- mason-lspconfig.nvim's ensure_installed takes lspconfig server names directly
-- and does its own server→package resolution internally.

M.lsp_to_mason = {
  lua_ls = "lua-language-server",
  rust_analyzer = "rust-analyzer",
  nil_ls = "nil",
  tsserver = "typescript-language-server",
  jsonls = "json-lsp",
  yamlls = "yaml-language-server",
  pylsp = "python-lsp-server",
  clangd = "clangd",
  gopls = "gopls",
  zls = "zls",
  vtsls = "vtsls",
  taplo = "taplo",
  pyright = "pyright",
  -- JVM
  jdtls = "jdtls",
  kotlin_language_server = "kotlin-language-server",
  -- Lisp / Clojure
  clojure_lsp = "clojure-lsp",
  -- Assembly
  asm_lsp = "asm-lsp",
  -- Shell
  bashls = "bash-language-server",
}

-- ── Formatter / linter tool → mason package ──────────────────────────────────

M.tool_to_mason = {
  ruff_format = "ruff",
  -- JVM formatters
  ["google-java-format"] = "google-java-format",
  ktfmt = "ktfmt",
  ktlint = "ktlint",
  -- Lisp / Clojure
  cljfmt = "cljfmt",
  ["clj-kondo"] = "clj-kondo",
  -- C/C++
  ["clang-format"] = "clang-format",
  -- clangtidy (clang-tidy) ships with the system LLVM/clang toolchain; not via mason
  -- Java
  checkstyle = "checkstyle",
  -- JS/TS
  eslint = "eslint_d", -- eslint tool name → eslint_d mason package (eslint_d is identity)
  prettierd = "prettierd",
  prettier = "prettier",
  -- Go
  goimports = "goimports",
  -- Shell
  shfmt = "shfmt",
  shellcheck = "shellcheck",
}

-- ── System-only tools (never via mason) ──────────────────────────────────────

M.system_tools = {
  -- Shell / system utilities
  rustup = true,
  nix = true,
  git = true,
  make = true,
  cc = true,
  -- Language-toolchain formatters / linters (never via mason)
  rustfmt = true,
  clippy = true,
  gofmt = true,
  zigfmt = true,
  fish_indent = true,
  fish = true,
  nixpkgs_fmt = true,
  clangtidy = true, -- ships with system LLVM/clang toolchain
}

-- ── User-defined overrides ─────────────────────────────────────────────────────
-- Set via toolchain/mappings.lua or vim.g.ltos_tool_overrides at runtime.
-- Each entry: tool_name → { use_mason: boolean, pkg: string|nil }
M.overrides = {}

-- ── Public API ────────────────────────────────────────────────────────────────

---@param server string
---@return string
function M.lsp_pkg(server)
  return M.lsp_to_mason[server] or server
end

---@param tool string
---@return string|nil
function M.tool_pkg(tool)
  if M.system_tools[tool] == true then
    return nil
  end
  return M.tool_to_mason[tool] or tool
end

--- Unified resolution: priority = user overrides → system_tools → tool_to_mason → identity.
---@param tool string
---@return { use_mason: boolean, pkg: string|nil }
function M.resolve(tool)
  -- 1. User overrides (vim.g takes priority over mappings.overrides)
  local g_overrides = vim.g.ltos_tool_overrides
  if type(g_overrides) == "table" and g_overrides[tool] then
    return g_overrides[tool]
  end
  local override = M.overrides[tool]
  if override ~= nil then
    return override
  end

  -- 2. System-only
  if M.system_tools[tool] == true then
    return { use_mason = false, pkg = nil }
  end

  -- 3. Explicit mapping
  local mapped = M.tool_to_mason[tool]
  if mapped then
    return { use_mason = true, pkg = mapped }
  end

  -- 4. Identity fallback
  if vim.g.ltos_debug then
    vim.notify("[ltos:mappings] identity mapping: " .. tool, vim.log.levels.DEBUG)
  end
  return { use_mason = true, pkg = tool }
end

return M
