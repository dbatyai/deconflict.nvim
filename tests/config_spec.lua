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
