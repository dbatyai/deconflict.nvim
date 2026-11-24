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

local helpers = dofile(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h") .. "/helpers.lua")

describe("deconflict.next / prev", function()
  local LINES = { "x", "<<<<<<< a", "o", "=======", "t", ">>>>>>> b", "y" }

  local function with_buf(fn)
    require("deconflict.config").setup(nil)
    local bufnr, cleanup = helpers.repo_buf(LINES)
    local prev = vim.api.nvim_get_current_buf()
    vim.api.nvim_set_current_buf(bufnr)
    local wrapscan = vim.o.wrapscan
    local okk, err = pcall(fn, bufnr)
    vim.o.wrapscan = wrapscan
    vim.api.nvim_set_current_buf(prev)
    cleanup()
    if not okk then
      error(err, 0)
    end
  end

  local function cursor()
    return vim.api.nvim_win_get_cursor(0)
  end

  it("is a no-op when not attached", function()
    with_buf(function(bufnr)
      deconflict.disable(bufnr) -- BufEnter autocmds may have attached it
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      deconflict.next()
      eq({ 1, 0 }, cursor())
    end)
  end)

  it("moves between markers and honours wrapscan", function()
    with_buf(function(bufnr)
      deconflict.enable(bufnr)
      vim.api.nvim_win_set_cursor(0, { 3, 0 })
      deconflict.next()
      eq({ 4, 0 }, cursor())
      deconflict.prev()
      eq({ 2, 0 }, cursor())

      vim.o.wrapscan = false
      deconflict.prev()
      eq({ 2, 0 }, cursor())
      vim.api.nvim_win_set_cursor(0, { 6, 0 })
      deconflict.next()
      eq({ 6, 0 }, cursor())

      vim.o.wrapscan = true
      deconflict.next()
      eq({ 2, 0 }, cursor())
      deconflict.prev()
      eq({ 6, 0 }, cursor())
    end)
  end)
end)
