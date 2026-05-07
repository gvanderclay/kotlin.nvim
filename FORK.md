# Fork Notes

This is a fork of [AlexandrosAlexiou/kotlin.nvim](https://github.com/AlexandrosAlexiou/kotlin.nvim) that decouples the plugin from `oil.nvim`, `trouble.nvim`, and `mason.nvim` by routing those integrations through a small adapter layer with neovim-builtin fallbacks.

## What changed vs upstream

A short, single-purpose patch stack on top of each upstream release tag:

1. **README** — relabel oil/trouble/mason as optional integrations, fix the `:KotlinWorkspaceSymbols` doc/code mismatch, drop the lazy.nvim auto-pulled dependency list.
2. **`lua/kotlin/adapters/`** — three new files (`init.lua`, `file_browser.lua`, `list.lua`, `installer.lua`) that own plugin-vs-builtin dispatch.
3. **`lua/kotlin.lua`** — installer adapter replaces inline `$MASON` path expansion; `setup()` accepts an `integrations` table and configures adapters via `vim.tbl_deep_extend`.
4. **`lua/kotlin/commands.lua`** — `document_symbols` calls the list adapter instead of `require("trouble")`.
5. **`lua/kotlin/package.lua`** — `BufNew` directory autocmd calls the file_browser adapter instead of `require("oil")`.
6. **`lua/kotlin/health.lua`** — `:checkhealth kotlin` no longer treats `mason.nvim` as required and lists every supported optional integration.

Each commit is a single, isolated change so rebasing onto a new upstream tag stays mechanical.

## Integrations API

```lua
require("kotlin").setup({
  integrations = {
    -- file_browser opens directory buffers reached via package navigation.
    -- "auto" probes: oil → mini.files → builtin (vim.cmd.edit).
    file_browser = "auto" | "builtin" | "oil" | "mini_files" | function(path, ctx),

    -- list renders :KotlinSymbols results.
    -- "auto" probes: trouble → snacks → telescope → fzf-lua → mini.pick → builtin (loclist).
    list = "auto" | "builtin" | "trouble" | "snacks" | "telescope" | "fzf_lua" | "mini_pick" | function(items, ctx),

    -- installer resolves the kotlin-lsp install directory.
    -- "auto" probes the mason path convention; falls through to $KOTLIN_LSP_DIR.
    installer = "auto" | "none" | "mason" | function(ctx),
  },

  -- Set lsp.enable = false to skip the FileType autocmd that registers
  -- vim.lsp.config.kotlin_ls. Use this when you manage kotlin LSP setup
  -- yourself (e.g. via after/lsp/kotlin_ls.lua + vim.lsp.enable). Commands,
  -- adapters, file templates, package navigation, and DAP still work.
  lsp = { enable = true },
})
```

### `ctx` shapes (pinned — additions are non-breaking)

```lua
-- file_browser
{ buf = number, prev_buf = number }

-- list
{ bufnr = number, title = string, source = string }

-- installer
{ is_windows = boolean }
```

`items` for the list adapter is a list of vim quickfix items: `{ bufnr, lnum, col, text }`.

### Auto-detection priority

| Adapter | Probe order |
| --- | --- |
| `file_browser` | `oil` → `mini.files` → `vim.cmd.edit` |
| `list` | `trouble` → `snacks` → `telescope` → `fzf-lua` → `mini.pick` → `setloclist` + `:lopen` |
| `installer` | mason path convention → `nil` (caller surfaces `$KOTLIN_LSP_DIR` / actionable error) |

To override the order, set the adapter to a specific named string or pass a function.

## Rebase workflow

The fork lives on a single long-lived branch, `optional-integrations`, rebased onto each upstream release tag.

```bash
git fetch upstream
git rebase upstream/vX.Y.Z optional-integrations
git tag fork/vX.Y.Z+integrations    # so users can pin a stable point
git push origin optional-integrations --force-with-lease
git push origin fork/vX.Y.Z+integrations
```

Conflicts to expect on each rebase:

| File | Likely conflict | Resolution |
| --- | --- | --- |
| `lua/kotlin.lua` | Installer dispatch + `adapters.configure` calls | Keep adapter calls; re-apply upstream changes around them. |
| `lua/kotlin/commands.lua` | The single `adapters.list.open(...)` line | Re-apply if upstream restructures `document_symbols`. |
| `lua/kotlin/package.lua` | The single `adapters.file_browser.open(...)` line | Re-apply if upstream restructures the `BufNew` autocmd. |
| `lua/kotlin/health.lua` | The dependency probe + install probe | Re-apply if upstream adds new optional integrations. |
| `README.md` | Anything in the dependencies / commands sections | Re-apply optional-integrations wording. |

`lua/kotlin/adapters/*` never conflicts — those files do not exist upstream.

## Force-push notice

The rebase workflow rewrites the topic branch's history. If you pin this fork, prefer one of:

- a `fork/vX.Y.Z+integrations` tag (stable; will not move),
- a commit SHA (stable; you opt into rebases by bumping it).

Tracking `optional-integrations` directly works but means a `git pull --rebase` after every upstream release.

## License & attribution (GPL-3.0)

Upstream is GPL-3.0; this fork stays GPL-3.0 (`LICENSE.txt` is preserved verbatim).

GPL-3.0 §5 obligations satisfied by this fork:

- §5(a) — the modified files carry "modified by" notices via this `FORK.md` and the per-commit attribution in git history.
- §5(b) — the modification dates are recorded in commits (`git log`).
- §5(c) — the entire work remains licensed under GPL-3.0.
- §5(d) — when this fork is distributed, sources are available on the public repository.

Original copyright notices in `LICENSE.txt` and any in-source headers are preserved unchanged.

## Scope

This fork only changes the integration plumbing. It does not:

- add Kotlin LSP features upstream lacks,
- support Neovim < 0.11,
- ship its own CI, test suite, or release artifacts,
- diverge from upstream in any way that would justify renaming the plugin.

If you need a feature outside that scope, file the issue upstream first.
