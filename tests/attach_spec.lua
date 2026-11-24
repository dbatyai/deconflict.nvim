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

local config = require("deconflict.config")
local helpers = dofile(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h") .. "/helpers.lua")

local CONFLICT = { "<<<<<<< a", "o", "=======", "t", ">>>>>>> b" }

describe("deconflict.attach gate and snapshot", function()
  it("attaches to a file buffer with a matched region", function()
    config.setup(nil)
    local bufnr, cleanup = helpers.repo_buf(CONFLICT)
    attach.attach(bufnr)
    eq(true, attach.is_attached(bufnr))
    eq(1, #attach.snapshot(bufnr).regions)
    attach.detach(bufnr)
    eq(false, attach.is_attached(bufnr))
    cleanup()
  end)

  it("returns an empty snapshot for an unattached buffer", function()
    config.setup(nil)
    local bufnr, cleanup = helpers.repo_buf(CONFLICT)
    eq({ tick = vim.api.nvim_buf_get_changedtick(bufnr), markers = {}, regions = {} }, attach.snapshot(bufnr))
    eq(false, attach.is_attached(bufnr))
    cleanup()
  end)

  it("rescans the snapshot when changedtick moves", function()
    config.setup(nil)
    local bufnr, cleanup = helpers.repo_buf(CONFLICT)
    attach.attach(bufnr)
    eq(3, #attach.snapshot(bufnr).markers)
    vim.api.nvim_buf_set_lines(bufnr, 0, 0, false, { "new", "=======" })
    local snap = attach.snapshot(bufnr)
    eq(vim.api.nvim_buf_get_changedtick(bufnr), snap.tick)
    eq(4, #snap.markers)
    eq(3, snap.regions[1].markers.ours.lnum)
    cleanup()
  end)

  it("strict filetypes drop stray markers and keep matched ones", function()
    config.setup(nil)
    local lines = vim.list_extend({ "Title", "=======" }, CONFLICT)
    local bufnr, cleanup = helpers.repo_buf(lines, "markdown")
    attach.attach(bufnr)
    eq(true, attach.is_attached(bufnr))
    eq({ 3, 5, 7 }, vim.tbl_map(function(m)
      return m.lnum
    end, attach.snapshot(bufnr).markers))
    cleanup()
  end)

  it("strict filetypes do not attach without a matched region", function()
    config.setup(nil)
    local bufnr, cleanup = helpers.repo_buf({ "Title", "=======" }, "markdown")
    attach.attach(bufnr)
    eq(false, attach.is_attached(bufnr))
    cleanup()
  end)

  it("does not attach outside a repo", function()
    config.setup(nil)
    local bufnr = vim.api.nvim_create_buf(false, false)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, CONFLICT)
    attach.attach(bufnr)
    eq(false, attach.is_attached(bufnr))
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)
end)

describe("deconflict.attach pending unmerged answer", function()
  local git = require("deconflict.git")
  local render = require("deconflict.render")
  local STRAY = { "a", "=======", "b" }

  ---Replace `git.unmerged` with a controllable fake for the duration of `body`.
  ---`answer` is the cached value to return (nil = pending); calls record their callbacks.
  ---@param body fun(fake: { answer: boolean|nil, callbacks: function[] })
  local function with_fake_unmerged(body)
    local original = git.unmerged
    local fake = { answer = nil, callbacks = {} }
    git.unmerged = function(_, on_result)
      if fake.answer == nil then
        table.insert(fake.callbacks, on_result)
      end
      return fake.answer
    end
    local okk, err = pcall(body, fake)
    git.unmerged = original
    config.setup(nil)
    assert(okk, err)
  end

  ---Trigger a refresh and wait until the gate has consulted `git.unmerged` (while pending).
  local function refresh_until_queried(bufnr, fake)
    local before = #fake.callbacks
    attach.refresh(bufnr)
    ok(vim.wait(1000, function()
      return #fake.callbacks > before
    end, 5))
  end

  local function marks(bufnr)
    return #vim.api.nvim_buf_get_extmarks(bufnr, render.namespace(), 0, -1, {})
  end

  local function resolve(fake, answer)
    fake.answer = answer
    local callbacks = fake.callbacks
    fake.callbacks = {}
    for _, callback in ipairs(callbacks) do
      callback(answer)
    end
  end

  it("keeps an attached stray-markers-only buffer attached and decorated while pending", function()
    with_fake_unmerged(function(fake)
      config.setup({ debounce = 0 })
      local bufnr, cleanup = helpers.repo_buf(STRAY)
      fake.answer = true
      attach.attach(bufnr)
      eq(true, attach.is_attached(bufnr))
      ok(vim.wait(1000, function()
        return marks(bufnr) > 0
      end, 5))

      fake.answer = nil
      git.invalidate(bufnr)
      refresh_until_queried(bufnr, fake)
      eq(true, attach.is_attached(bufnr))
      ok(marks(bufnr) > 0)

      resolve(fake, false)
      eq(false, attach.is_attached(bufnr))
      eq(0, marks(bufnr))
      cleanup()
    end)
  end)

  it("does not attach an unattached buffer while pending, and attaches once resolved true", function()
    with_fake_unmerged(function(fake)
      config.setup({ debounce = 0 })
      local bufnr, cleanup = helpers.repo_buf(STRAY)
      attach.attach(bufnr)
      eq(1, #fake.callbacks)
      eq(false, attach.is_attached(bufnr))

      resolve(fake, true)
      eq(true, attach.is_attached(bufnr))
      cleanup()
    end)
  end)

  it("stays unattached when the pending answer resolves false", function()
    with_fake_unmerged(function(fake)
      config.setup({ debounce = 0 })
      local bufnr, cleanup = helpers.repo_buf(STRAY)
      attach.attach(bufnr)
      resolve(fake, false)
      eq(false, attach.is_attached(bufnr))
      cleanup()
    end)
  end)
end)
