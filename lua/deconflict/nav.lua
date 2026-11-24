---@mod deconflict.nav Pure next/prev marker lookup

local M = {}

---Find the first marker strictly after `lnum`.
---@param markers Marker[] ascending by lnum
---@param lnum integer 1-indexed reference line
---@param wrap boolean continue from the start of the file when nothing follows
---@return Marker|nil
function M.next(markers, lnum, wrap)
  vim.validate("markers", markers, "table")
  vim.validate("lnum", lnum, "number")
  vim.validate("wrap", wrap, "boolean")
  for _, marker in ipairs(markers) do
    if marker.lnum > lnum then
      return marker
    end
  end
  return wrap and markers[1] or nil
end

---Find the last marker strictly before `lnum`.
---@param markers Marker[] ascending by lnum
---@param lnum integer 1-indexed reference line
---@param wrap boolean continue from the end of the file when nothing precedes
---@return Marker|nil
function M.prev(markers, lnum, wrap)
  vim.validate("markers", markers, "table")
  vim.validate("lnum", lnum, "number")
  vim.validate("wrap", wrap, "boolean")
  for i = #markers, 1, -1 do
    if markers[i].lnum < lnum then
      return markers[i]
    end
  end
  return wrap and markers[#markers] or nil
end

return M
