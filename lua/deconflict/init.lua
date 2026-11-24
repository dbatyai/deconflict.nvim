---@mod deconflict Git conflict marker highlighting

local attach = require("deconflict.attach")
local config = require("deconflict.config")
local highlight = require("deconflict.highlight")
local nav = require("deconflict.nav")
local render = require("deconflict.render")

local M = {}

---Resolve a buffer argument to a concrete buffer number.
---@param bufnr integer|nil
---@return integer
local function resolve(bufnr)
  if bufnr == nil or bufnr == 0 then
    return vim.api.nvim_get_current_buf()
  end
  return bufnr
end

---Jump the current window to the marker found by `find`.
---@param find fun(markers: Marker[], lnum: integer, wrap: boolean): Marker|nil
---@return nil
local function jump(find)
  local bufnr = vim.api.nvim_get_current_buf()
  if not attach.is_attached(bufnr) then
    return nil
  end

  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  local target = find(attach.snapshot(bufnr).markers, lnum, vim.o.wrapscan)
  if target then
    vim.api.nvim_win_set_cursor(0, { target.lnum, 0 })
  end
  return nil
end

---Set up the plugin.
---@param opts table|nil
---@return nil
function M.setup(opts)
  config.setup(opts)
  highlight.apply()
  attach.setup_autocmds()
  return nil
end

---Enable conflict highlighting for a buffer.
---@param bufnr integer|nil defaults to the current buffer
---@return nil
function M.enable(bufnr)
  attach.attach(resolve(bufnr))
  return nil
end

---Disable conflict highlighting for a buffer.
---@param bufnr integer|nil defaults to the current buffer
---@return nil
function M.disable(bufnr)
  attach.detach(resolve(bufnr))
  return nil
end

---Whether conflict highlighting is active for a buffer.
---@param bufnr integer|nil defaults to the current buffer
---@return boolean
function M.is_enabled(bufnr)
  return attach.is_attached(resolve(bufnr))
end

---Get every (strict-filtered) marker of a buffer.
---@param bufnr integer|nil defaults to the current buffer
---@return Marker[]
function M.get_markers(bufnr)
  return attach.snapshot(resolve(bufnr)).markers
end

---Get the matched conflict regions of a buffer. Extension point for future resolution.
---@param bufnr integer|nil defaults to the current buffer
---@return Region[]
function M.get_regions(bufnr)
  return attach.snapshot(resolve(bufnr)).regions
end

---Jump to the next marker in the current window. Honours 'wrapscan'.
---@return nil
function M.next()
  jump(nav.next)
  return nil
end

---Jump to the previous marker in the current window. Honours 'wrapscan'.
---@return nil
function M.prev()
  jump(nav.prev)
  return nil
end

---Extmark namespace used for decorations.
---@return integer
function M.namespace()
  return render.namespace()
end

return M
