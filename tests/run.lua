-- Spec runner: `nvim --headless -l tests/run.lua`
-- Loads every `tests/*_spec.lua` file and reports pass/fail counts.

local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.runtimepath:prepend(root)
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path

local harness = dofile(root .. "/tests/harness.lua")
harness.install()

local specs = vim.fn.glob(root .. "/tests/*_spec.lua", false, true)
table.sort(specs)

for _, spec in ipairs(specs) do
  local chunk, err = loadfile(spec)
  if not chunk then
    harness.failures[#harness.failures + 1] = { name = spec, err = tostring(err) }
  else
    local okk, rerr = pcall(chunk)
    if not okk then
      harness.failures[#harness.failures + 1] = { name = spec, err = tostring(rerr) }
    end
  end
end

for _, failure in ipairs(harness.failures) do
  io.stderr:write("FAIL: " .. failure.name .. "\n" .. failure.err .. "\n\n")
end

io.stdout:write(string.format("%d passed, %d failed\n", harness.passed, #harness.failures))
vim.cmd(#harness.failures == 0 and "cquit 0" or "cquit 1")
