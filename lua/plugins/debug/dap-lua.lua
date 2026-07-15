-- ~/.config/nvim/lua/plugins/debug/dap-lua.lua
-- Lua language editing enhancements.
--
-- Responsibility boundary (职责分离):
--   • LTOS adapter (runtime/adapters/) owns: LSP (lua_ls), formatter (stylua),
--     linters (luacheck), mason packages, treesitter (lua/luadoc/luap).
--   • This file owns: Lua debug adapter (one-small-step-for-vimkind).
--
-- one-small-step-for-vimkind: Lua debugger that attaches to a Neovim
-- instance — debug your nvim config / plugins by setting breakpoints in
-- Lua code and stepping through. Essential for LTOS self-development.
return {
  {
    "jbyuki/one-small-step-for-vimkind",
    ft = "lua",
    dependencies = { "mfussenegger/nvim-dap" },
    config = function()
      local dap = require("dap")
      dap.configurations.lua = {
        {
          type = "nlua",
          request = "attach",
          name = "Attach to running Neovim instance",
        },
      }
      dap.adapters.nlua = function(callback, config)
        callback({ type = "server", host = config.host or "127.0.0.1", port = config.port or 8086 })
      end
    end,
  },
}