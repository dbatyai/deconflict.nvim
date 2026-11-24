---@mod deconflict.parser Conflict marker scanning (pass 1) and matching (pass 2)

---@alias MarkerKind "ours"|"base"|"separator"|"theirs"

---A single conflict marker line, as produced by `scan`.
---@class Marker
---@field kind MarkerKind
---@field lnum integer line number of the marker (1-indexed)
---@field marker_col {[1]: integer, [2]: integer} 0-indexed byte range of the marker run
---@field label string|nil text after the marker; never present on "separator"
---@field label_col {[1]: integer, [2]: integer}|nil 0-indexed byte range of the label

---One side of a conflict region.
---Line numbers are 1-indexed and inclusive; an empty side has `last < first`.
---@class Side
---@field first integer
---@field last integer

---The markers delimiting a region. Same table instances as in `Snapshot.markers`.
---@class RegionMarkers
---@field ours Marker
---@field base Marker|nil
---@field separator Marker
---@field theirs Marker

---A matched conflict region.
---@class Region
---@field style "diff3"|"merge"
---@field ours Side
---@field base Side|nil diff3/zdiff3 only
---@field theirs Side
---@field markers RegionMarkers
---@field incoming "ours"|"theirs"|nil stamped by `attach`, nil from the parser

---A buffer's scan/match result.
---@class Snapshot
---@field tick integer b:changedtick the snapshot was built from
---@field markers Marker[] every marker in the buffer, ascending lnum
---@field regions Region[] matched regions only

local M = {}

---Minimum length of a marker run.
local MIN_RUN = 7

---Marker character -> marker kind.
---@type table<string, MarkerKind>
local KINDS = {
  ["<"] = "ours",
  ["|"] = "base",
  ["="] = "separator",
  [">"] = "theirs",
}

---A classified marker line (without `lnum`).
---@class ParsedMarker
---@field kind MarkerKind
---@field label string|nil
---@field marker_col {[1]: integer, [2]: integer}
---@field label_col {[1]: integer, [2]: integer}|nil

---Classify a line as a conflict marker, if it is one (design: "Marker recognition (scan)").
---@param line string
---@return ParsedMarker|nil
local function classify(line)
  local char = line:sub(1, 1)
  local kind = KINDS[char]
  if not kind then
    return nil
  end

  local run = #(line:match("^" .. vim.pesc(char) .. "+") or "")
  if run < MIN_RUN then
    return nil
  end

  local rest = line:sub(run + 1)

  -- Markers always start at column 0, so the run covers bytes `0..run`.
  local marker_col = { 0, run }

  if kind == "separator" then
    if rest:match("^%s*$") then
      return { kind = kind, marker_col = marker_col }
    end
    return nil
  end

  if rest == "" then
    return { kind = kind, marker_col = marker_col }
  end

  if rest:sub(1, 1) ~= " " then
    return nil
  end

  local label = rest:sub(2):gsub("\r$", "")
  if label == "" then
    return { kind = kind, marker_col = marker_col }
  end

  return {
    kind = kind,
    label = label,
    marker_col = marker_col,
    label_col = { run + 1, run + 1 + #label },
  }
end

---Pass 1: classify every marker line.
---@param lines string[]
---@return Marker[]
function M.scan(lines)
  vim.validate("lines", lines, "table")
  local markers = {}
  for lnum, line in ipairs(lines) do
    local parsed = classify(line)
    if parsed then
      markers[#markers + 1] = {
        kind = parsed.kind,
        lnum = lnum,
        marker_col = parsed.marker_col,
        label = parsed.label,
        label_col = parsed.label_col,
      }
    end
  end
  return markers
end

---Pass 1 over a buffer's lines.
---@param bufnr integer
---@return Marker[]
function M.scan_buf(bufnr)
  vim.validate("bufnr", bufnr, "number")
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return {}
  end
  return M.scan(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false))
end

---Whether a region in progress accepts a marker of `kind` next.
---@param open table<string, Marker> markers collected so far (always has `ours`)
---@param kind MarkerKind
---@return boolean
local function accepts(open, kind)
  if open.separator then
    return kind == "theirs"
  end
  if kind == "base" then
    return open.base == nil
  end
  return kind == "separator"
end

---Body lines strictly between two markers.
---@param from Marker
---@param to Marker
---@return Side
local function side(from, to)
  return { first = from.lnum + 1, last = to.lnum - 1 }
end

---Build a Region from a complete set of markers.
---@param m {ours: Marker, base: Marker|nil, separator: Marker, theirs: Marker}
---@return Region
local function build_region(m)
  return {
    style = m.base and "diff3" or "merge",
    ours = side(m.ours, m.base or m.separator),
    base = m.base and side(m.base, m.separator) or nil,
    theirs = side(m.separator, m.theirs),
    markers = { ours = m.ours, base = m.base, separator = m.separator, theirs = m.theirs },
  }
end

---Pass 2: pair scanned markers into regions.
---@param markers Marker[]
---@return Region[]
function M.match(markers)
  vim.validate("markers", markers, "table")
  local regions = {}
  ---@type table<string, Marker>|nil
  local open = nil

  for _, marker in ipairs(markers) do
    if marker.kind == "ours" then
      open = { ours = marker }
    elseif open and accepts(open, marker.kind) then
      open[marker.kind] = marker
      if marker.kind == "theirs" then
        regions[#regions + 1] = build_region(open)
        open = nil
      end
    else
      open = nil
    end
  end

  return regions
end

return M
