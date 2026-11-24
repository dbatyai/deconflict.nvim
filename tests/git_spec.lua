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

  it("unmerged is false without a repository, with no callback", function()
    local bufnr = vim.api.nvim_create_buf(false, true)
    local called = false
    eq(false, git.unmerged(bufnr, function()
      called = true
    end))
    vim.wait(50)
    eq(false, called)
    git.invalidate(bufnr)
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

  it("FocusGained invalidates non-current buffers too", function()
    require("deconflict.attach").setup_autocmds()
    with_repo({}, function(bufnr, _, gitdir)
      ok(bufnr ~= vim.api.nvim_get_current_buf())
      is_nil(git.state(bufnr))

      local fd = assert(io.open(gitdir .. "/MERGE_HEAD", "w"))
      fd:write("x\n")
      fd:close()

      vim.api.nvim_exec_autocmds("FocusGained", { group = "Deconflict" })
      eq("merge", git.state(bufnr))
    end)
  end)
end)

---Run a git command in `cwd`, erroring on failure (unless allow_fail).
local function run(cwd, args, allow_fail)
  local res = vim.system(vim.list_extend({ "git", "-c", "user.name=t", "-c", "user.email=t@t", "-c", "init.defaultBranch=main" }, args), { cwd = cwd, text = true }):wait()
  if res.code ~= 0 and not allow_fail then
    error(table.concat(args, " ") .. ": " .. (res.stderr or ""))
  end
end

local function write(path, text)
  local fd = assert(io.open(path, "w"))
  fd:write(text)
  fd:close()
end

local function await(bufnr)
  local got
  local first = git.unmerged(bufnr, function(v)
    got = v
  end)
  if first ~= nil then
    return first, true
  end
  ok(vim.wait(5000, function()
    return got ~= nil
  end), "unmerged callback timed out")
  return got, false
end

describe("git.unmerged", function()
  if vim.fn.executable("git") ~= 1 then
    io.stdout:write("SKIP: git.unmerged specs (git not on PATH)\n")
    return
  end

  local root = vim.fn.tempname()
  vim.fn.mkdir(root, "p")
  run(root, { "init", "-q" })
  write(root .. "/c.txt", "base\n")
  write(root .. "/clean.txt", "clean\n")
  run(root, { "add", "." })
  run(root, { "commit", "-qm", "base" })
  run(root, { "checkout", "-qb", "other" })
  write(root .. "/c.txt", "other\n")
  run(root, { "commit", "-qam", "other" })
  run(root, { "checkout", "-q", "main" })
  write(root .. "/c.txt", "main\n")
  run(root, { "commit", "-qam", "main" })
  run(root, { "merge", "-q", "other" }, true)

  local function buf(name)
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(bufnr, root .. "/" .. name)
    git.invalidate(bufnr)
    return bufnr
  end

  it("is true for a conflicted file (async, then cached)", function()
    local bufnr = buf("c.txt")
    eq({ true, false }, { await(bufnr) })
    eq({ true, true }, { await(bufnr) }, "second call served from cache")
    git.invalidate(bufnr)
    eq({ true, false }, { await(bufnr) }, "invalidate forces a new check")
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)

  it("is false for a clean tracked file", function()
    local bufnr = buf("clean.txt")
    eq(false, (await(bufnr)))
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)

  it("does not deliver a result for an entry invalidated mid-flight", function()
    local bufnr = buf("c.txt")
    local called = false
    is_nil(git.unmerged(bufnr, function()
      called = true
    end))
    git.invalidate(bufnr)
    vim.wait(300)
    eq(false, called)
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)

  vim.fn.delete(root, "rf")
end)
