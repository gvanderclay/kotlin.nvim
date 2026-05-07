-- file_browser adapter: opens a directory path with the user's chosen handler.
-- Replaces the inline pcall(require, "oil") in lua/kotlin/package.lua.
--
-- Config values:
--   "auto"        -- detect: oil.nvim → mini.files → builtin
--   "builtin"     -- always use vim.cmd.edit (lets netrw / user default handle it)
--   "oil"         -- require("oil").open(path)
--   "mini_files"  -- require("mini.files").open(path)
--   function(path, ctx) ... end

local M = {}

local function has(mod)
  local ok = pcall(require, mod)
  return ok
end

local function open_oil(path)
  local ok, oil = pcall(require, "oil")
  if not ok then
    return false, "oil.nvim not loaded"
  end
  return pcall(oil.open, path)
end

local function open_mini_files(path)
  local ok, mini_files = pcall(require, "mini.files")
  if not ok then
    return false, "mini.files not loaded"
  end
  return pcall(mini_files.open, path)
end

local function open_builtin(path)
  return pcall(vim.cmd.edit, vim.fn.fnameescape(path))
end

local function resolve_auto()
  if has("oil") then
    return "oil"
  end
  if has("mini.files") then
    return "mini_files"
  end
  return "builtin"
end

-- Open `path` (a directory) using the configured file browser.
-- ctx is reserved for future use; pinned shape: { buf = number, prev_buf = number }.
function M.open(path, ctx)
  ctx = ctx or {}
  local cfg = require("kotlin.adapters").get("file_browser")

  if type(cfg) == "function" then
    return cfg(path, ctx)
  end

  local choice = cfg
  if cfg == "auto" then
    choice = resolve_auto()
  end

  if choice == "oil" then
    local ok, err = open_oil(path)
    if not ok then
      vim.notify("kotlin.nvim: failed to open with oil: " .. tostring(err), vim.log.levels.ERROR)
    end
    return ok
  elseif choice == "mini_files" then
    local ok, err = open_mini_files(path)
    if not ok then
      vim.notify("kotlin.nvim: failed to open with mini.files: " .. tostring(err), vim.log.levels.ERROR)
    end
    return ok
  elseif choice == "builtin" then
    local ok, err = open_builtin(path)
    if not ok then
      vim.notify("kotlin.nvim: failed to open directory: " .. tostring(err), vim.log.levels.ERROR)
    end
    return ok
  else
    vim.notify("kotlin.nvim: unknown integrations.file_browser value: " .. vim.inspect(cfg), vim.log.levels.ERROR)
    return false
  end
end

return M
