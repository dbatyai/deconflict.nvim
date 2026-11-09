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
  -- TODO: (design: deconflict.nav) target every marker, matched or not, with marker.lnum > lnum.
  -- With `wrap`, continue from the start of the file: return the first marker, which may be the
  -- marker on `lnum` itself (e.g. the only marker), matching `n` on a single match.
  -- Return nil for an empty list, or when nothing qualifies and `wrap` is false.
  return nil
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
  -- TODO: (design: deconflict.nav) mirror of `next`: marker.lnum < lnum. With `wrap`, continue from the
  -- end of the file: return the last marker, which may be the marker on `lnum` itself (e.g. the only
  -- marker), matching `N` on a single match. Return nil for an empty list, or when nothing qualifies and
  -- `wrap` is false.
  return nil
end

return M
