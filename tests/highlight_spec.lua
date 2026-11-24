local highlight = require("deconflict.highlight")

local LINKS = {
  DeconflictMarkerOurs = "DeconflictMarker",
  DeconflictMarkerBase = "DeconflictMarker",
  DeconflictMarkerSeparator = "DeconflictMarker",
  DeconflictMarkerTheirs = "DeconflictMarker",
  DeconflictMarkerOursLine = "DeconflictOurs",
  DeconflictMarkerBaseLine = "DeconflictBase",
  DeconflictMarkerTheirsLine = "DeconflictTheirs",
}

local function clear_all()
  for _, name in pairs(highlight.names) do
    vim.cmd("highlight! link " .. name .. " NONE")
    vim.cmd("highlight clear " .. name)
  end
end

describe("highlight.apply", function()
  it("defines every named group", function()
    clear_all()
    highlight.apply()
    for _, name in pairs(highlight.names) do
      ok(not vim.tbl_isempty(vim.api.nvim_get_hl(0, { name = name })), name .. " undefined")
    end
  end)

  it("sets links and colors per design", function()
    clear_all()
    highlight.apply()
    for name, target in pairs(LINKS) do
      eq(target, vim.api.nvim_get_hl(0, { name = name, link = true }).link, name)
    end
    local marker = vim.api.nvim_get_hl(0, { name = "DeconflictMarker" })
    eq(0xb48ead, marker.fg)
    eq(true, marker.bold)
    eq(0x2b2b2b, vim.api.nvim_get_hl(0, { name = "DeconflictMarkerSeparatorLine" }).bg)
    local inc = vim.api.nvim_get_hl(0, { name = "DeconflictIncoming" })
    eq({ 0xebcb8b, true, true }, { inc.fg, inc.bold, inc.italic })
  end)

  it("does not override a user definition and is idempotent", function()
    clear_all()
    vim.api.nvim_set_hl(0, "DeconflictOurs", { bg = "#123456" })
    highlight.apply()
    highlight.apply()
    eq(0x123456, vim.api.nvim_get_hl(0, { name = "DeconflictOurs" }).bg)
    eq("DeconflictOurs", vim.api.nvim_get_hl(0, { name = "DeconflictMarkerOursLine", link = true }).link)
    clear_all()
    highlight.apply()
  end)
end)

describe("plugin/deconflict.lua bootstrap", function()
  it("defines every group without calling setup()", function()
    local plugin = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h") .. "/plugin/deconflict.lua"
    local loaded = vim.g.loaded_deconflict
    clear_all()
    vim.g.loaded_deconflict = nil
    local done, err = pcall(vim.cmd.source, plugin)
    vim.g.loaded_deconflict = loaded
    ok(done, err)
    for _, name in pairs(highlight.names) do
      ok(not vim.tbl_isempty(vim.api.nvim_get_hl(0, { name = name })), name .. " undefined")
    end
  end)
end)
