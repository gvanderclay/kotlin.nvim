-- Configurable integration points for kotlin.nvim.
-- This module owns plugin-vs-builtin dispatch so call sites in package.lua,
-- commands.lua, and kotlin.lua keep a single-line delta from upstream.

local M = {}

local default_config = {
  file_browser = "auto",
  list = "auto",
  installer = "auto",
}

local current_config = vim.deepcopy(default_config)

function M.configure(user_config)
  current_config = vim.tbl_deep_extend("force", default_config, user_config or {})
end

function M.get(key)
  return current_config[key]
end

function M.defaults()
  return vim.deepcopy(default_config)
end

return M
