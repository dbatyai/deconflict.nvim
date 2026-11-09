local attach = require("deconflict.attach")

---Collect the set of events the refresh autocmd is registered for.
---The refresh autocmd is the only one in the group that covers "TextChanged".
---@return table<string, boolean>
local function refresh_events()
  attach.setup_autocmds()

  local autocmds = vim.api.nvim_get_autocmds({ group = "Deconflict" })
  local events = {}
  for _, autocmd in ipairs(autocmds) do
    events[autocmd.event] = true
  end
  return events
end

describe("deconflict.attach autocmds", function()
  it("registers the refresh autocmd for every event that can change a buffer", function()
    local events = refresh_events()

    for _, event in ipairs({
      "BufReadPost",
      "BufWritePost",
      "BufEnter",
      "TextChanged",
      "InsertLeave",
    }) do
      ok(events[event], "expected a Deconflict autocmd for " .. event)
    end
  end)

  it("does not refresh while still typing in insert mode", function()
    local events = refresh_events()
    is_nil(events["TextChangedI"])
  end)
end)
