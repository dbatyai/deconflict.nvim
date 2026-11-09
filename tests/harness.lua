-- Minimal zero-dependency spec harness.
-- Provides `describe`/`it`/`eq`/`ok`/`is_nil` and collects results so that
-- `tests/run.lua` can report pass/fail counts and set the exit status.

local M = {}

---@class SpecFailure
---@field name string
---@field err string

---@type SpecFailure[]
M.failures = {}

---Number of specs that passed.
---@type integer
M.passed = 0

---Current `describe` nesting, used to build readable spec names.
---@type string[]
local stack = {}

---Group a set of specs.
---@param name string
---@param fn fun()
---@return nil
function M.describe(name, fn)
  stack[#stack + 1] = name
  local okk, err = pcall(fn)
  table.remove(stack)
  if not okk then
    M.failures[#M.failures + 1] = { name = name .. " (describe body)", err = tostring(err) }
  end
  return nil
end

---Run a single spec.
---@param name string
---@param fn fun()
---@return nil
function M.it(name, fn)
  local full = table.concat(stack, " > ") .. " > " .. name
  local okk, err = pcall(fn)
  if okk then
    M.passed = M.passed + 1
  else
    M.failures[#M.failures + 1] = { name = full, err = tostring(err) }
  end
  return nil
end

---Assert deep equality.
---@param expected any
---@param actual any
---@param msg string|nil
---@return nil
function M.eq(expected, actual, msg)
  if not vim.deep_equal(expected, actual) then
    error(
      string.format(
        "%sexpected: %s\n     got: %s",
        msg and (msg .. "\n") or "",
        vim.inspect(expected),
        vim.inspect(actual)
      ),
      2
    )
  end
  return nil
end

---Assert truthiness.
---@param value any
---@param msg string|nil
---@return nil
function M.ok(value, msg)
  if not value then
    error(msg or ("expected truthy, got " .. vim.inspect(value)), 2)
  end
  return nil
end

---Assert that a value is nil.
---@param value any
---@param msg string|nil
---@return nil
function M.is_nil(value, msg)
  if value ~= nil then
    error(msg or ("expected nil, got " .. vim.inspect(value)), 2)
  end
  return nil
end

---Install the harness functions as globals for spec files.
---@return nil
function M.install()
  _G.describe = M.describe
  _G.it = M.it
  _G.eq = M.eq
  _G.ok = M.ok
  _G.is_nil = M.is_nil
  return nil
end

return M
