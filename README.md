# deconflict.nvim

Highlights git conflict markers (merge, diff3 and zdiff3 styles), marks the incoming side depending on the
operation in progress (merge/cherry-pick/revert: `theirs`; rebase: `ours`), and jumps between markers.
Highlighting is only applied to normal file buffers inside a git repository that contain conflict markers.

Requires Neovim **0.11+** (uses `vim.fs.abspath` and the 0.11 `vim.validate` form). `git` on `$PATH` is
optional: it is only used to check `git ls-files --unmerged` for buffers whose markers don't form a complete
conflict region. Without it, such buffers are not highlighted. Files with complete regions are still highlighted.

## Installation

[lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "dbatyai/deconflict.nvim",
  opts = {},
}
```

Manual:

```lua
vim.opt.runtimepath:append("/path/to/deconflict.nvim")
require("deconflict").setup()
```

The plugin works without `setup()`. On load, `plugin/deconflict.lua` registers the commands, defines the
highlight groups and creates the autocmds. Call `setup()` only to change options.

## Configuration

| Option | Type | Default | Meaning |
|---|---|---|---|
| `highlight_incoming` | `boolean` | `true` | Show the incoming annotation. |
| `incoming_label` | `string\|false\|nil` | `"Incoming"` | Annotation text. A falsy value disables it. |
| `debounce` | `number` | `100` | Redraw debounce, in milliseconds. |
| `strict_filetypes` | `string[]` | `{ "markdown", "rst", "asciidoc" }` | Filetypes where only markers that belong to a complete conflict region are kept. |

A user-supplied `strict_filetypes` list replaces the default list. It is not merged with it.

```lua
require("deconflict").setup({
  highlight_incoming = true,
  incoming_label = "Incoming",
  debounce = 100,
  strict_filetypes = { "markdown", "rst", "asciidoc" },
})
```

Colors are **not** set through options. Use highlight groups instead.

## Highlight groups

All groups are defined with `default = true`, so `:hi` commands and colorschemes override them.

**Range groups**: the marker run and label text. Drawn for every marker.

| Group | Covers | Default |
|---|---|---|
| `DeconflictMarker` | Shared parent for all marker runs | `{ fg = "#b48ead", bold = true }` |
| `DeconflictMarkerOurs` | `<<<<<<<` run | link `DeconflictMarker` |
| `DeconflictMarkerBase` | `\|\|\|\|\|\|\|` run | link `DeconflictMarker` |
| `DeconflictMarkerSeparator` | `=======` run | link `DeconflictMarker` |
| `DeconflictMarkerTheirs` | `>>>>>>>` run | link `DeconflictMarker` |
| `DeconflictLabel` | Text after the marker run (e.g. `HEAD`) | `{ fg = "#88c0d0", bold = true }` |

**Line groups**: full-line background. Drawn only for complete conflict regions.

| Group | Covers | Default |
|---|---|---|
| `DeconflictOurs` | ours body | `{ bg = "#1f3326" }` |
| `DeconflictBase` | base body (diff3/zdiff3) | `{ bg = "#2e2b22" }` |
| `DeconflictTheirs` | theirs body | `{ bg = "#1e2c3f" }` |
| `DeconflictMarkerOursLine` | `<<<<<<<` line | link `DeconflictOurs` |
| `DeconflictMarkerBaseLine` | `\|\|\|\|\|\|\|` line | link `DeconflictBase` |
| `DeconflictMarkerSeparatorLine` | `=======` line | `{ bg = "#2b2b2b" }` |
| `DeconflictMarkerTheirsLine` | `>>>>>>>` line | link `DeconflictTheirs` |

**Annotation**

| Group | Covers | Default |
|---|---|---|
| `DeconflictIncoming` | End-of-line incoming label | `{ fg = "#ebcb8b", bold = true, italic = true }` |

Overrides:

```vim
hi DeconflictMarker guifg=#ff8800 gui=bold
```

```lua
-- Recolour every marker run at once
vim.api.nvim_set_hl(0, "DeconflictMarker", { fg = "#ff8800", bold = true })
vim.api.nvim_set_hl(0, "DeconflictTheirs", { bg = "#20304a" })
```

Because the defaults use `default = true`, your overrides always take precedence over the defaults, whenever
you set them. However, `:colorscheme` clears all highlights. To keep overrides after switching colorschemes,
set them after the colorscheme loads or in a `ColorScheme` autocmd.

## Commands & API

| Command | Action |
|---|---|
| `:DeconflictNext` | Jump to the next marker (honours `'wrapscan'`) |
| `:DeconflictPrev` | Jump to the previous marker (honours `'wrapscan'`) |
| `:DeconflictEnable` | Enable highlighting in the current buffer |
| `:DeconflictDisable` | Disable highlighting in the current buffer |

Lua API (`require("deconflict")`). `bufnr` defaults to the current buffer:

| Function | Description |
|---|---|
| `setup(opts)` | Apply options. Re-defines the highlight groups and autocmds. |
| `enable(bufnr)` | Enable highlighting for a buffer. |
| `disable(bufnr)` | Disable highlighting for a buffer. |
| `is_enabled(bufnr)` | Whether highlighting is active for a buffer. |
| `get_markers(bufnr)` | All markers in the buffer, after the strict-filetype filter. |
| `get_regions(bufnr)` | Complete conflict regions in the buffer. |
| `next()` | Jump to the next marker in the current window. |
| `prev()` | Jump to the previous marker in the current window. |
| `namespace()` | Extmark namespace used for the highlighting. |

There are no default keymaps. Suggested:

```lua
vim.keymap.set("n", "]x", "<Cmd>DeconflictNext<CR>", { desc = "Next conflict marker" })
vim.keymap.set("n", "[x", "<Cmd>DeconflictPrev<CR>", { desc = "Previous conflict marker" })
```

## License

Public domain ([Unlicense](https://unlicense.org/)). See `LICENSE`.
