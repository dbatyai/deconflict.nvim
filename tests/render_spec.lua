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
