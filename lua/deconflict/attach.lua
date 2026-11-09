---@mod deconflict.attach Per-buffer lifecycle: gate, snapshot, autocmds, keymaps

local config = require("deconflict.config")
local git = require("deconflict.git")
local highlight = require("deconflict.highlight")
local parser = require("deconflict.parser")
local render = require("deconflict.render")

local M = {}

---Augroup used for all plugin autocmds.
local AUGROUP = "Deconflict"

---Per-buffer plugin state.
---@class BufState
---@field attached boolean
---@field snapshot Snapshot|nil last built snapshot
---@field keymaps string[] lhs of buffer-local maps set by the plugin (to remove on detach)
---@field timer uv.uv_timer_t|nil debounce timer

---@type table<integer, BufState>
local states = {}

---Get (and lazily create) the state entry for a buffer.
---@param bufnr integer
---@return BufState
local function get_state(bufnr)
  local state = states[bufnr]
  if not state then
    state = { attached = false, keymaps = {} }
    states[bufnr] = state
  end
  return state
end

---Stop and dispose of a buffer's debounce timer.
---@param state BufState
---@return nil
local function stop_timer(state)
  if state.timer then
    state.timer:stop()
    if not state.timer:is_closing() then
      state.timer:close()
    end
    state.timer = nil
  end
  return nil
end

---Keep only markers referenced by `regions` when the buffer's filetype is strict.
---@param bufnr integer
---@param markers Marker[]
---@param regions Region[]
---@return Marker[]
local function strict_filter(bufnr, markers, regions)
  -- TODO: (design: Strict filetypes) if vim.bo[bufnr].filetype is in config.get().strict_filetypes,
  -- return only markers that are (by identity) in some region.markers, preserving ascending order.
  -- Otherwise return `markers` unchanged.
  local _ = { bufnr, regions }
  return markers
end

---Build a fresh snapshot: scan, match, strict filter, stamp incoming side.
---@param bufnr integer
---@return Snapshot
local function build_snapshot(bufnr)
  local markers = parser.scan_buf(bufnr)
  local regions = parser.match(markers)
  markers = strict_filter(bufnr, markers, regions)

  local incoming = git.incoming_side(bufnr)
  for _, region in ipairs(regions) do
    region.incoming = incoming
  end

  return { tick = vim.api.nvim_buf_get_changedtick(bufnr), markers = markers, regions = regions }
end

---Evaluate the attach gate for a snapshot.
---@param bufnr integer
---@param snapshot Snapshot
---@return boolean
local function eligible(bufnr, snapshot)
  if vim.bo[bufnr].buftype ~= "" then
    return false
  end

  if not git.in_repo(bufnr) then
    return false
  end

  -- TODO: (design: Attach gate) require #snapshot.markers > 0 (already strict-filtered); true if
  -- #snapshot.regions > 0 (no subprocess). Otherwise ask git.unmerged(bufnr, cb): return the cached
  -- boolean if present; while pending return false; cb(true) re-runs M.attach(bufnr) (guard buffer
  -- validity). cb(false) does nothing.
  local _ = snapshot
  return false
end

---Set the buffer-local navigation keymaps.
---@param bufnr integer
---@return nil
local function set_keymaps(bufnr)
  -- TODO: (design: deconflict.config `keymaps`) skip entirely if config.get().keymaps is false; skip an
  -- entry that is false. Do NOT override an lhs that already has a buffer-local or global normal-mode
  -- mapping (check vim.fn.maparg / nvim_buf_get_keymap + nvim_get_keymap). Map `next` -> init.next and
  -- `prev` -> init.prev (require lazily to avoid a cycle). Record mapped lhs in state.keymaps.
  local _ = bufnr
  return nil
end

---Remove the buffer-local keymaps this plugin set.
---@param bufnr integer
---@return nil
local function remove_keymaps(bufnr)
  -- TODO: delete only the lhs recorded in state.keymaps (never user mappings); tolerate invalid buffers.
  local _ = bufnr
  return nil
end

---Rescan, re-gate and redraw a buffer immediately.
---@param bufnr integer
---@return nil
local function do_refresh(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) or not vim.api.nvim_buf_is_loaded(bufnr) then
    return nil
  end

  local snapshot = build_snapshot(bufnr)

  if not eligible(bufnr, snapshot) then
    M.detach(bufnr)
    return nil
  end

  get_state(bufnr).snapshot = snapshot

  render.clear(bufnr)
  render.draw(bufnr, snapshot, config.get())
  return nil
end

---Attach to a buffer if it passes the gate.
---@param bufnr integer
---@return nil
function M.attach(bufnr)
  if M.is_attached(bufnr) then
    return nil
  end

  if not vim.api.nvim_buf_is_valid(bufnr) then
    return nil
  end

  local snapshot = build_snapshot(bufnr)
  if not eligible(bufnr, snapshot) then
    return nil
  end

  local state = get_state(bufnr)
  state.attached = true
  state.snapshot = snapshot
  set_keymaps(bufnr)
  M.refresh(bufnr)
  return nil
end

---Detach from a buffer: clear decorations, drop git cache, remove keymaps.
---@param bufnr integer
---@return nil
function M.detach(bufnr)
  local state = states[bufnr]
  if state then
    stop_timer(state)
    remove_keymaps(bufnr)
  end
  states[bufnr] = nil

  render.clear(bufnr)
  git.invalidate(bufnr)
  return nil
end

---Whether the plugin is currently attached to a buffer.
---@param bufnr integer
---@return boolean
function M.is_attached(bufnr)
  local state = states[bufnr]
  return state ~= nil and state.attached
end

---Debounced: rescan, re-gate, redraw.
---@param bufnr integer
---@return nil
function M.refresh(bufnr)
  local state = get_state(bufnr)

  if not state.timer then
    state.timer = vim.uv.new_timer()
  end

  state.timer:stop()
  state.timer:start(config.get().debounce, 0, function()
    vim.schedule(function()
      do_refresh(bufnr)
    end)
  end)

  return nil
end

---Get a fresh snapshot of a buffer.
---@param bufnr integer
---@return Snapshot
function M.snapshot(bufnr)
  -- TODO: (design: Relationships / control flow) if the cached snapshot's tick differs from
  -- b:changedtick, rebuild synchronously via build_snapshot and cache it (do not redraw; refresh does
  -- that). For an unattached buffer return exactly
  -- { tick = b:changedtick, markers = {}, regions = {} } without scanning and without creating state.
  local _ = build_snapshot
  return { tick = vim.api.nvim_buf_get_changedtick(bufnr), markers = {}, regions = {} }
end

---Create the plugin's autocmds. Idempotent (augroup cleared).
---@return nil
function M.setup_autocmds()
  local group = vim.api.nvim_create_augroup(AUGROUP, { clear = true })

  vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost", "BufEnter", "TextChanged", "InsertLeave" }, {
    group = group,
    callback = function(args)
      if M.is_attached(args.buf) then
        M.refresh(args.buf)
      else
        M.attach(args.buf)
      end
    end,
  })

  vim.api.nvim_create_autocmd("ColorScheme", {
    group = group,
    callback = function()
      highlight.apply()
    end,
  })

  vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
    group = group,
    callback = function(args)
      M.detach(args.buf)
    end,
  })

  vim.api.nvim_create_autocmd({ "FocusGained", "BufWritePost" }, {
    group = group,
    callback = function(args)
      git.invalidate(args.buf)
    end,
  })

  return nil
end

return M
