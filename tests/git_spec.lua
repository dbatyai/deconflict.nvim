local git = require("deconflict.git")

---Create a throwaway directory tree containing a fake git repository.
---@param opts {gitfile?: boolean, markers?: string[], dirs?: string[]}
---@return string root repository root
---@return string gitdir resolved git directory
local function make_repo(opts)
  opts = opts or {}
  local root = vim.fn.tempname()
  vim.fn.mkdir(root, "p")

  local gitdir
  if opts.gitfile then
    -- Worktree/submodule layout: `.git` is a file pointing at the real gitdir.
    gitdir = root .. "/realgit"
    vim.fn.mkdir(gitdir, "p")
    local fd = assert(io.open(root .. "/.git", "w"))
    fd:write("gitdir: realgit\n")
    fd:close()
  else
    gitdir = root .. "/.git"
    vim.fn.mkdir(gitdir, "p")
  end

  for _, dir in ipairs(opts.dirs or {}) do
    vim.fn.mkdir(gitdir .. "/" .. dir, "p")
  end
  for _, marker in ipairs(opts.markers or {}) do
    local fd = assert(io.open(gitdir .. "/" .. marker, "w"))
    fd:write("deadbeef\n")
    fd:close()
  end

  local fd = assert(io.open(root .. "/file.txt", "w"))
  fd:write("content\n")
  fd:close()

  return root, gitdir
end

---Create a scratch buffer named after a file in `root`.
---@param root string
---@return integer
local function buf_in(root)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(bufnr, root .. "/file.txt")
  git.invalidate(bufnr)
  return bufnr
end

---Run `fn` with a buffer inside a repo built from `opts`, then clean up.
---@param opts table
---@param fn fun(bufnr: integer, root: string, gitdir: string)
---@return nil
local function with_repo(opts, fn)
  local root, gitdir = make_repo(opts)
  local bufnr = buf_in(root)
  local okk, err = pcall(fn, bufnr, root, gitdir)
  vim.api.nvim_buf_delete(bufnr, { force = true })
  git.invalidate(bufnr)
  vim.fn.delete(root, "rf")
  if not okk then
    error(err, 0)
  end
  return nil
end

describe("git.in_repo", function()
  it("is true for a file below a .git directory", function()
    with_repo({}, function(bufnr)
      eq(true, git.in_repo(bufnr))
    end)
  end)

  it("is true for a .git file pointing at another gitdir", function()
    with_repo({ gitfile = true, markers = { "MERGE_HEAD" } }, function(bufnr)
      eq(true, git.in_repo(bufnr))
      eq("merge", git.state(bufnr))
    end)
  end)

  it("is false for a buffer without a name", function()
    local bufnr = vim.api.nvim_create_buf(false, true)
    eq(false, git.in_repo(bufnr))
    is_nil(git.state(bufnr))
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)

  it("is false for a file outside any repository", function()
    local dir = vim.fn.tempname()
    vim.fn.mkdir(dir, "p")
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(bufnr, dir .. "/file.txt")
    git.invalidate(bufnr)

    eq(false, git.in_repo(bufnr))
    is_nil(git.state(bufnr))

    vim.api.nvim_buf_delete(bufnr, { force = true })
    vim.fn.delete(dir, "rf")
  end)
end)

describe("git.state", function()
  it("is nil without an in-progress operation", function()
    with_repo({}, function(bufnr)
      is_nil(git.state(bufnr))
    end)
  end)

  it("detects merge", function()
    with_repo({ markers = { "MERGE_HEAD" } }, function(bufnr)
      eq("merge", git.state(bufnr))
    end)
  end)

  it("detects cherry_pick", function()
    with_repo({ markers = { "CHERRY_PICK_HEAD" } }, function(bufnr)
      eq("cherry_pick", git.state(bufnr))
    end)
  end)

  it("detects revert", function()
    with_repo({ markers = { "REVERT_HEAD" } }, function(bufnr)
      eq("revert", git.state(bufnr))
    end)
  end)

  it("detects rebase from rebase-merge", function()
    with_repo({ dirs = { "rebase-merge" } }, function(bufnr)
      eq("rebase", git.state(bufnr))
    end)
  end)

  it("detects rebase from rebase-apply", function()
    with_repo({ dirs = { "rebase-apply" } }, function(bufnr)
      eq("rebase", git.state(bufnr))
    end)
  end)

  it("prefers rebase over the head-file markers", function()
    with_repo({ dirs = { "rebase-merge" }, markers = { "MERGE_HEAD", "REVERT_HEAD" } }, function(bufnr)
      eq("rebase", git.state(bufnr))
    end)
  end)

  it("prefers cherry_pick over revert and merge", function()
    with_repo({ markers = { "CHERRY_PICK_HEAD", "REVERT_HEAD", "MERGE_HEAD" } }, function(bufnr)
      eq("cherry_pick", git.state(bufnr))
    end)
  end)
end)

describe("git.incoming_side", function()
  it("maps merge to theirs", function()
    with_repo({ markers = { "MERGE_HEAD" } }, function(bufnr)
      eq("theirs", git.incoming_side(bufnr))
    end)
  end)

  it("maps cherry_pick to theirs", function()
    with_repo({ markers = { "CHERRY_PICK_HEAD" } }, function(bufnr)
      eq("theirs", git.incoming_side(bufnr))
    end)
  end)

  it("maps revert to theirs", function()
    with_repo({ markers = { "REVERT_HEAD" } }, function(bufnr)
      eq("theirs", git.incoming_side(bufnr))
    end)
  end)

  it("maps rebase to ours", function()
    with_repo({ dirs = { "rebase-apply" } }, function(bufnr)
      eq("ours", git.incoming_side(bufnr))
    end)
  end)

  it("is nil when no operation is in progress", function()
    with_repo({}, function(bufnr)
      is_nil(git.incoming_side(bufnr))
    end)
  end)
end)

describe("git.invalidate", function()
  it("caches until invalidated", function()
    with_repo({}, function(bufnr, _, gitdir)
      is_nil(git.state(bufnr))

      local fd = assert(io.open(gitdir .. "/MERGE_HEAD", "w"))
      fd:write("x\n")
      fd:close()

      is_nil(git.state(bufnr), "state must still be served from the cache")
      git.invalidate(bufnr)
      eq("merge", git.state(bufnr))
    end)
  end)

  it("clears every entry when called with nil", function()
    with_repo({}, function(bufnr, _, gitdir)
      is_nil(git.state(bufnr))

      local fd = assert(io.open(gitdir .. "/REVERT_HEAD", "w"))
      fd:write("x\n")
      fd:close()

      git.invalidate(nil)
      eq("revert", git.state(bufnr))
    end)
  end)
end)
