-- installer adapter: resolves the kotlin-lsp install directory.
-- Replaces the inline $MASON path expansion in lua/kotlin.lua.
--
-- Config values:
--   "auto"      -- mason ($MASON path convention) → none
--   "none"      -- skip mason; rely on KOTLIN_LSP_DIR / PATH only
--   "mason"     -- explicit mason path lookup
--   function(ctx) -> string|nil
--
-- ctx shape (pinned):
--   { is_windows = boolean, sep = string }
--
-- Returns the absolute path of the kotlin-lsp install dir, or nil if not found.
-- Resolution chain (orchestrated by kotlin.lua, not by this adapter):
--   1. installer adapter (this module)
--   2. $KOTLIN_LSP_DIR env var
--   3. (caller surfaces an actionable error if both fail)

local M = {}

local function mason_dir()
  local path = vim.fn.expand("$MASON/packages/kotlin-lsp")
  if vim.fn.isdirectory(path) == 1 then
    return path
  end
  return nil
end

function M.resolve(ctx)
  ctx = ctx or {}
  local cfg = require("kotlin.adapters").get("installer")

  if type(cfg) == "function" then
    return cfg(ctx)
  end

  if cfg == "none" then
    return nil
  end

  if cfg == "mason" or cfg == "auto" then
    return mason_dir()
  end

  vim.notify("kotlin.nvim: unknown integrations.installer value: " .. vim.inspect(cfg), vim.log.levels.ERROR)
  return nil
end

-- Construct the actionable error printed when no install path resolves.
function M.format_not_found_error()
  return "[kotlin.nvim] kotlin-lsp install not found.\n"
    .. "Configure one of the following:\n"
    .. "  1. integrations.installer = 'mason'  (and :MasonInstall kotlin-lsp)\n"
    .. "  2. export KOTLIN_LSP_DIR=/path/to/kotlin-lsp\n"
    .. "  3. integrations.installer = function(ctx) return '/path' end"
end

return M
