-- Health check module for kotlin.nvim. Run with:
--     :checkhealth kotlin
-- Reports launcher resolution, JRE compatibility, optional dependencies, and
-- (when an LSP client is attached) the negotiated server capabilities.

local M = {}

local h = vim.health or require("health")
local start = h.start or h.report_start
local ok = h.ok or h.report_ok
local warn = h.warn or h.report_warn
local err = h.error or h.report_error
local info = h.info or h.report_info

local function is_windows()
  return vim.fn.has("win32") == 1
end

local function check_neovim()
  start("Neovim")
  if vim.fn.has("nvim-0.11") == 1 then
    ok(("Neovim %s"):format(tostring(vim.version())))
  else
    err("Neovim 0.11+ is required (vim.lsp.foldexpr, vim.lsp.config, …)")
  end
end

local function check_dependencies()
  start("Optional integrations")
  local checks = {
    { mod = "mason", name = "mason.nvim", note = "managed kotlin-lsp install (integrations.installer = 'mason')" },
    { mod = "oil", name = "oil.nvim", note = "package navigation (integrations.file_browser = 'oil')" },
    { mod = "mini.files", name = "mini.files", note = "package navigation (integrations.file_browser = 'mini_files')" },
    { mod = "trouble", name = "trouble.nvim", note = ":KotlinSymbols UI (integrations.list = 'trouble')" },
    { mod = "snacks", name = "snacks.nvim", note = ":KotlinSymbols UI (integrations.list = 'snacks')" },
    { mod = "telescope", name = "telescope.nvim", note = ":KotlinSymbols UI (integrations.list = 'telescope')" },
    { mod = "fzf-lua", name = "fzf-lua", note = ":KotlinSymbols UI (integrations.list = 'fzf_lua')" },
    { mod = "mini.pick", name = "mini.pick", note = ":KotlinSymbols UI (integrations.list = 'mini_pick')" },
    { mod = "dap", name = "nvim-dap", note = ":KotlinDebug" },
  }
  for _, c in ipairs(checks) do
    if pcall(require, c.mod) then
      ok(c.name .. " installed")
    else
      info(("%s not installed (optional — %s)"):format(c.name, c.note))
    end
  end
end

local function check_install()
  start("kotlin-lsp installation")
  local kotlin = require("kotlin")
  local sep = is_windows() and "\\" or "/"

  local installer = require("kotlin.adapters.installer")
  local installer_root = installer.resolve({ is_windows = is_windows() })
  if installer_root then
    info("Installer adapter resolved: " .. installer_root)
  else
    info("Installer adapter: no install dir resolved (integrations.installer = "
      .. vim.inspect(require("kotlin.adapters").get("installer")) .. ")")
  end

  local env_dir = os.getenv("KOTLIN_LSP_DIR")
  if env_dir then
    info("$KOTLIN_LSP_DIR: " .. env_dir)
  end

  local resolved
  if installer_root then
    resolved = kotlin.resolve_kotlin_lsp_dir(installer_root, is_windows())
  end
  if not resolved and env_dir then
    resolved = kotlin.resolve_kotlin_lsp_dir(env_dir, is_windows()) or env_dir
  end

  if not resolved then
    err(installer.format_not_found_error())
    return
  end

  ok("Resolved kotlin_lsp_dir: " .. resolved)

  local lib = resolved .. sep .. "lib"
  if vim.fn.isdirectory(lib) == 1 then
    ok("lib/ directory present")
  else
    err("lib/ directory not found at " .. lib)
  end

  local intellij_server = resolved
    .. sep
    .. "bin"
    .. sep
    .. (is_windows() and "intellij-server.exe" or "intellij-server")
  local legacy = resolved .. sep .. (is_windows() and "kotlin-lsp.cmd" or "kotlin-lsp.sh")

  if vim.fn.executable(intellij_server) == 1 then
    ok("Launcher: bin/intellij-server (v262.4739.0+) — " .. intellij_server)
    if vim.fn.executable(legacy) == 1 then
      info("Legacy " .. legacy .. " also present (deprecated, unused)")
    end
  elseif vim.fn.executable(legacy) == 1 then
    warn("Launcher: " .. legacy .. " (deprecated; will be removed in a future kotlin-lsp release)")
  else
    err("No launcher found. Expected bin/intellij-server or kotlin-lsp.sh under " .. resolved)
  end
end

local function check_jre()
  start("Java runtime")
  local jre = require("kotlin.jre")
  local minimum = jre.minimum_supported_jre_version

  local function probe(label, java_bin, required)
    if vim.fn.executable(java_bin) ~= 1 then
      if required then
        err(label .. " not executable: " .. java_bin)
      else
        info(label .. " not configured")
      end
      return
    end
    if jre.is_supported_version(java_bin) then
      ok(("%s -> %s (>= JDK %d)"):format(label, java_bin, minimum))
    else
      err(("%s -> %s does not satisfy JDK %d minimum"):format(label, java_bin, minimum))
    end
  end

  info(("Minimum JDK required: %d (kotlin-lsp v262.4739.0+)"):format(minimum))

  if vim.env.JAVA_HOME then
    probe("$JAVA_HOME java", vim.env.JAVA_HOME .. "/bin/" .. (is_windows() and "java.exe" or "java"), true)
  else
    info("$JAVA_HOME not set")
  end

  if vim.fn.executable("java") == 1 then
    probe("PATH java", "java", false)
  else
    info("No `java` on PATH")
  end

  info(
    "Note: when bin/intellij-server is the chosen launcher it uses its bundled JBR; the JREs above only matter if you set jre_path or fall back to the manual classpath path."
  )
end

local function check_clients()
  start("Active LSP clients")
  local clients = vim.lsp.get_clients({ name = "kotlin_ls" })

  if #clients == 0 then
    info("No kotlin_ls client attached. Open a .kt file in a Kotlin project to start the server.")
    return
  end

  for _, c in ipairs(clients) do
    ok(("kotlin_ls (id=%d) attached to %d buffer(s)"):format(c.id, vim.tbl_count(c.attached_buffers or {})))
    info("  cmd: " .. vim.inspect(c.config.cmd))

    local caps = c.server_capabilities or {}
    local function cap(name, key)
      if caps[key] then
        ok("  " .. name)
      else
        warn("  " .. name .. " not advertised")
      end
    end
    cap("foldingRangeProvider", "foldingRangeProvider")
    cap("callHierarchyProvider", "callHierarchyProvider")
    cap("inlayHintProvider", "inlayHintProvider")
    cap("typeDefinitionProvider", "typeDefinitionProvider")
    cap("implementationProvider", "implementationProvider")
    cap("renameProvider", "renameProvider")
    cap("documentFormattingProvider", "documentFormattingProvider")

    local provider = caps.executeCommandProvider
    if type(provider) == "table" and provider.commands then
      info("  executeCommands: " .. table.concat(provider.commands, ", "))
      local needed = { "exportWorkspace", "kotlin.organize.imports", "interpolateFileTemplate", "start_debug_server" }
      for _, name in ipairs(needed) do
        if vim.tbl_contains(provider.commands, name) then
          ok("  command available: " .. name)
        else
          warn("  command missing: " .. name)
        end
      end
    end
  end
end

function M.check()
  check_neovim()
  check_dependencies()
  check_install()
  check_jre()
  check_clients()
end

return M
