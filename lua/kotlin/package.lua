local M = {}

local function is_directory(path)
  local stat = vim.loop.fs_stat(path)
  return stat and stat.type == "directory"
end

function M.setup()
  local group = vim.api.nvim_create_augroup("KotlinDirIntercept", { clear = true })

  vim.api.nvim_create_autocmd("BufNew", {
    group = group,
    callback = function(args)
      local bufname = vim.api.nvim_buf_get_name(args.buf)
      if bufname and bufname ~= "" and is_directory(bufname) then
        vim.schedule(function()
          local prev_buf = vim.fn.bufnr("#")
          local prev_ft = vim.api.nvim_buf_get_option(prev_buf, "filetype") or ""

          if prev_ft == "kotlin" then
            require("kotlin.adapters.file_browser").open(bufname, { buf = args.buf, prev_buf = prev_buf })
          end
        end)
      end
    end,
  })

  -- Fix for oil buffers that get stuck in modified state
  vim.api.nvim_create_autocmd("BufEnter", {
    group = group,
    pattern = "oil://*",
    callback = function()
      vim.bo.modified = false
    end,
  })
end

return M
