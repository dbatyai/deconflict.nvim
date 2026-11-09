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

  local label = rest:sub(2)
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
  -- TODO: (design: Data model / Marker recognition) For each line, use `classify`; emit a Marker with
  -- `lnum` (1-indexed). Every marker is emitted, matched or not, ascending lnum. No highlight concerns
  -- here: parser stays dependency-free (render maps kind -> group).
  -- `separator` never carries label/label_col.
  local _ = classify
  return {}
end

---Pass 1 over a buffer's lines.
---@param bufnr integer
---@return Marker[]
function M.scan_buf(bufnr)
  vim.validate("bufnr", bufnr, "number")
  -- TODO: return {} for an invalid buffer; otherwise `M.scan` over all buffer lines.
  return {}
end

---Pass 2: pair scanned markers into regions.
---@param markers Marker[]
---@return Region[]
function M.match(markers)
  vim.validate("markers", markers, "table")
  -- TODO: (design: Matching rules) order ours -> [base] -> separator -> theirs.
  -- - An `ours` before the current region closes discards it and starts a new one.
  -- - Any other out-of-order marker discards the region in progress.
  -- - Unterminated region at EOF is dropped.
  -- - style = "diff3" iff base present, else "merge"; Side ranges are body lines between markers
  --   (empty => last < first).
  -- - Region.markers must reference the SAME Marker tables passed in (no copies).
  -- - incoming stays nil.
  return {}
end

return M
