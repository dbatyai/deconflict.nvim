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
  local key = "marker_" .. kind
  return highlight.names[key], highlight.names[key .. "_line"]
end

---Priority of the line layer.
local LINE_PRIORITY = 100

---Priority of the range layer (above the line layer).
local RANGE_PRIORITY = 200

---Set a ranged highlight on one line.
---@param bufnr integer
---@param lnum integer 1-indexed
---@param col {[1]: integer, [2]: integer}
---@param group string
---@return nil
local function range_mark(bufnr, lnum, col, group)
  vim.api.nvim_buf_set_extmark(bufnr, M.namespace(), lnum - 1, col[1], {
    end_row = lnum - 1,
    end_col = col[2],
    hl_group = group,
    priority = RANGE_PRIORITY,
  })
  return nil
end

---Set a full-line highlight.
---@param bufnr integer
---@param lnum integer 1-indexed
---@param group string
---@return nil
local function line_mark(bufnr, lnum, group)
  vim.api.nvim_buf_set_extmark(bufnr, M.namespace(), lnum - 1, 0, {
    line_hl_group = group,
    priority = LINE_PRIORITY,
  })
  return nil
end

---Range layer for one marker: marker run and label.
---@param bufnr integer
---@param marker Marker
---@return nil
local function draw_ranges(bufnr, marker)
  local range_group = marker_groups(marker.kind)
  range_mark(bufnr, marker.lnum, marker.marker_col, range_group)
  if marker.label_col then
    range_mark(bufnr, marker.lnum, marker.label_col, highlight.names.label)
  end
  return nil
end

---Line layer for one matched region: marker lines and side bodies.
---@param bufnr integer
---@param region Region
---@return nil
local function draw_lines(bufnr, region)
  for _, marker in pairs(region.markers) do
    local _, line_group = marker_groups(marker.kind)
    line_mark(bufnr, marker.lnum, line_group)
  end
  for _, key in ipairs({ "ours", "base", "theirs" }) do
    local body = region[key]
    if body then
      for lnum = body.first, body.last do
        line_mark(bufnr, lnum, highlight.names[key])
      end
    end
  end
  return nil
end

---Incoming end-of-line annotation for one matched region.
---@param bufnr integer
---@param region Region
---@param opts table
---@return nil
local function draw_incoming(bufnr, region, opts)
  if not opts.highlight_incoming or not opts.incoming_label or not region.incoming then
    return nil
  end
  local marker = region.markers[region.incoming]
  vim.api.nvim_buf_set_extmark(bufnr, M.namespace(), marker.lnum - 1, 0, {
    virt_text = { { opts.incoming_label, highlight.names.incoming } },
    virt_text_pos = "eol",
  })
  return nil
end

---Draw a snapshot's decorations. Does not clear existing extmarks.
---@param bufnr integer
---@param snapshot Snapshot
---@param opts table options as returned by `deconflict.config.get()`
---@return nil
function M.draw(bufnr, snapshot, opts)
  vim.validate("snapshot", snapshot, "table")
  vim.validate("opts", opts, "table")
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return nil
  end

  for _, marker in ipairs(snapshot.markers) do
    draw_ranges(bufnr, marker)
  end
  for _, region in ipairs(snapshot.regions) do
    draw_lines(bufnr, region)
    draw_incoming(bufnr, region, opts)
  end
  return nil
end

return M
