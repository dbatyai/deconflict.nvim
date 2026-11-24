-- Shared spec helpers (not a spec file).
local M = {}

---Create a file buffer (buftype "") inside a fake git repo, with `lines`.
---@param lines string[]
---@param filetype string|nil
---@return integer bufnr
---@return fun() cleanup
function M.repo_buf(lines, filetype)
  local root = vim.fn.tempname()
  vim.fn.mkdir(root .. "/.git", "p")
  local bufnr = vim.api.nvim_create_buf(false, false)
  vim.api.nvim_buf_set_name(bufnr, root .. "/file.txt")
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  if filetype then
    vim.bo[bufnr].filetype = filetype
  end
  require("deconflict.git").invalidate(bufnr)
  return bufnr, function()
    require("deconflict.attach").detach(bufnr)
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
    vim.fn.delete(root, "rf")
  end
end

return M
