-- Lazy entry point: registers user commands and bootstraps autocmds.

if vim.g.loaded_deconflict then
  return
end
vim.g.loaded_deconflict = true

vim.api.nvim_create_user_command("DeconflictNext", function()
  require("deconflict").next()
end, { desc = "Jump to the next conflict marker" })

vim.api.nvim_create_user_command("DeconflictPrev", function()
  require("deconflict").prev()
end, { desc = "Jump to the previous conflict marker" })

vim.api.nvim_create_user_command("DeconflictEnable", function()
  require("deconflict").enable()
end, { desc = "Enable conflict highlighting in the current buffer" })

vim.api.nvim_create_user_command("DeconflictDisable", function()
  require("deconflict").disable()
end, { desc = "Disable conflict highlighting in the current buffer" })

require("deconflict.attach").setup_autocmds()
