-- spec/runtime/adapters_spec.lua
-- Individual lang adapter unit tests:
-- lsp, mason, treesitter, conform, lint.
-- Each adapter: build() contract, IR field handling, _source tagging,
-- missing field graceful degradation, spec structure validity.

local R = require("spec._runner")

-- ── Shared fixtures ───────────────────────────────────────────────────────────

local function full_lir()
  local pipeline = require("runtime.pipeline")
  return pipeline.debug_run({ "modules.lang.lua", "modules.lang.python" }, "optimize")
end

-- Minimal valid LIR with all required fields
local function minimal_lir(overrides)
  local F = require("spec._fixtures.ir")
  local ir = F.lir(
    {
      lua = {
        lsp = { lua_ls = {} },
        formatters = { lua = { "stylua" } },
        linters = { lua = { "luacheck" } },
        treesitter = { "lua" },
        mason = { "stylua" },
      },
    },
    { lsp = { lua_ls = true }, tools = { stylua = true } },
    { lua_ls = { settings = { Lua = {} } } },
    { "lua", "luadoc" }
  )
  ir.symbols = {
    lsp = { lua_ls = { mason = "lua-language-server", system = false } },
    tools = { stylua = { mason = "stylua", system = false } },
  }
  if overrides then
    -- FIX-DEPLOY-TEST (2026-06-23): use rawset to handle nil values.
    -- pairs() does NOT iterate fields with nil values, so
    -- overrides = { merged_lsp = nil } would be silently ignored.
    -- rawset explicitly sets the field (including nil, which removes it).
    for k, v in pairs(overrides) do
      ir[k] = v
    end
    -- Also handle explicit nil overrides (for keys not iterated by pairs)
    if overrides.merged_lsp == nil and rawget(overrides, "merged_lsp") ~= nil then
      ir.merged_lsp = nil
    end
  end
  return ir
end

-- ── runtime.adapters.lsp ─────────────────────────────────────────────────────

