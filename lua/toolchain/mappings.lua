-- ~/.config/nvim/lua/toolchain/mappings.lua
-- Strategy layer: tool-name → mason-package-name (single source of truth).
--
-- Rules:
--   • lsp_to_mason: only entries whose mason pkg DIFFERS from server name.
--   • tool_to_mason: only entries whose mason pkg DIFFERS from tool name.
--   • system_tools: NEVER install via mason.
--   • resolve() priority: user overrides → system_tools → Nix → mappings → identity.
--   • Tool resolution: use toolchain.rules.resolve() — not here (avoids circular require).

local M = {}

-- ── LSP server → mason package ────────────────────────────────────────────────

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
  jdtls = "jdtls",
  kotlin_language_server = "kotlin-language-server",
  clojure_lsp = "clojure-lsp",
  asm_lsp = "asm-lsp",
  bashls = "bash-language-server",
}

-- ── Formatter / linter tool → mason package ──────────────────────────────────

M.tool_to_mason = {
  ruff_format = "ruff",
  ["google-java-format"] = "google-java-format",
  ktfmt = "ktfmt",
  ktlint = "ktlint",
  cljfmt = "cljfmt",
  ["clj-kondo"] = "clj-kondo",
  ["clang-format"] = "clang-format",
  checkstyle = "checkstyle",
  eslint = "eslint_d",
  prettierd = "prettierd",
  prettier = "prettier",
  goimports = "goimports",
  shfmt = "shfmt",
  shellcheck = "shellcheck",
}

-- ── System-only tools (never via mason) ──────────────────────────────────────

M.system_tools = {
  rustup = true,
  nix = true,
  git = true,
  make = true,
  cc = true,
  rustfmt = true,
  clippy = true,
  gofmt = true,
  zigfmt = true,
  fish_indent = true,
  fish = true,
  nixpkgs_fmt = true,
  clangtidy = true,
}

-- ── User-defined overrides (runtime-injected via register_override) ──────────

M.overrides = {}

-- ── Extension API ─────────────────────────────────────────────────────────────

---@param server string
---@param pkg string
function M.register_lsp(server, pkg)
  M.lsp_to_mason[server] = pkg
end

---@param tool string
---@param pkg string
function M.register_tool(tool, pkg)
  M.tool_to_mason[tool] = pkg
end

---@param tool string
---@param override { use_mason: boolean, pkg: string|nil }
function M.register_override(tool, override)
  M.overrides[tool] = override
end

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

return M
