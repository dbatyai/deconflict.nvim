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

  ---Filetypes in which only markers belonging to a matched region are kept.
  strict_filetypes = { "markdown", "rst", "asciidoc" },
}

---Currently active options.
---@type table
local options = vim.deepcopy(M.defaults)

---Whether a value is a list of strings.
---@param value any
---@return boolean
local function valid_filetypes(value)
  return type(value) == "table"
    and vim.islist(value)
    and vim.iter(value):all(function(ft)
      return type(ft) == "string"
    end)
end

---Deep-merge user options over the defaults and store them.
---List values (`strict_filetypes`) replace the default list wholesale.
---@param opts table|nil
---@return table options merged options
function M.setup(opts)
  vim.validate("opts", opts, "table", true)

  options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), vim.deepcopy(opts or {}))

  vim.validate("highlight_incoming", options.highlight_incoming, "boolean")
  vim.validate("debounce", options.debounce, "number")
  if opts and opts.strict_filetypes ~= nil then
    options.strict_filetypes = vim.deepcopy(opts.strict_filetypes)
  end

  vim.validate("strict_filetypes", options.strict_filetypes, valid_filetypes, "list of strings")

  return options
end

---Get the currently active options.
---@return table
function M.get()
  return options
end

return M
