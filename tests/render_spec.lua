local render = require("deconflict.render")

---Collect all plugin extmarks.
---@param bufnr integer
---@return table[]
local function marks(bufnr)
  return vim.api.nvim_buf_get_extmarks(bufnr, render.namespace(), 0, -1, { details = true })
end

describe("render.namespace", function()
  it("is stable across calls", function()
    eq(render.namespace(), render.namespace())
    eq(vim.api.nvim_create_namespace("deconflict"), render.namespace())
  end)
end)

describe("render.clear", function()
  it("removes every plugin extmark", function()
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "a", "b" })
    vim.api.nvim_buf_set_extmark(bufnr, render.namespace(), 0, 0, { line_hl_group = "Comment" })
    vim.api.nvim_buf_set_extmark(bufnr, render.namespace(), 1, 0, { virt_text = { { "x", "Comment" } } })
    ok(#marks(bufnr) > 0)

    render.clear(bufnr)
    eq(0, #marks(bufnr))

    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)
end)

local parser = require("deconflict.parser")

---Build a scratch buffer and snapshot from lines.
local function setup(lines, incoming)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  local markers = parser.scan(lines)
  local regions = parser.match(markers)
  for _, r in ipairs(regions) do
    r.incoming = incoming
  end
  return bufnr, { tick = 0, markers = markers, regions = regions }
end

local OPTS = { highlight_incoming = true, incoming_label = "Incoming" }

local function ranges(bufnr)
  return vim.tbl_filter(function(m)
    return m[4].hl_group ~= nil
  end, marks(bufnr))
end

---Map 1-indexed line -> line_hl_group.
local function lines_hl(bufnr)
  local out = {}
  for _, m in ipairs(marks(bufnr)) do
    if m[4].line_hl_group then
      out[m[2] + 1] = m[4].line_hl_group
    end
  end
  return out
end

local function virt(bufnr)
  local out = {}
  for _, m in ipairs(marks(bufnr)) do
    if m[4].virt_text then
      out[#out + 1] = { m[2] + 1, m[4].virt_text[1][1], m[4].virt_text[1][2] }
    end
  end
  return out
end

describe("render.draw", function()
  it("draws range marks for stray markers but no line marks", function()
    local bufnr, snap = setup({ "text", "=======", "more" })
    render.draw(bufnr, snap, OPTS)
    local r = ranges(bufnr)
    eq(1, #r)
    eq({ 1, 0, 1, 7, "DeconflictMarkerSeparator" }, { r[1][2], r[1][3], r[1][4].end_row, r[1][4].end_col, r[1][4].hl_group })
    eq({}, lines_hl(bufnr))
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)

  it("uses per-kind range groups and a label range", function()
    local bufnr, snap = setup({ "<<<<<<< HEAD", "a", "||||||| b", "=======", ">>>>>>> x" })
    render.draw(bufnr, snap, OPTS)
    local got = {}
    for _, m in ipairs(ranges(bufnr)) do
      got[#got + 1] = { m[2] + 1, m[3], m[4].end_col, m[4].hl_group }
    end
    table.sort(got, function(a, b)
      return a[1] < b[1] or (a[1] == b[1] and a[2] < b[2])
    end)
    eq({
      { 1, 0, 7, "DeconflictMarkerOurs" },
      { 1, 8, 12, "DeconflictLabel" },
      { 3, 0, 7, "DeconflictMarkerBase" },
      { 3, 8, 9, "DeconflictLabel" },
      { 4, 0, 7, "DeconflictMarkerSeparator" },
      { 5, 0, 7, "DeconflictMarkerTheirs" },
      { 5, 8, 9, "DeconflictLabel" },
    }, got)
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)

  it("draws line marks for matched regions, skipping empty sides and stray markers", function()
    local bufnr, snap = setup({ ">>>>>>> stray", "<<<<<<< a", "|||||||", "o", "=======", "t", ">>>>>>> b" })
    render.draw(bufnr, snap, OPTS)
    eq({
      [2] = "DeconflictMarkerOursLine",
      [3] = "DeconflictMarkerBaseLine",
      [4] = "DeconflictBase",
      [5] = "DeconflictMarkerSeparatorLine",
      [6] = "DeconflictTheirs",
      [7] = "DeconflictMarkerTheirsLine",
    }, lines_hl(bufnr))
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)

  it("gives range marks a higher priority than line marks", function()
    local bufnr, snap = setup({ "<<<<<<< a", "=======", ">>>>>>> b" })
    render.draw(bufnr, snap, OPTS)
    local lo, hi = math.huge, -math.huge
    for _, m in ipairs(marks(bufnr)) do
      if m[4].hl_group then
        lo = math.min(lo, m[4].priority)
      elseif m[4].line_hl_group then
        hi = math.max(hi, m[4].priority)
      end
    end
    ok(lo > hi)
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)

  it("annotates the incoming side", function()
    local lines = { "<<<<<<< a", "=======", ">>>>>>> b" }
    local bufnr, snap = setup(lines, "theirs")
    render.draw(bufnr, snap, OPTS)
    eq({ { 3, "Incoming", "DeconflictIncoming" } }, virt(bufnr))
    vim.api.nvim_buf_delete(bufnr, { force = true })

    bufnr, snap = setup(lines, "ours")
    render.draw(bufnr, snap, { highlight_incoming = true, incoming_label = "IN" })
    eq({ { 1, "IN", "DeconflictIncoming" } }, virt(bufnr))
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)

  it("suppresses the annotation", function()
    local lines = { "<<<<<<< a", "=======", ">>>>>>> b" }
    for _, case in ipairs({
      { "theirs", { highlight_incoming = false, incoming_label = "Incoming" } },
      { "theirs", { highlight_incoming = true, incoming_label = false } },
      { nil, OPTS },
    }) do
      local bufnr, snap = setup(lines, case[1])
      render.draw(bufnr, snap, case[2])
      eq({}, virt(bufnr))
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)

  it("does not clear existing marks", function()
    local bufnr, snap = setup({ "=======" })
    render.draw(bufnr, snap, OPTS)
    render.draw(bufnr, snap, OPTS)
    eq(2, #marks(bufnr))
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)
end)
