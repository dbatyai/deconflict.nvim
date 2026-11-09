local deconflict = require("deconflict")

describe("deconflict public API", function()
  it("sets up without errors", function()
    deconflict.setup({})
  end)

  it("exposes the render namespace", function()
    eq(require("deconflict.render").namespace(), deconflict.namespace())
  end)

  it("reports unattached buffers as disabled with no regions", function()
    local bufnr = vim.api.nvim_create_buf(false, true)
    eq(false, deconflict.is_enabled(bufnr))
    eq({}, deconflict.get_regions(bufnr))
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)

  it("does not attach to a non-file buffer", function()
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.bo[bufnr].buftype = "nofile"
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "<<<<<<< HEAD", "=======", ">>>>>>> x" })

    deconflict.enable(bufnr)
    eq(false, deconflict.is_enabled(bufnr))

    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)

  it("disable is a no-op on a buffer that was never attached", function()
    local bufnr = vim.api.nvim_create_buf(false, true)
    deconflict.disable(bufnr)
    eq(false, deconflict.is_enabled(bufnr))
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)
end)
