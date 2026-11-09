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
  -- TODO: (design: Highlight groups) for every entry of DEFAULTS call nvim_set_hl(0, name, spec)
  -- with `default = true` added on a copy (never mutate DEFAULTS). User `:hi` / colorschemes must win.
  -- Re-applied on ColorScheme, so must be safe to call repeatedly.
  local _ = DEFAULTS
  return nil
end

return M
