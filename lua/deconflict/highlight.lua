---@mod deconflict.highlight Default highlight group definitions

local M = {}

---Logical key -> highlight group name, covering every group of the design.
---@type table<string, string>
M.names = {
  -- Range groups
  marker = "DeconflictMarker",
  marker_ours = "DeconflictMarkerOurs",
  marker_base = "DeconflictMarkerBase",
  marker_separator = "DeconflictMarkerSeparator",
  marker_theirs = "DeconflictMarkerTheirs",
  label = "DeconflictLabel",
  -- Line groups
  ours = "DeconflictOurs",
  base = "DeconflictBase",
  theirs = "DeconflictTheirs",
  marker_ours_line = "DeconflictMarkerOursLine",
  marker_base_line = "DeconflictMarkerBaseLine",
  marker_separator_line = "DeconflictMarkerSeparatorLine",
  marker_theirs_line = "DeconflictMarkerTheirsLine",
  -- Annotation
  incoming = "DeconflictIncoming",
}

---Default definitions: group name -> `nvim_set_hl` spec (without `default`).
---Links are given as `{ link = <group> }`.
---@type table<string, vim.api.keyset.highlight>
local DEFAULTS = {
  DeconflictMarker = { fg = "#b48ead", bold = true },
  DeconflictMarkerOurs = { link = "DeconflictMarker" },
  DeconflictMarkerBase = { link = "DeconflictMarker" },
  DeconflictMarkerSeparator = { link = "DeconflictMarker" },
  DeconflictMarkerTheirs = { link = "DeconflictMarker" },
  DeconflictLabel = { fg = "#88c0d0", bold = true },
  DeconflictOurs = { bg = "#1f3326" },
  DeconflictBase = { bg = "#2e2b22" },
  DeconflictTheirs = { bg = "#1e2c3f" },
  DeconflictMarkerOursLine = { link = "DeconflictOurs" },
  DeconflictMarkerBaseLine = { link = "DeconflictBase" },
  DeconflictMarkerSeparatorLine = { bg = "#2b2b2b" },
  DeconflictMarkerTheirsLine = { link = "DeconflictTheirs" },
  DeconflictIncoming = { fg = "#ebcb8b", bold = true, italic = true },
}

---Define all default highlight groups with `default = true`. Idempotent.
---@return nil
function M.apply()
  for name, spec in pairs(DEFAULTS) do
    vim.api.nvim_set_hl(0, name, vim.tbl_extend("force", spec, { default = true }))
  end
  return nil
end

return M
