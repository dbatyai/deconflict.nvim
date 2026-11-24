local config = require("deconflict.config")

describe("config.defaults", function()
  it('defaults incoming_label to "Incoming"', function()
    eq("Incoming", config.defaults.incoming_label)
  end)
end)

describe("config.setup", function()
  it("returns the defaults when called without options", function()
    local opts = config.setup(nil)
    eq(true, opts.highlight_incoming)
    eq("Incoming", opts.incoming_label)
    ok(type(opts.debounce) == "number")
  end)

  it("accepts scalar options", function()
    local opts = config.setup({
      highlight_incoming = false,
      incoming_label = "THEIRS",
      debounce = 42,
    })

    eq(false, opts.highlight_incoming)
    eq("THEIRS", opts.incoming_label)
    eq(42, opts.debounce)
  end)

  it("deep-merges nested keys", function()
    local opts = config.setup({ nested = { a = 1 } })
    eq({ a = 1 }, opts.nested)
    eq(100, opts.debounce)
  end)

  it("does not mutate the defaults", function()
    config.setup({ debounce = 999 })
    eq(100, config.defaults.debounce)
  end)
end)

describe("config.get", function()
  it("returns the merged options", function()
    config.setup({ debounce = 7 })
    eq(7, config.get().debounce)
  end)
end)

describe("config.setup lists", function()
  it("defaults strict_filetypes", function()
    local opts = config.setup(nil)
    eq({ "markdown", "rst", "asciidoc" }, opts.strict_filetypes)
  end)

  it("replaces strict_filetypes wholesale", function()
    eq({ "text" }, config.setup({ strict_filetypes = { "text" } }).strict_filetypes)
    eq({}, config.setup({ strict_filetypes = {} }).strict_filetypes)
  end)

  it("rejects invalid values", function()
    ok(not pcall(config.setup, { strict_filetypes = "markdown" }))
    ok(not pcall(config.setup, { strict_filetypes = { 1 } }))
    ok(not pcall(config.setup, { debounce = "x" }))
    config.setup(nil)
  end)
end)
