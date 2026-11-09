---@mod deconflict.git Git repository state detection

local M = {}

---Per-buffer cache entry shared by `M.in_repo`, `M.state` and `M.unmerged`.
---@class GitCacheEntry
---@field gitdir string|nil resolved git directory, nil when not in a repo
---@field state "merge"|"rebase"|"cherry_pick"|"revert"|nil
---@field unmerged boolean|nil cached `git ls-files --unmerged` answer, nil until known

---@type table<integer, GitCacheEntry>
local cache = {}

---Whether `path` exists and is a directory.
---@param path string
---@return boolean
local function is_dir(path)
  local stat = vim.uv.fs_stat(path)
  return stat ~= nil and stat.type == "directory"
end

---Whether `path` exists as a regular file.
---@param path string
---@return boolean
local function is_file(path)
  local stat = vim.uv.fs_stat(path)
  return stat ~= nil and stat.type == "file"
end

---Read the `gitdir:` pointer out of a `.git` file (worktrees, submodules).
---@param path string path of the `.git` file
---@return string|nil
local function read_gitdir_file(path)
  local fd = io.open(path, "r")
  if not fd then
    return nil
  end

  local content = fd:read("*a")
  fd:close()

  local target = content and content:match("gitdir:%s*(.-)%s*\n") or nil
  if not target or target == "" then
    return nil
  end

  if vim.fs.abspath(target) ~= target then
    target = vim.fs.joinpath(vim.fs.dirname(path), target)
  end

  return vim.fs.normalize(target)
end

---Resolve the git directory governing a buffer's file.
---@param bufnr integer
---@return string|nil
local function resolve_gitdir(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return nil
  end

  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == "" then
    return nil
  end

  local start = vim.fs.dirname(vim.fs.normalize(vim.fn.fnamemodify(name, ":p")))
  local found = vim.fs.find(".git", { path = start, upward = true, limit = 1 })[1]
  if not found then
    return nil
  end

  if is_dir(found) then
    return vim.fs.normalize(found)
  end

  if is_file(found) then
    return read_gitdir_file(found)
  end

  return nil
end

---Detect the in-progress operation inside a git directory.
---@param gitdir string
---@return "merge"|"rebase"|"cherry_pick"|"revert"|nil
local function detect_state(gitdir)
  if is_dir(vim.fs.joinpath(gitdir, "rebase-merge")) or is_dir(vim.fs.joinpath(gitdir, "rebase-apply")) then
    return "rebase"
  end
  if vim.uv.fs_stat(vim.fs.joinpath(gitdir, "CHERRY_PICK_HEAD")) then
    return "cherry_pick"
  end
  if vim.uv.fs_stat(vim.fs.joinpath(gitdir, "REVERT_HEAD")) then
    return "revert"
  end
  if vim.uv.fs_stat(vim.fs.joinpath(gitdir, "MERGE_HEAD")) then
    return "merge"
  end
  return nil
end

---Get (and lazily populate) the cache entry for a buffer.
---@param bufnr integer
---@return GitCacheEntry
local function entry(bufnr)
  local cached = cache[bufnr]
  if cached then
    return cached
  end

  local gitdir = resolve_gitdir(bufnr)
  cached = { gitdir = gitdir, state = gitdir and detect_state(gitdir) or nil }
  cache[bufnr] = cached

  return cached
end

---Check whether the buffer's file lives inside a git repository.
---Shares a single per-buffer cache entry with `M.state`.
---@param bufnr integer
---@return boolean
function M.in_repo(bufnr)
  return entry(bufnr).gitdir ~= nil
end

---Determine the in-progress git operation for the buffer's repository.
---Shares a single per-buffer cache entry with `M.in_repo`.
---@param bufnr integer
---@return "merge"|"rebase"|"cherry_pick"|"revert"|nil
function M.state(bufnr)
  return entry(bufnr).state
end

---Incoming side per in-progress operation.
---@type table<string, "ours"|"theirs">
local INCOMING = {
  merge = "theirs",
  cherry_pick = "theirs",
  revert = "theirs",
  rebase = "ours",
}

---Determine which conflict side is the incoming one.
---Mapping: merge/cherry_pick/revert => "theirs"; rebase => "ours";
---no in-progress operation (nil state) => nil.
---@param bufnr integer
---@return "ours"|"theirs"|nil
function M.incoming_side(bufnr)
  local state = M.state(bufnr)
  return state and INCOMING[state] or nil
end

---Whether git reports the buffer's file as unmerged.
---Returns the cached answer if known; otherwise returns nil and resolves asynchronously.
---@param bufnr integer
---@param on_result fun(unmerged: boolean) called on the main loop once the async answer is known
---@return boolean|nil
function M.unmerged(bufnr, on_result)
  vim.validate("on_result", on_result, "function")
  -- TODO: (design: deconflict.git) if entry(bufnr).unmerged ~= nil return it (no callback).
  -- Otherwise return nil and run `git ls-files --unmerged -- <file>` via vim.system (cwd = file dir),
  -- store the result in the SAME cache entry, then vim.schedule(on_result). Missing git (vim.system
  -- throws) or non-zero exit => false. Non-empty stdout => true. Guard against an entry invalidated
  -- while the job was running (don't resurrect a stale entry). Avoid spawning duplicate jobs per buffer.
  return nil
end

---Drop cached git information.
---@param bufnr integer|nil buffer to invalidate, or all buffers when nil
---@return nil
function M.invalidate(bufnr)
  if bufnr == nil then
    cache = {}
  else
    cache[bufnr] = nil
  end
  return nil
end

return M