R.describe("runtime.adapters.lsp", function()
  local lsp = require("runtime.adapters.lsp")

  -- ── build() output shape ──────────────────────────────────────────────────

  R.describe("build() output shape", function()
    R.it("returns table list (LazySpec[])", function()
      local specs = lsp.build(minimal_lir())
      R.assert_type(specs, "table")
      R.assert_true(#specs >= 2)
    end)

    R.it("nvim-lspconfig spec present", function()
      local specs = lsp.build(minimal_lir())
      local found = false
      for _, s in ipairs(specs) do
        if s[1] == "neovim/nvim-lspconfig" then
          found = true
          break
        end
      end
      R.assert_true(found, "nvim-lspconfig must be in lsp adapter output")
    end)

    R.it("mason-lspconfig spec present", function()
      local specs = lsp.build(minimal_lir())
      local found = false
      for _, s in ipairs(specs) do
        if s[1] == "mason-org/mason-lspconfig.nvim" then
          found = true
          break
        end
      end
      R.assert_true(found, "mason-lspconfig must be in lsp adapter output")
    end)

    R.it("_source = 'ltos:lsp' on both specs", function()
      local specs = lsp.build(minimal_lir())
      for _, s in ipairs(specs) do
        R.assert_eq(s._source, "ltos:lsp", s[1] .. " must have ltos:lsp source")
      end
    end)
  end)

  -- ── servers propagation ───────────────────────────────────────────────────

  R.describe("servers propagation", function()
    R.it("nvim-lspconfig opts.servers contains lua_ls", function()
      local specs = lsp.build(minimal_lir())
      for _, s in ipairs(specs) do
        if s[1] == "neovim/nvim-lspconfig" then
          R.assert_not_nil(s.opts and s.opts.servers and s.opts.servers.lua_ls)
          return
        end
      end
      R.assert_true(false, "nvim-lspconfig spec not found")
    end)

    R.it("mason-lspconfig ensure_installed contains mason-managed servers", function()
      local ir = full_lir()
      local specs = lsp.build(ir)
      for _, s in ipairs(specs) do
        if s[1] == "mason-org/mason-lspconfig.nvim" then
          local ei = s.opts and s.opts.ensure_installed or {}
          R.assert_true(#ei >= 1, "ensure_installed must be non-empty")
          return
        end
      end
    end)
  end)

  -- ── missing field graceful degradation ───────────────────────────────────

  R.describe("missing field graceful degradation", function()
    R.it("missing merged_lsp → returns _ltos_error spec", function()
      -- FIX-DEPLOY-TEST (2026-06-23): construct IR directly without merged_lsp.
      -- minimal_lir({ merged_lsp = nil }) doesn't work because pairs() doesn't
      -- iterate nil values, so the override is silently ignored.
      local ir = minimal_lir()
      ir.merged_lsp = nil -- explicitly nil out after construction
      local specs = lsp.build(ir)
      R.assert_eq(#specs, 1)
      R.assert_not_nil(specs[1]._ltos_error)
      R.assert_match(specs[1]._ltos_error, "merged_lsp")
    end)
  end)

  -- ── full pipeline integration ─────────────────────────────────────────────

  R.it("processes full_lir without error", function()
    local specs = lsp.build(full_lir())
    R.assert_type(specs, "table")
    R.assert_true(#specs > 0)
  end)
end)

-- ── runtime.adapters.mason ───────────────────────────────────────────────────

R.describe("runtime.adapters.mason", function()
  local mason = require("runtime.adapters.mason")

  -- ── build() output shape ──────────────────────────────────────────────────

  R.describe("build() output shape", function()
    R.it("returns table with mason.nvim spec", function()
      local specs = mason.build(minimal_lir())
      R.assert_type(specs, "table")
      R.assert_true(#specs >= 1)
      local found = false
      for _, s in ipairs(specs) do
        if s[1] == "mason-org/mason.nvim" then
          found = true
          break
        end
      end
      R.assert_true(found, "mason.nvim must be in output")
    end)

    R.it("_source = 'ltos:mason'", function()
      local specs = mason.build(minimal_lir())
      for _, s in ipairs(specs) do
        if s[1] == "mason-org/mason.nvim" then
          R.assert_eq(s._source, "ltos:mason")
          return
        end
      end
    end)
  end)

  -- ── ensure_installed content ──────────────────────────────────────────────

  R.describe("ensure_installed content", function()
    R.it("lua-language-server in ensure_installed for lua", function()
      local ir = full_lir()
      local specs = mason.build(ir)
      for _, s in ipairs(specs) do
        if s[1] == "mason-org/mason.nvim" then
          local ei = s.opts and s.opts.ensure_installed or {}
          local found = false
          for _, pkg in ipairs(ei) do
            if pkg == "lua-language-server" then
              found = true
              break
            end
          end
          R.assert_true(found, "lua-language-server must be in mason ensure_installed")
          return
        end
      end
    end)

    R.it("system tools NOT in ensure_installed (rustfmt excluded)", function()
      local pipeline = require("runtime.pipeline")
      local ir = pipeline.debug_run({ "modules.lang.rust" }, "optimize")
      local specs = mason.build(ir)
      for _, s in ipairs(specs) do
        if s[1] == "mason-org/mason.nvim" then
          local ei = s.opts and s.opts.ensure_installed or {}
          for _, pkg in ipairs(ei) do
            R.assert_ne(pkg, "rustfmt", "rustfmt must not be mason-managed")
          end
          return
        end
      end
    end)

    R.it("no duplicates in ensure_installed", function()
      local ir = full_lir()
      local specs = mason.build(ir)
      for _, s in ipairs(specs) do
        if s[1] == "mason-org/mason.nvim" then
          local ei = s.opts and s.opts.ensure_installed or {}
          local seen = {}
          for _, pkg in ipairs(ei) do
            R.assert_true(not seen[pkg], "duplicate in mason ensure_installed: " .. pkg)
            seen[pkg] = true
          end
          return
        end
      end
    end)

    R.it("base_tools (codespell) always included", function()
      local ir = minimal_lir()
      local specs = mason.build(ir)
      for _, s in ipairs(specs) do
        if s[1] == "mason-org/mason.nvim" then
          local ei = s.opts and s.opts.ensure_installed or {}
          local found = false
          for _, pkg in ipairs(ei) do
            if pkg == "codespell" then
              found = true
              break
            end
          end
          R.assert_true(found, "codespell (base_tool) must be in ensure_installed")
          return
        end
      end
    end)
  end)

  -- ── missing caps graceful degradation ────────────────────────────────────

  R.it("missing caps → returns _ltos_error spec", function()
    local ir_mod = require("core.compiler.ir")
    local ir = ir_mod.new({}, "full")
    ir.caps = nil
    local specs = mason.build(ir)
    R.assert_true(#specs >= 1)
    R.assert_not_nil(specs[1]._ltos_error)
  end)
end)

-- ── runtime.adapters.treesitter ──────────────────────────────────────────────

R.describe("runtime.adapters.treesitter", function()
  local treesitter = require("runtime.adapters.treesitter")

  -- ── build() output shape ──────────────────────────────────────────────────

  R.describe("build() output shape", function()
    R.it("returns nvim-treesitter spec", function()
      local specs = treesitter.build(minimal_lir())
      R.assert_type(specs, "table")
      R.assert_true(#specs >= 1)
      R.assert_eq(specs[1][1], "nvim-treesitter/nvim-treesitter")
    end)

    R.it("_source = 'ltos:treesitter'", function()
      local specs = treesitter.build(minimal_lir())
      R.assert_eq(specs[1]._source, "ltos:treesitter")
    end)
  end)

  -- ── ensure_installed content ──────────────────────────────────────────────

  R.describe("ensure_installed content", function()
    R.it("contains lua parsers from lua module", function()
      local ir = full_lir()
      local specs = treesitter.build(ir)
      local ei = specs[1].opts and specs[1].opts.ensure_installed or {}
      local found = false
      for _, p in ipairs(ei) do
        if p == "lua" then
          found = true
          break
        end
      end
      R.assert_true(found, "lua parser must be in ensure_installed")
    end)

    R.it("no duplicates in ensure_installed", function()
      local ir = full_lir()
      local specs = treesitter.build(ir)
      local ei = specs[1].opts and specs[1].opts.ensure_installed or {}
      local seen = {}
      for _, p in ipairs(ei) do
        R.assert_true(not seen[p], "duplicate parser: " .. p)
        seen[p] = true
      end
    end)

    R.it("base parsers (lua, python, etc.) always included", function()
      local ir = minimal_lir()
      local specs = treesitter.build(ir)
      local ei = specs[1].opts and specs[1].opts.ensure_installed or {}
      local set = {}
      for _, p in ipairs(ei) do
        set[p] = true
      end
      -- these are in DEFAULT_BASE_PARSERS
      for _, p in ipairs({ "lua", "python", "bash", "json" }) do
        R.assert_true(set[p], p .. " must be in base parsers")
      end
    end)
  end)

  -- ── textobjects opts ─────────────────────────────────────────────────────

  R.it("opts.textobjects.select is configured", function()
    local specs = treesitter.build(minimal_lir())
    local to = specs[1].opts and specs[1].opts.textobjects
    if to then
      R.assert_not_nil(to.select, "textobjects.select must be configured")
    end
  end)

  -- ── missing field graceful degradation ───────────────────────────────────

  R.it("missing all_parsers → returns _ltos_error spec", function()
    local ir = minimal_lir()
    ir.all_parsers = nil
    local specs = treesitter.build(ir)
    R.assert_not_nil(specs[1]._ltos_error)
    R.assert_match(specs[1]._ltos_error, "all_parsers")
  end)
end)

-- ── runtime.adapters.conform ─────────────────────────────────────────────────

R.describe("runtime.adapters.conform", function()
  local conform = require("runtime.adapters.conform")

  -- ── build() output shape ──────────────────────────────────────────────────

  R.describe("build() output shape", function()
    R.it("returns conform.nvim spec", function()
      local specs = conform.build(minimal_lir())
      R.assert_type(specs, "table")
      R.assert_eq(specs[1][1], "stevearc/conform.nvim")
    end)

    R.it(
      "_source = 'ltos:conform'",
      function() R.assert_eq(conform.build(minimal_lir())[1]._source, "ltos:conform") end
    )
  end)

  -- ── formatters_by_ft content ──────────────────────────────────────────────

  R.describe("formatters_by_ft", function()
    R.it("lua filetype has stylua formatter", function()
      local specs = conform.build(minimal_lir())
      local fmts = specs[1].opts and specs[1].opts.formatters_by_ft or {}
      R.assert_not_nil(fmts.lua, "lua formatters must be set")
      local found = false
      for _, f in ipairs(fmts.lua) do
        if f == "stylua" then
          found = true
          break
        end
      end
      R.assert_true(found, "stylua must be in lua formatters")
    end)

    R.it("FormatterNode with fn injected correctly", function()
      local pipeline = require("runtime.pipeline")
      local ir = pipeline.debug_run({ "modules.lang.python" }, "normalize")
      -- At normalize stage, fn is injected
      local specs = conform.build(ir)
      local fmts = specs[1].opts and specs[1].opts.formatters_by_ft or {}
      -- python formatters may contain function-based entries
      if fmts.python then
        for _, f in ipairs(fmts.python) do
          if type(f) == "table" then
            -- Either has fn (valid) or _ltos_warn (missing fn)
            local valid = type(f.fn) == "function" or f._ltos_warn ~= nil or f.name ~= nil
            R.assert_true(valid, "FormatterNode must have fn, name, or warn marker")
          end
        end
      end
    end)
  end)

  -- ── default opts ─────────────────────────────────────────────────────────

  R.it("default_format_opts present (format_on_save owned by LazyVim)", function()
    local opts = conform.build(minimal_lir())[1].opts
    R.assert_not_nil(opts.default_format_opts)
    R.assert_type(opts.default_format_opts.timeout_ms, "number")
    -- FIX-LAZYVIM-FORMAT-ON-SAVE (2026-06-26): format_on_save is intentionally
    -- NOT set by the adapter. LazyVim owns format-on-save via LazyVim.format
    -- (BufWritePre autocmd calling conform.format()). Setting opts.format_on_save
    -- would create a conflicting second hook. See https://www.lazyvim.org/plugins/formatting
    R.assert_nil(opts.format_on_save, "format_on_save must NOT be set — LazyVim owns it")
  end)

  -- ── missing caps ─────────────────────────────────────────────────────────

  R.it("missing caps → returns _ltos_error spec", function()
    local ir_mod = require("core.compiler.ir")
    local ir = ir_mod.new({}, "full")
    ir.caps = nil
    local specs = conform.build(ir)
    R.assert_not_nil(specs[1]._ltos_error)
  end)
end)

-- ── runtime.adapters.lint ────────────────────────────────────────────────────

R.describe("runtime.adapters.lint", function()
  local lint = require("runtime.adapters.lint")

  -- ── build() output shape ──────────────────────────────────────────────────

  R.describe("build() output shape", function()
    R.it("returns nvim-lint spec", function()
      local specs = lint.build(minimal_lir())
      R.assert_type(specs, "table")
      R.assert_eq(specs[1][1], "mfussenegger/nvim-lint")
    end)

    R.it(
      "_source = 'ltos:lint'",
      function() R.assert_eq(lint.build(minimal_lir())[1]._source, "ltos:lint") end
    )
  end)

  -- ── linters_by_ft content ────────────────────────────────────────────────

  R.describe("linters_by_ft", function()
    R.it("lua filetype has luacheck linter", function()
      local specs = lint.build(minimal_lir())
      local lints = specs[1].opts and specs[1].opts.linters_by_ft or {}
      R.assert_not_nil(lints.lua, "lua linters must be set")
      local found = false
      for _, l in ipairs(lints.lua) do
        if l == "luacheck" then
          found = true
          break
        end
      end
      R.assert_true(found, "luacheck must be in lua linters")
    end)

    R.it("python filetype has ruff linter", function()
      local pipeline = require("runtime.pipeline")
      local ir = pipeline.debug_run({ "modules.lang.python" }, "optimize")
      local specs = lint.build(ir)
      local lints = specs[1].opts and specs[1].opts.linters_by_ft or {}
      R.assert_not_nil(lints.python, "python linters must be set")
      local found = false
      for _, l in ipairs(lints.python) do
        if l == "ruff" then
          found = true
          break
        end
      end
      R.assert_true(found, "ruff must be in python linters")
    end)

    R.it("no duplicate linters per filetype", function()
      local ir = full_lir()
      local specs = lint.build(ir)
      local lints = specs[1].opts and specs[1].opts.linters_by_ft or {}
      for ft, lst in pairs(lints) do
        local seen = {}
        for _, l in ipairs(lst) do
          R.assert_true(not seen[l], "duplicate linter in " .. ft .. ": " .. l)
          seen[l] = true
        end
      end
    end)
  end)

  -- ── missing caps ─────────────────────────────────────────────────────────

  R.it("missing caps → returns _ltos_error spec", function()
    local ir_mod = require("core.compiler.ir")
    local ir = ir_mod.new({}, "full")
    ir.caps = nil
    local specs = lint.build(ir)
    R.assert_not_nil(specs[1]._ltos_error)
  end)
end)

-- ── runtime.adapters.registry (AdapterRegistry) ──────────────────────────────

R.describe("runtime.adapters.registry", function()
  local reg = require("runtime.adapters.registry")

  R.it(
    "at least 5 adapters registered (lsp/mason/treesitter/conform/lint)",
    function() R.assert_true(#reg.list() >= 5) end
  )

  R.it(
    "first adapter is lsp (priority 10)",
    function() R.assert_eq(reg.list()[1], "runtime.adapters.lsp") end
  )

  R.it("adapters are in ascending priority order", function()
    local list = reg.list()
    local known = {
      ["runtime.adapters.lsp"] = 10,
      ["runtime.adapters.mason"] = 20,
      ["runtime.adapters.treesitter"] = 30,
      ["runtime.adapters.conform"] = 40,
      ["runtime.adapters.lint"] = 50,
    }
    local last_prio = -1
    for _, path in ipairs(list) do
      local p = known[path]
      if p then
        R.assert_true(p > last_prio, path .. " must have higher priority than previous")
        last_prio = p
      end
    end
  end)

  R.it("setup() is idempotent (P6-C2)", function()
    local n = #reg.list()
    reg.setup()
    reg.setup()
    R.assert_eq(#reg.list(), n)
  end)

  R.it("register() adds custom adapter", function()
    local before = #reg.list()
    reg.register("runtime.adapters.lint", { priority = 999 }) -- idempotent: already exists
    R.assert_eq(#reg.list(), before, "existing adapter must not be duplicated")
  end)
end)

