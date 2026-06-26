-- lua/toolchain/defaults/mappings.lua
-- Default toolchain mappings (P2: externalized from toolchain/mappings.lua)

return {
  lsp_to_mason = {
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
  },

  tool_to_mason = {
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
  },

  system_tools = {
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
  },
}

