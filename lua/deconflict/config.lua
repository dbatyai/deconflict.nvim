---@mod deconflict.config Behavioural options

local M = {}

---Default options.
---@type table
M.defaults = {
  ---Enable the incoming annotation.
  highlight_incoming = true,

  ---Annotation text. A falsy value disables it.
  incoming_label = "Incoming",

  ---Redraw debounce, in milliseconds.
  debounce = 100,

  ---Buffer-local navigation maps. `false` disables both; a `false` entry disables only that one.
  ---Keys that already have a buffer-local or global mapping are left alone.
  keymaps = { next = "]x", prev = "[x" },

  ---Filetypes in which only markers belonging to a matched region are kept.
  strict_filetypes = { "markdown", "rst", "asciidoc" },
}

---Currently active options.
---@type table
local options = vim.deepcopy(M.defaults)

---Deep-merge user options over the defaults and store them.
---List values (`strict_filetypes`) replace the default list wholesale.
---@param opts table|nil
---@return table options merged options
function M.setup(opts)
  vim.validate("opts", opts, "table", true)

  options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), vim.deepcopy(opts or {}))

  vim.validate("highlight_incoming", options.highlight_incoming, "boolean")
  vim.validate("debounce", options.debounce, "number")
  -- TODO: (design: deconflict.config) list values replace wholesale: tbl_deep_extend merges list-like
  -- tables index-wise, so if the user supplied `strict_filetypes`, set
  -- options.strict_filetypes = vim.deepcopy(opts.strict_filetypes) after the merge (a shorter user list
  -- must not keep trailing default entries; `{}` must yield `{}`). Everything else stays deep-merge.
  -- Validate `keymaps` (false or table of string|false; `keymaps = false` must survive as `false`) and
  -- `strict_filetypes` (list of strings).

  return options
end

---Get the currently active options.
---@return table
function M.get()
  return options
end

return M
