-- list adapter: displays a quickfix-shaped list of items in the user's chosen UI.
-- Replaces the inline require("trouble").open("loclist") in lua/kotlin/commands.lua.
--
-- Config values:
--   "auto"      -- detect: trouble → snacks → telescope → fzf_lua → mini.pick → builtin
--   "builtin"   -- vim.fn.setloclist + vim.cmd.lopen
--   "trouble"   -- require("trouble").open("loclist")
--   "snacks"    -- Snacks.picker with a static-list source
--   "telescope" -- builtin location-list picker
--   "fzf_lua"   -- require("fzf-lua").loclist
--   "mini_pick" -- MiniPick.start with a static-source items provider
--   function(items, ctx) ... end
--
-- ctx shape (pinned):
--   { bufnr = number, title = string, source = string }
-- items shape: vim quickfix items — { bufnr, lnum, col, text, filename? }

local M = {}

local function has(mod)
  local ok = pcall(require, mod)
  return ok
end

local function set_loclist(items, ctx)
  vim.fn.setloclist(0, items, "r")
  vim.fn.setloclist(0, {}, "a", { title = ctx.title or "Kotlin" })
end

local function open_builtin(items, ctx)
  set_loclist(items, ctx)
  vim.cmd.lopen()
  return true
end

local function open_trouble(items, ctx)
  local ok, trouble = pcall(require, "trouble")
  if not ok then
    return false, "trouble.nvim not loaded"
  end
  set_loclist(items, ctx)
  return pcall(trouble.open, "loclist")
end

local function open_snacks(items, ctx)
  -- Snacks 2.x: rebuild items into the picker's expected shape and call
  -- Snacks.picker.pick with a static items list. Snacks normalizes loclist
  -- items, so we hand it the same quickfix-shaped table.
  local ok, snacks = pcall(require, "snacks")
  if not ok or not snacks.picker then
    return false, "snacks.picker not loaded"
  end
  return pcall(function()
    snacks.picker.pick({
      source = ctx.source or "kotlin_symbols",
      items = items,
      title = ctx.title or "Kotlin",
      format = "file",
    })
  end)
end

local function open_telescope(items, ctx)
  local ok = has("telescope")
  if not ok then
    return false, "telescope not loaded"
  end
  -- Use the location list as the bridge — telescope's loclist picker reads it.
  set_loclist(items, ctx)
  return pcall(vim.cmd, "Telescope loclist")
end

local function open_fzf_lua(items, ctx)
  local ok, fzf = pcall(require, "fzf-lua")
  if not ok then
    return false, "fzf-lua not loaded"
  end
  set_loclist(items, ctx)
  return pcall(fzf.loclist, { winid = vim.api.nvim_get_current_win() })
end

local function open_mini_pick(items, ctx)
  local ok, mini_pick = pcall(require, "mini.pick")
  if not ok then
    return false, "mini.pick not loaded"
  end
  -- Convert quickfix items to display strings; resolve choice back to {bufnr,lnum,col}.
  local choices = {}
  for _, it in ipairs(items) do
    table.insert(choices, {
      text = string.format("%s:%d  %s", vim.fn.bufname(it.bufnr) or "", it.lnum or 0, it.text or ""),
      bufnr = it.bufnr,
      lnum = it.lnum,
      col = it.col,
    })
  end
  return pcall(function()
    mini_pick.start({
      source = {
        items = choices,
        name = ctx.title or "Kotlin",
        choose = function(item)
          if not item then
            return
          end
          if item.bufnr and vim.api.nvim_buf_is_valid(item.bufnr) then
            vim.api.nvim_set_current_buf(item.bufnr)
          end
          if item.lnum then
            pcall(vim.api.nvim_win_set_cursor, 0, { item.lnum, (item.col or 1) - 1 })
          end
        end,
        show = function(buf_id, items_arr, query)
          mini_pick.default_show(buf_id, vim.tbl_map(function(i)
            return i.text
          end, items_arr), query)
        end,
      },
    })
  end)
end

local function resolve_auto()
  if has("trouble") then
    return "trouble"
  end
  if has("snacks") then
    return "snacks"
  end
  if has("telescope") then
    return "telescope"
  end
  if has("fzf-lua") then
    return "fzf_lua"
  end
  if has("mini.pick") then
    return "mini_pick"
  end
  return "builtin"
end

function M.open(items, ctx)
  ctx = ctx or {}
  local cfg = require("kotlin.adapters").get("list")

  if type(cfg) == "function" then
    return cfg(items, ctx)
  end

  local choice = cfg
  if cfg == "auto" then
    choice = resolve_auto()
  end

  local handlers = {
    builtin = open_builtin,
    trouble = open_trouble,
    snacks = open_snacks,
    telescope = open_telescope,
    fzf_lua = open_fzf_lua,
    mini_pick = open_mini_pick,
  }

  local handler = handlers[choice]
  if not handler then
    vim.notify("kotlin.nvim: unknown integrations.list value: " .. vim.inspect(cfg), vim.log.levels.ERROR)
    return false
  end

  local ok, err = handler(items, ctx)
  if not ok then
    vim.notify(
      "kotlin.nvim: list adapter '" .. tostring(choice) .. "' failed: " .. tostring(err) .. "; falling back to loclist",
      vim.log.levels.WARN
    )
    return open_builtin(items, ctx)
  end
  return true
end

return M
