---@mod deconflict.render Snapshot -> extmarks (range layer + line layer)

local highlight = require("deconflict.highlight")

local M = {}

---Memoized extmark namespace.
---@type integer|nil
local ns = nil

---Get (and lazily create) the plugin's extmark namespace.
---@return integer
function M.namespace()
  if not ns then
    ns = vim.api.nvim_create_namespace("deconflict")
  end
  return ns
end

---Remove all plugin extmarks from a buffer.
---@param bufnr integer
---@return nil
function M.clear(bufnr)
  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_clear_namespace(bufnr, M.namespace(), 0, -1)
  end
  return nil
end

---Map a marker kind to its range and line highlight group names via `highlight.names`.
---@param kind MarkerKind
---@return string range_group e.g. DeconflictMarkerOurs
---@return string line_group e.g. DeconflictMarkerOursLine
local function marker_groups(kind)
  -- TODO: (design: deconflict.render) ours -> names.marker_ours / names.marker_ours_line,
  -- base -> marker_base / marker_base_line, separator -> marker_separator / marker_separator_line,
  -- theirs -> marker_theirs / marker_theirs_line. highlight.names is the single source of group names.
  local _ = kind
  return "", ""
end

---Draw a snapshot's decorations. Does not clear existing extmarks.
---@param bufnr integer
---@param snapshot Snapshot
---@param opts table options as returned by `deconflict.config.get()`
---@return nil
function M.draw(bufnr, snapshot, opts)
  vim.validate("snapshot", snapshot, "table")
  vim.validate("opts", opts, "table")
  -- TODO: (design: Highlight groups / Incoming side) no-op on invalid buffer. Two layers:
  -- 1. Range layer, for EVERY marker in snapshot.markers (matched or not): ranged `hl_group` extmark
  --    over marker_col using the range group from marker_groups(marker.kind), plus one over label_col with highlight.names.label.
  --    Only the run and the label; not the gap between them nor to EOL. Higher priority than layer 2.
  -- 2. Line layer, matched regions only: `line_hl_group` on each marker line
  --    (line group from marker_groups(marker.kind)) and on each body line of ours/base/theirs (empty side: last < first).
  -- Incoming annotation: eol virt_text {opts.incoming_label, names.incoming} on the `theirs` marker when
  -- region.incoming == "theirs", on the `ours` marker when "ours". Suppressed when
  -- opts.highlight_incoming is false, incoming_label is falsy, or region.incoming is nil.
  local _ = { highlight.names, marker_groups }
  return nil
end

return M
