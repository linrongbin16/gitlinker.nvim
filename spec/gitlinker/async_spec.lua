--- Regression tests for the async runtime.
---
--- Each case here used to lose or misreport an error, which is invisible in a
--- `describe` block that only checks the happy path: the runtime reports
--- failures asynchronously, so a broken path just leaves the task suspended.

describe("gitlinker.async", function()
  local assert_eq = assert.is_equal
  local assert_true = assert.is_true
  local assert_false = assert.is_false

  local async = require("gitlinker.async")

  --- Run the event loop until `pred()` holds, collecting garbage on the way.
  ---
  --- Some failures are only detected once the abandoned callback has actually
  --- been collected, so waiting purely on the event loop is not enough.
  --- @param pred fun(): boolean
  --- @return boolean
  local function wait_until(pred)
    for _ = 1, 200 do
      if pred() then
        return true
      end
      collectgarbage("collect")
      vim.wait(10)
    end
    return pred()
  end

  --- Wait for `task` to settle and return its status plus error.
  --- @param task vim.async.Task
  --- @return boolean ok
  --- @return any err
  local function settle(task)
    assert_true(wait_until(function()
      return task:completed()
    end))
    return task:pwait(0)
  end

  --- Run `fn` with deferred errors captured instead of printed.
  ---
  --- The runtime reports observer errors on a later event-loop turn. That is
  --- the behaviour under test, but an uncaught scheduled error would abort the
  --- whole spec run, so collect them here.
  --- @param fn fun(caught: any[])
  local function with_captured_schedule(fn)
    local caught = {}
    local schedule = vim.schedule
    vim.schedule = function(callback)
      schedule(function()
        local ok, err = pcall(callback)
        if not ok then
          caught[#caught + 1] = err
        end
      end)
    end
    local ok, err = pcall(fn, caught)
    vim.schedule = schedule
    assert_true(ok, tostring(err))
  end

  it("fails the task when its await callback is discarded", function()
    local task = async.run(function()
      -- The callback never reaches the awaitable, so this wait can only be
      -- settled by the GC proxy.
      async.await(1, function(_) end)
    end)

    local ok, err = settle(task)
    assert_false(ok)
    assert_eq(err, "await callback was discarded")
  end)

  it("drops a discarded task from the tracking table", function()
    local task = async.run(function()
      async.await(1, function(_) end)
    end)
    settle(task)

    -- A strong table keeps the task alive until cleanup finishes; once the
    -- discarded await fails, the entry must go away again.
    assert_true(wait_until(function()
      return async._inspect_tree() == ""
    end))
  end)

  it("returns a table error from pcall instead of re-throwing it", function()
    local ok --- @type boolean
    local err --- @type any

    local task = async.run(function()
      ok, err = async.pcall(function()
        error({ code = 42 })
      end)
    end)
    assert_true(settle(task))
    assert_false(ok)
    assert_eq(type(err), "table")
    assert_eq(err.code, 42)
  end)

  it("re-throws a child error from pcall instead of returning it", function()
    local reached_past_pcall = false

    local task = async.run(function()
      async.pcall(function()
        -- `level = 0` keeps the message identical to the one the runtime
        -- builds when a child task fails, without a `file:line:` prefix.
        error("child error: boom", 0)
      end)
      reached_past_pcall = true
    end)

    local ok, err = settle(task)
    assert_false(ok)
    assert_false(reached_past_pcall)
    assert_eq(tostring(err):find("child error: boom", 1, true), 1)
    -- The captured traceback travels with the re-thrown error.
    assert_true(tostring(err):find("stack traceback", 1, true) ~= nil)
  end)

  it("defers an observer error instead of failing the completer", function()
    with_captured_schedule(function(caught)
      local future = async._future()
      local seen = {}

      future:wait(function()
        seen[#seen + 1] = "first"
        error("OBSERVER-BOOM")
      end)
      future:wait(function()
        seen[#seen + 1] = "second"
      end)

      -- Completing must not raise: it used to collect observer errors and
      -- throw them from here, which aborted the caller mid-finalization.
      future:complete(nil, "result")

      assert_true(vim.deep_equal(seen, { "first", "second" }))
      assert_true(wait_until(function()
        return #caught == 1
      end))
      assert_true(tostring(caught[1]):find("OBSERVER-BOOM", 1, true) ~= nil)
    end)
  end)

  it("propagates a child failure even when an observer raises", function()
    with_captured_schedule(function(caught)
      local task = async.run(function()
        local child = async.run(function()
          async.await(1, function(cb)
            vim.defer_fn(cb, 10)
          end)
          error("CHILD-BOOM")
        end)
        -- This observer raises. Before the fix, its error aborted the
        -- finalization of the child and the failure never reached the parent.
        child:wait(function()
          error("OBSERVER-BOOM")
        end)
        async.await(1, function(cb)
          vim.defer_fn(cb, 50)
        end)
      end)

      local ok, err = settle(task)
      assert_false(ok)
      assert_true(tostring(err):find("CHILD-BOOM", 1, true) ~= nil)
      assert_true(#caught >= 1)
    end)
  end)

  it("stringifies an unprintable child error", function()
    local evil = setmetatable({}, {
      __tostring = function()
        error("TOSTRING-BOOM")
      end,
    })

    local task = async.run(function()
      async.run(function()
        error(evil)
      end)
      async.await(1, function(cb)
        vim.defer_fn(cb, 10)
      end)
    end)

    local ok, err = settle(task)
    assert_false(ok)
    assert_eq(err, "child error: <unprintable error>")
  end)
end)
