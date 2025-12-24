local util = require('commons.async._util')

local pack_len = util.pack_len
local unpack_len = util.unpack_len
local is_callable = util.is_callable
local gc_fun = util.gc_fun

--- This module implements an asynchronous programming library for Neovim,
--- centered around the principle of **Structured Concurrency**. This design
--- makes concurrent programs easier to reason about, more reliable, and less
--- prone to resource leaks.
---
--- ### Core Philosophy: Structured Concurrency
---
--- Every async operation happens within a "concurrency scope", which is represented
--- by a [vim.async.Task] object created with `vim.async.run()`. This creates a
--- parent-child relationship between tasks, with the following guarantees:
---
--- 1.  **Task Lifetime:** A parent task's scope cannot end until all of its
---     child tasks have completed. The parent *implicitly waits* for its children,
---     preventing orphaned or "fire-and-forget" tasks.
---
--- 2.  **Error Propagation:** If a child task fails with an error, the error is
---     propagated up to its parent.
---
--- 3.  **Cancellation Propagation:** If a parent task is cancelled (e.g., via
---     `:close()`), the cancellation is propagated down to all of its children.
---
--- This model ensures that all concurrent tasks form a clean, hierarchical tree,
--- and control flow is always well-defined.
---
--- ### Stackful vs. Stackless Coroutines (Green Threads)
---
--- A key architectural feature of `async.nvim` is that it is built on Lua's
--- native **stackful coroutines**. This provides a significant advantage over the
--- `async/await` implementations in many other popular languages, though it's
--- important to clarify its role in the "function coloring" problem.
---
--- - **Stackful (Lua, Go):** A stackful coroutine has its own dedicated call
---   stack, much like a traditional OS thread (and are often called "green threads"
---   or "virtual threads"). This allows a coroutine to be suspended from deep
---   within a nested function call. When using `async.nvim`, `vim.async.run()`
---   serves as the explicit entry point to an asynchronous context (similar to
---   Go's `go` keyword). However, *within* that `async.run()` context,
---   intermediate synchronous helper functions do *not* need to be specially
---   marked. This means if function `A` calls `B` calls `C`, and `C` performs
---   an `await`, `A` and `B` can remain regular Lua functions as long as they are
---   called from within an `async.run()` context. This significantly reduces the
---   viral spread of "coloring".
---
--- - **Stackless (JavaScript, Python, Swift, C#, Kotlin):** Most languages
---   implement `async/await` with stackless coroutines. A function that can
---   be suspended must be explicitly marked with a keyword (like `async` or
---   `suspend`). This requirement is "viral"—any function that calls an `async`
---   function must itself be marked `async`, and so on up the call stack. This
---   is the typical "function coloring" problem.
---
--- Because Lua provides stackful coroutines, `async.nvim` allows you to `await`
--- from deeply nested synchronous functions *within an async context* without
--- "coloring" those intermediate callers. This makes concurrent code less
--- intrusive and easier to integrate with existing synchronous code, despite
--- `async.run()` providing an explicit boundary for the async operations.
---
--- ### Key Features
---
--- - **Task Scopes:** Create a new concurrency scope with `vim.async.run()`.
---   The returned [vim.async.Task] object acts as the parent for any other
---   tasks started within its function.
---
--- - **Awaiting:** Suspend execution and wait for an operation to complete using
---   `vim.async.await()`. This can be used on other tasks or on callback-based
---   functions.
---
--- - **Callback Wrapping:** Convert traditional callback-based functions into
---   modern async functions with `vim.async.wrap()`.
---
--- - **Concurrency Utilities:** `await_all`, `await_any`, and `iter` provide
---   powerful tools for managing groups of tasks.
---
--- - **Synchronization Primitives:** `event`, `queue`, and `semaphore` are
---   available for more complex coordination patterns.
---
--- ### Example
---
--- ```lua
--- -- Create an async version of vim.system
--- local system = vim.async.wrap(3, vim.system)
---
--- -- vim.async.run() creates a parent task scope.
--- local parent_task = vim.async.run(function()
---   -- These child tasks are launched within the parent's scope.
---   local ls_task = system({ 'ls', '-l' })
---   local date_task = system({ 'date' })
---
---   -- The parent task will not complete until both ls_task and
---   -- date_task have finished, even without an explicit 'await'.
--- end)
---
--- -- Wait for the parent and all its children to complete.
--- parent_task:wait()
--- ```
---
--- ### Structured Concurrency and Task Scopes
---
--- Every call to `vim.async.run(fn)` creates a new [vim.async.Task] that establishes
--- a concurrency scope. Any other tasks started inside `fn` become children of this
--- task.
---
--- ```lua
--- -- t1 is a top-level task with no parent.
--- local t1 = async.run(function() vim.async.sleep(50) end)
---
--- local main = async.run(function()
---   -- 'child' is created within main's scope, so 'main' is its parent.
---   local child = async.run(function() vim.async.sleep(100) end)
---
---   -- Because 'main' is the parent, it implicitly waits for 'child'
---   -- to complete before it can complete itself.
---
---   -- Cancellation is also propagated down the tree.
---   -- Calling main:close() will also call child:close().
---
---   -- t1 created outside of the main async context.
---   -- It has no parent, so 'main' does not implicitly wait for it.
---   async.await(t1)
--- end)
---
--- -- This will wait for ~100ms, as 'main' must wait for 'child'.
--- main:wait()
--- ```
---
--- If a parent task finishes with an error, it will immediately cancel all of its
--- running child tasks. If it finishes normally, it implicitly waits for them to
--- complete normally.
---
--- ### Comparison with Python's Trio
---
--- The design of `async.nvim` is heavily inspired by Python's `trio` library,
--- and it implements the same core philosophy of **Structured Concurrency**.
--- Both libraries guarantee that all tasks are run in a hierarchy, preventing
--- leaked or "orphaned" tasks and ensuring that cancellation and errors
--- propagate predictably.
---
--- Trio uses an explicit `nursery` object. To spawn child tasks, you must
--- create a nursery scope (e.g., `async with trio.open_nursery() as nursery:`),
--- and the nursery block defines the lifetime of the child tasks.
---
--- async.nvim unifies the concepts of a task and a concurrency scope.
--- The [vim.async.Task] object returned by `vim.async.run()` *is* the scope.
--- In essence, `async.nvim` provides the same safety and clarity as `trio` but
--- adapts the concepts idiomatically for Lua and Neovim.
---
--- ### Comparison with JavaScript's Promises
---
--- JavaScript's `async/await` model with Promises is fundamentally **unstructured**.
--- While tools like `Promise.all` can coordinate multiple promises, the language
--- provides no built-in "scope" that automatically manages child tasks.
---
--- An `async` function call in JavaScript returns a Promise
--- that runs independently. If it is not explicitly awaited, it can easily
--- become an "orphaned" task.
---
--- Cancellation is manual and opt-in via the `AbortController`
--- and `AbortSignal` pattern. It does not automatically propagate from a parent
--- scope to child operations.
---
--- `async.nvim`'s structured model contrasts with this by providing automatic
--- cleanup and cancellation, preventing common issues like resource leaks from
--- forgotten background tasks.
---
--- ### Comparison with Swift Concurrency
---
--- Swift's concurrency model maps closely to `async.nvim`.
---
--- Swift's `TaskGroup` is analogous to the concurrency scope
--- created by `vim.async.run()`. The group's scope cannot exit until all
--- child tasks added to it are complete.
---
--- In both Swift and `async.nvim`, cancelling a parent task
--- automatically propagates a cancellation notice down to all of its children.
---
--- ### Comparison with Kotlin Coroutines
---
--- Kotlin's Coroutine framework is another system built on **Structured Concurrency**,
--- and it shares a nearly identical philosophy with `async.nvim`.
---
--- In Kotlin, a `coroutineScope` function creates a new
--- scope. The scope is guaranteed not to complete until all coroutines
--- launched within it have also completed. This is conceptually the same as
--- the scope created by `vim.async.run()`.
---
--- Like `async.nvim`, cancellation and errors
--- propagate automatically through the task hierarchy. Cancelling a parent scope
--- cancels its children, and an exception in a child will cancel the parent.
---
--- ### Comparison with Go Goroutines
---
--- Go's concurrency model, while powerful, is fundamentally **unstructured**.
--- Launching a `go` routine is a "fire-and-forget" operation with no implicit
--- parent-child relationship.
---
--- Programmers must manually track groups of goroutines,
--- typically using a `sync.WaitGroup` to ensure they all complete before
--- proceeding.
---
--- Cancellation and deadlines are handled by
--- explicitly passing a `context` object through the entire call stack. There
--- is no automatic propagation of cancellation or errors up or down a task tree.
---
--- This contrasts with `async.nvim`, where the structured concurrency model
--- automates the lifetime, cancellation, and error management that must be
--- handled explicitly in Go.
---
--- @class vim.async
local M = {}

-- Use max 32-bit signed int value to avoid overflow on 32-bit systems.
-- Do not use `math.huge` as it is not interpreted as a positive integer on all
-- platforms.
local MAX_TIMEOUT = 2 ^ 31 - 1

--- Weak table to keep track of running tasks
--- @type table<thread,vim.async.Task<any>?>
local threads = setmetatable({}, { __mode = 'k' })

--- Returns the currently running task.
--- @return vim.async.Task<any>?
local function running()
  local task = threads[coroutine.running()]
  if task and not task:completed() then
    return task
  end
end

--- Internal marker used to identify that a yielded value is an asynchronous yielding.
local yield_marker = {}
local resume_marker = {}
local complete_marker = {}

local resume_error = 'Unexpected coroutine.resume()'
local yield_error = 'Unexpected coroutine.yield()'

--- Checks the arguments of a `coroutine.resume`.
--- This is used to ensure that a resume is expected.
--- @generic T
--- @param marker any
--- @param err? any
--- @param ... T...
--- @return T...
local function check_yield(marker, err, ...)
  if marker ~= resume_marker then
    local task = assert(running(), 'Not in async context')
    task:_raise(resume_error)
    -- Return an error to the caller. This will also leave the task in a dead
    -- and unfinshed state
    error(resume_error, 0)
  elseif err then
    error(err, 0)
  end
  return ...
end

--- @class vim.async.Closable
--- @field close fun(self, callback?: fun())
--- @field is_closing? fun(self): boolean

--- Tasks are used to run coroutines in event loops. If a coroutine needs to
--- wait on the event loop, the Task suspends the execution of the coroutine and
--- waits for event loop to restart it.
---
--- Use the [vim.async.run()] to create Tasks.
---
--- To close a running Task use the `close()` method. Calling it will cause the
--- Task to throw a "closed" error in the wrapped coroutine.
---
--- Note a Task can be waited on via more than one waiter.
---
--- @class vim.async.Task<R>: vim.async.Closable
--- @field package _thread thread
--- @field package _future vim.async.Future<R>
--- @field package _closing boolean
---
--- Reference to parent to handle attaching/detaching.
--- @field package _parent? vim.async.Task<any>
--- @field package _parent_children_idx? integer
---
--- Name of the task
--- @field name? string
---
--- Mark task for internal use. Used for awaiting children tasks on complete.
--- @field package _internal? string
---
--- The source line that created this task, used for inspect().
--- @field package _caller? string
---
--- Maintain children as an array to preserve closure order.
--- @field package _children table<integer, vim.async.Task<any>?>
---
--- Pointer to last child in children
--- @field package _children_idx integer
---
--- Tasks can await other async functions (task of callback functions)
--- when we are waiting on a child, we store the handle to it here so we can
--- close it.
--- @field package _awaiting? vim.async.Task|vim.async.Closable
local Task = {}

do --- Task
  Task.__index = Task
  --- @package
  --- @param func function
  --- @param opts? vim.async.run.Opts
  --- @return vim.async.Task
  function Task._new(func, opts)
    local thread = coroutine.create(function(marker, ...)
      check_yield(marker)
      return func(...)
    end)

    opts = opts or {}

    local self = setmetatable({
      name = opts.name,
      _internal = opts._internal,
      _closing = false,
      _is_completing = false,
      _thread = thread,
      _future = M._future(),
      _children = {},
      _children_idx = 0,
    }, Task)

    threads[thread] = self

    if not (opts and opts.detached) then
      self:_attach(running())
    end

    return self
  end

  -- --- @return boolean
  -- function Task:closed()
  --   return self._future._err == 'closed'
  -- end

  --- @package
  function Task:_unwait(cb)
    return self._future:_remove_cb(cb)
  end

  --- Returns whether the Task has completed.
  --- @return boolean
  function Task:completed()
    return self._future:completed()
  end

  --- Add a callback to be run when the Task has completed.
  ---
  --- - If a timeout or `nil` is provided, the Task will synchronously wait for the
  ---   task to complete for the given time in milliseconds.
  ---
  ---   ```lua
  ---   local result = task:wait(10) -- wait for 10ms or else error
  ---
  ---   local result = task:wait() -- wait indefinitely
  ---   ```
  ---
  --- - If a function is provided, it will be called when the Task has completed
  ---   with the arguments:
  ---   - (`err: string`) - if the Task completed with an error.
  ---   - (`nil`, `...:any`) - the results of the Task if it completed successfully.
  ---
  ---
  --- If the Task is already done when this method is called, the callback is
  --- called immediately with the results.
  --- @param callback_or_timeout integer|fun(err?: any, ...: R...)?
  --- @overload fun(timeout?: integer): R...
  function Task:wait(callback_or_timeout)
    if is_callable(callback_or_timeout) then
      self._future:wait(callback_or_timeout)
      return
    end

    if
      not vim.wait(callback_or_timeout or MAX_TIMEOUT, function()
        return self:completed()
      end)
    then
      error('timeout', 2)
    end

    local res = pack_len(self._future:result())

    assert(self:status() == 'completed' or res[2] == yield_error)

    if not res[1] then
      error(res[2], 2)
    end

    return unpack_len(res, 2)
  end

  --- Protected-call version of `wait()`.
  ---
  --- Does not throw an error if the task fails or times out. Instead, returns
  --- the status and the results.
  --- @param timeout integer?
  --- @return boolean, R...
  function Task:pwait(timeout)
    vim.validate('timeout', timeout, 'number', true)
    return pcall(self.wait, self, timeout)
  end

  --- @package
  --- @param parent? vim.async.Task
  function Task:_attach(parent)
    if parent then
      -- Attach to parent
      parent._children_idx = parent._children_idx + 1
      parent._children[parent._children_idx] = self

      -- Keep track of the parent and this tasks index so we can detach
      self._parent = parent
      self._parent_children_idx = parent._children_idx
    end
  end

  --- Detach a task from its parent.
  ---
  --- The task becomes a top-level task.
  --- @return vim.async.Task
  function Task:detach()
    if self._parent then
      self._parent._children[self._parent_children_idx] = nil
      self._parent = nil
      self._parent_children_idx = nil
    end
    return self
  end

  --- Get the traceback of a task when it is not active.
  --- Will also get the traceback of nested tasks.
  ---
  --- @param msg? string
  --- @param level? integer
  --- @return string traceback
  function Task:traceback(msg, level)
    level = level or 0

    local thread = ('[%s] '):format(self._thread)

    local awaiting = self._awaiting
    if getmetatable(awaiting) == Task then
      --- @cast awaiting vim.async.Task
      msg = awaiting:traceback(msg, level + 1)
    end

    local tblvl = getmetatable(awaiting) == Task and 2 or nil
    msg = (tostring(msg) or '')
      .. debug.traceback(self._thread, '', tblvl):gsub('\n\t', '\n\t' .. thread)

    if level == 0 then
      --- @type string
      msg = msg
        :gsub('\nstack traceback:\n', '\nSTACK TRACEBACK:\n', 1)
        :gsub('\nstack traceback:\n', '\n')
        :gsub('\nSTACK TRACEBACK:\n', '\nstack traceback:\n', 1)
    end

    return msg
  end

  --- If a task completes with an error, raise the error
  --- @return vim.async.Task self
  function Task:raise_on_error()
    self:wait(function(err)
      if err then
        error(self:traceback(err), 0)
      end
    end)
    return self
  end

  --- @package
  --- @param err any
  function Task:_raise(err)
    if self:status() == 'running' then
      -- TODO(lewis6991): is there a better way to do this?
      vim.schedule(function()
        self:_resume(err)
      end)
    else
      self:_resume(err)
    end
  end

  --- Close the task and all of its children.
  --- If callback is provided it will run asynchronously,
  --- else it will run synchronously.
  ---
  --- @param callback? fun()
  function Task:close(callback)
    if not self:completed() and not self._closing and not self._is_completing then
      self._closing = true
      self:_raise('closed')
    end
    if callback then
      self:wait(function()
        callback()
      end)
    end
  end

  --- Complete a task with the given values, cancelling any remaining work.
  ---
  --- This marks the task as successfully completed and notifies any waiters with
  --- the provided values. It also initiates the cancellation of all
  --- running child tasks.
  ---
  --- A primary use case is for "race" scenarios. A child task can acquire a
  --- reference to its parent task and call `complete()` on it. This signals
  --- that the overall goal of the parent scope has been met, which immediately
  --- triggers the cancellation of all sibling tasks.
  ---
  --- This provides a built-in pattern for "first-to-finish" logic, such as
  --- querying multiple data sources and taking the first response.
  ---
  --- @param ... any The values to complete the task with.
  function Task:complete(...)
    if self:completed() or self._closing or self._is_completing then
      error('Task is already completing or completed', 2)
    end
    self._is_completing = true
    self:_raise({ complete_marker, pack_len(...) })
  end

  --- Checks if an object is closable, i.e., has a `close` method.
  --- @param obj any
  --- @return boolean
  --- @return_cast obj vim.async.Closable
  local function is_closable(obj)
    local ty = type(obj)
    return (ty == 'table' or ty == 'userdata') and is_callable(obj.close)
  end

  do -- Task:_resume()
    --- @private
    --- @param stat boolean
    --- @param ...R... result
    function Task:_finalize0(stat, ...)
      -- TODO(lewis6991): should we collect all errors?
      for _, child in pairs(self._children) do
        if not stat then
          child:close()
        end
        -- If child fails then it will resume the parent with an error
        -- which is handled below
        pcall(M.await, child)
      end

      local parent = self._parent
      self:detach()

      threads[self._thread] = nil

      if not stat then
        local err = ...
        if type(err) == 'table' and err[1] == complete_marker then
          self._future:complete(nil, unpack_len(err[2]))
        else
          local err_msg = err or 'unknown error'
          self._future:complete(err_msg)
          if parent and not self._closing then
            parent:_raise('child error: ' .. tostring(err_msg))
          end
        end
      else
        self._future:complete(nil, ...)
      end
    end

    --- @private
    --- Should only be called in Task:_resume_co()
    --- @param stat boolean
    --- @param ...R... result
    function Task:_finalize(stat, ...)
      -- Only run self._finalize0() directly if there are children, otherwise
      -- this will cause infinite recursion:
      --   M.run() -> task:_resume() -> resume_co() -> complete_task() -> M.run()
      if next(self._children) ~= nil then
        -- TODO(lewis6991): should this be detached?
        M.run({ _internal = true, name = 'await_children' }, self._finalize0, self, stat, ...)
      else
        self:_finalize0(stat, ...)
      end
    end

    --- @param thread thread
    --- @param on_finish fun(stat: boolean, ...:any)
    --- @param stat boolean
    --- @return fun(callback: fun(...:any...): vim.async.Closable?)?
    local function handle_co_resume(thread, on_finish, stat, ...)
      if coroutine.status(thread) == 'dead' then
        on_finish(stat, ...)
        return
      end

      local marker, fn = ...

      if marker ~= yield_marker or not is_callable(fn) then
        on_finish(false, yield_error)
        return
      end

      return fn
    end

    --- @param awaitable fun(callback: fun(...:any...): vim.async.Closable?)
    --- @param on_defer fun(err?:any, ...:any)
    --- @return any[]? next_args
    --- @return vim.async.Closable? closable
    local function handle_awaitable(awaitable, on_defer)
      local ok, closable_or_err
      local settled = false
      local next_args --- @type any[]?
      ok, closable_or_err = pcall(awaitable, function(...)
        if settled then
          -- error here?
          return
        end
        settled = true

        if ok == nil then
          next_args = pack_len(...)
        else
          on_defer(...)
        end
      end)

      if not ok then
        return pack_len(closable_or_err)
      elseif is_closable(closable_or_err) then
        return next_args, closable_or_err
      else
        return next_args
      end
    end

    --- @param task vim.async.Task
    --- @param awaiting vim.async.Task|vim.async.Closable
    --- @return boolean
    local function can_close_awaiting(task, awaiting)
      if getmetatable(awaiting) ~= Task then
        return true
      end

      for _, child in pairs(task._children) do
        if child == awaiting then
          return true
        end
      end

      return false
    end

    --- Handle closing an awaitable if needed
    --- @param task vim.async.Task
    --- @param awaiting vim.async.Closable?
    --- @param on_continue fun()
    --- @return boolean should_return
    --- @return {[integer]: any, n: integer}? new_args
    local function handle_close_awaiting(task, awaiting, on_continue)
      if not awaiting or not can_close_awaiting(task, awaiting) then
        return false, nil
      end

      -- Check if the awaitable is already closing (if it has an is_closing method)
      local already_closing = false
      if type(awaiting.is_closing) == 'function' then
        already_closing = awaiting:is_closing()
      end

      if already_closing then
        -- Already closing, just continue without calling close
        task._awaiting = nil
        on_continue()
        return true, nil
      end

      -- We must close the closable child before we resume to ensure
      -- all resources are collected.
      --- @diagnostic disable-next-line: param-type-not-match
      local close_ok, close_err = pcall(awaiting.close, awaiting, function()
        task._awaiting = nil
        on_continue()
      end)

      if close_ok then
        -- will call on_continue in close callback
        return true, nil
      end

      -- Close failed (synchronously) raise error
      return false, pack_len(close_err)
    end

    --- @package
    --- @param ... any the first argument is the error, except for when the coroutine begins
    function Task:_resume(...)
      --- @type {[integer]: any, n: integer}?
      local args = pack_len(...)

      -- Run this block in a while loop to run non-deferred continuations
      -- without a new stack frame.
      while args do
        -- TODO(lewis6991): Add a test that handles awaiting in the non-deferred
        -- continuation
        if self._is_completing and select(1, ...) == 'closed' then
          return
        end

        local should_return, close_err_args = handle_close_awaiting(self, self._awaiting, function()
          self:_resume(unpack_len(args))
        end)
        if should_return then
          return
        end

        args = close_err_args or args

        -- Check the coroutine is still alive before trying to resume it
        if coroutine.status(self._thread) == 'dead' then
          -- Can only happen if coroutine.resume() is called outside of this
          -- function. When that happens check_yield() will error the coroutine
          -- which puts it in the 'dead' state.
          self:_finalize(false, (...))
          return
        end

        -- Level-triggered cancellation: if the task is closing and the coroutine
        -- completed successfully (e.g., after pcall caught the cancellation and
        -- then did another await), override the success with "closed" error.
        -- This ensures cancellations persist across pcall catches.
        local awaitable = handle_co_resume(self._thread, function(stat2, ...)
          if self._closing and stat2 then
            self:_finalize(false, 'closed')
          else
            self:_finalize(stat2, ...)
          end
        end, coroutine.resume(self._thread, resume_marker, unpack_len(args)))

        if not awaitable then
          return
        end

        args, self._awaiting = handle_awaitable(awaitable, function(...)
          if not self:completed() then
            self:_resume(...)
          end
        end)
      end
    end
  end

  --- @package
  function Task:_log(...)
    print(tostring(self._thread), ...)
  end

  --- Returns the status of the task:
  --- - 'running'    : task is running (that is, is called `status()`).
  --- - 'normal'     : task is active but not running (e.g. it is starting
  ---                  another task).
  --- - 'awaiting'   : if the task is awaiting another task either directly via
  ---                  `await()` or waiting for all children to complete.
  --- - 'completed'  : task and all it's children have completed
  --- @return 'running'|'awaiting'|'normal'|'scheduled'|'completed'
  function Task:status()
    local co_status = coroutine.status(self._thread)
    if co_status == 'dead' then
      return self:completed() and 'completed' or 'awaiting'
    elseif co_status == 'suspended' then
      return 'awaiting'
    elseif co_status == 'normal' then
      -- TODO(lewis6991): This state is a bit ambiguous. If all tasks
      -- are started from the main thread, then we can remove this state.
      -- Though it still may be possible if the user resumes a non-task
      -- coroutine.
      return 'normal'
    end
    assert(co_status == 'running')
    return 'running'
  end
end

do --- M.run
  --- @class vim.async.run.Opts
  --- @field name? string
  --- @field detached? boolean
  --- @field package _internal? boolean

  --- @package
  --- @generic T, R
  --- @param opts? vim.async.run.Opts
  --- @param func async fun(...:T...): R... Function to run in an async context
  --- @param ... T... Arguments to pass to the function
  --- @return vim.async.Task<R...>
  local function run(opts, func, ...)
    vim.validate('opts', opts, 'table', true)
    vim.validate('func', func, 'callable')
    -- TODO(lewis6991): add task names
    local task = Task._new(func, opts)
    local info = debug.getinfo(2, 'Sl')
    if info and info.currentline then
      task._caller = ('%s:%d'):format(info.source, info.currentline)
    end
    task:_resume(...)
    return task
  end

  --- Run a function in an async context, asynchronously.
  ---
  --- Returns an [vim.async.Task] object which can be used to wait or await the result
  --- of the function.
  ---
  --- Examples:
  --- ```lua
  --- -- Run a uv function and wait for it
  --- local stat = vim.async.run(function()
  ---     return vim.async.await(2, vim.uv.fs_stat, 'foo.txt')
  --- end):wait()
  ---
  --- -- Since uv functions have sync versions, this is the same as:
  --- local stat = vim.fs_stat('foo.txt')
  --- ```
  --- @generic T, R
  --- @param func async fun(...:T...): R...
  --- @return vim.async.Task<R...>
  --- @overload fun(name: string, func: async fun(...:T...), ...: T...): vim.async.Task<R...>
  --- @overload fun(opts: vim.async.run.Opts, func: async fun(...:T...), ...: T...): vim.async.Task<R...>
  function M.run(func, ...)
    if type(func) == 'string' then
      return run({ name = func }, ...)
    elseif type(func) == 'table' then
      return run(func, ...)
    elseif is_callable(func) then
      return run(nil, func, ...)
    end
    error('Invalid arguments')
  end
end

do --- M.await()
  --- @generic T, R
  --- @param argc integer
  --- @param fun fun(...: T..., callback: fun(...: R...))
  --- @param ... T... func arguments
  --- @return fun(callback: fun(...: R...))
  local function norm_cb_fun(argc, fun, ...)
    local args = pack_len(...)

    --- @param callback fun(...:any)
    --- @return any?
    return function(callback)
      args[argc] = function(...)
        callback(nil, ...)
      end
      args.n = math.max(args.n, argc)
      return fun(unpack_len(args))
    end
  end

  --- Asynchronous blocking wait
  ---
  --- Example:
  --- ```lua
  --- local task = vim.async.run(function()
  ---    return 1, 'a'
  --- end)
  ---
  --- local task_fun = vim.async.async(function(arg)
  ---    return 2, 'b', arg
  --- end)
  ---
  --- vim.async.run(function()
  ---   do -- await a callback function
  ---     vim.async.await(1, vim.schedule)
  ---   end
  ---
  ---   do -- await a callback function (if function only has a callback argument)
  ---     vim.async.await(vim.schedule)
  ---   end
  ---
  ---   do -- await a task (new async context)
  ---     local n, s = vim.async.await(task)
  ---     assert(n == 1 and s == 'a')
  ---   end
  ---
  --- end)
  --- ```
  --- @async
  --- @generic T, R
  --- @param ... any see overloads
  --- @overload async fun(func: (fun(callback: fun(...:R...)): vim.async.Closable?)): R...
  --- @overload async fun(argc: integer, func: (fun(...:T..., callback: fun(...:R...)): vim.async.Closable?), ...:T...): R...
  --- @overload async fun(task: vim.async.Task<R>): R...
  function M.await(...)
    local task = running()
    assert(task, 'Not in async context')

    -- TODO(lewis6991): needs test coverage. Happens when a task pcalls an await
    if task._closing then
      error('closed', 0)
    end

    local arg1 = select(1, ...)

    local fn --- @type fun(...:R...): vim.async.Closable?
    if type(arg1) == 'number' then
      fn = norm_cb_fun(...)
    elseif type(arg1) == 'function' then
      fn = norm_cb_fun(1, arg1)
    elseif getmetatable(arg1) == Task then
      fn = function(callback)
        --- @cast arg1 vim.async.Task<R>
        arg1:wait(callback)
        return arg1
      end
    else
      error('Invalid arguments, expected Task or (argc, func) got: ' .. vim.inspect(arg1), 2)
    end

    return check_yield(coroutine.yield(yield_marker, fn))
  end
end

--- Returns true if the current task has been closed.
---
--- Can be used in an async function to do cleanup when a task is closing.
--- @return boolean
function M.is_closing()
  local task = running()
  return task and task._closing or false
end

--- Protected call for async functions that propagates child task errors.
---
--- Similar to Lua's built-in `pcall`, but with special handling for child task
--- errors. This function will:
--- - Catch regular errors (return `false, err`)
--- - Propagate child task errors (re-throw them)
--- - Propagate cancellation errors (re-throw them)
---
--- This is useful when you want to handle regular errors locally, but allow
--- child task failures to bubble up to the parent task, maintaining the
--- structured concurrency guarantees.
---
--- Note: This function uses `xpcall` with a custom error handler to capture the
--- full stack trace before the stack is unwound. When re-throwing child errors
--- or cancellation errors, the traceback is preserved. Regular errors are
--- caught and returned with their error messages as usual.
---
--- Example:
--- ```lua
--- vim.async.run(function()
---   local child = vim.async.run(function()
---     vim.async.sleep(10)
---     error('CHILD_FAILED')
---   end)
---
---   -- Regular pcall would catch the child error
---   local ok1, err1 = pcall(function()
---     vim.async.sleep(100)
---   end)
---   -- ok1 = false, err1 = 'child error: CHILD_FAILED'
---
---   -- async.pcall propagates child errors
---   local ok2, err2 = vim.async.pcall(function()
---     error('REGULAR_ERROR')
---   end)
---   -- ok2 = false, err2 = 'REGULAR_ERROR'
---
---   -- But child errors propagate:
---   vim.async.pcall(function()
---     vim.async.sleep(100)
---   end)
---   -- This will error with 'child error: CHILD_FAILED'
--- end)
--- ```
---
--- @async
--- @generic T
--- @param fn async fun(): T...
--- @return boolean ok
--- @return any|T... err_or_result
function M.pcall(fn)
  vim.validate('fn', fn, 'callable')

  local captured_traceback
  local results = pack_len(xpcall(fn, function(err)
    -- Error handler runs before stack is unwound
    -- Capture the full traceback here
    captured_traceback = debug.traceback(err, 2)

    -- Check if this is a child error or cancellation
    if type(err) == 'string' then
      if err:match('^child error: ') or err == 'closed' then
        -- For child errors/cancellations, return the traceback so it can be re-thrown
        return captured_traceback
      end
    end

    -- For regular errors, just return the error message
    return err
  end))

  local ok = results[1]

  if not ok then
    local err = results[2]
    -- If this is a child error or cancellation, re-throw with the full traceback
    if err == captured_traceback then
      -- This is a child error or cancellation - re-throw it
      error(err, 0)
    end
  end

  return unpack_len(results)
end

--- Creates an async function from a callback style function.
---
--- `func` can optionally return an object with a close method to clean up
--- resources. Note this method will be called when the task finishes or
--- interrupted.
---
--- Example:
---
--- ```lua
--- --- Note the callback argument is not present in the return function
--- --- @type async fun(timeout: integer)
--- local sleep = vim.async.wrap(2, function(timeout, callback)
---   local timer = vim.uv.new_timer()
---   timer:start(timeout * 1000, 0, callback)
---   -- uv_timer_t provides a close method so timer will be
---   -- cleaned up when this function finishes
---   return timer
--- end)
---
--- vim.async.run(function()
---   print('hello')
---   sleep(2)
---   print('world')
--- end)
--- ```
---
--- @generic T, R
--- @param argc integer
--- @param func fun(...: T..., callback: fun(...: R...)): vim.async.Closable?
--- @return async fun(...:T...): R...
function M.wrap(argc, func)
  vim.validate('argc', argc, 'number')
  vim.validate('func', func, 'callable')
  --- @async
  return function(...)
    return M.await(argc, func, ...)
  end
end

do --- M.iter(), M.await_all(), M.await_any()
  --- @async
  --- @generic R
  --- @param tasks vim.async.Task<R>[] A list of tasks to wait for and iterate over.
  --- @return async fun(): (integer?, any?, ...R) iterator that yields the index, error, and results of each task.
  local function iter(tasks)
    vim.validate('tasks', tasks, 'table')

    -- TODO(lewis6991): do not return err, instead raise any errors as they occur
    assert(running(), 'Not in async context')

    local remaining = #tasks
    local queue = M._queue()

    -- Keep track of the callbacks so we can remove them when the iterator
    -- is garbage collected.
    --- @type table<vim.async.Task<any>,function>
    local task_cbs = setmetatable({}, { __mode = 'v' })

    -- Wait on all the tasks. Keep references to the task futures and wait
    -- callbacks so we can remove them when the iterator is garbage collected.
    for i, task in ipairs(tasks) do
      local function cb(err, ...)
        remaining = remaining - 1
        queue:put_nowait(pack_len(err, i, ...))
        if remaining == 0 then
          queue:put_nowait()
        end
      end

      task_cbs[task] = cb
      task:wait(cb)
    end

    --- @async
    return gc_fun(function()
      local r = queue:get()
      if r then
        local err = r[1]
        if err then
          -- -- Note: if the task was a child, then an error should have already been
          -- -- raised in _complete_task(). This should only trigger to detached tasks.
          -- assert(assert(tasks[r[2]])._parent == nil)
          error(('iter error[index:%d]: %s'):format(r[2], r[1]), 3)
        end
        return unpack_len(r, 2)
      end
    end, function()
      for t, tcb in pairs(task_cbs) do
        t:_unwait(tcb)
      end
    end)
  end

  --- Waits for multiple tasks to finish and iterates over their results.
  ---
  --- This function allows you to run multiple asynchronous tasks concurrently and
  --- process their results as they complete. It returns an iterator function that
  --- yields the index of the task, any error encountered, and the results of the
  --- task.
  ---
  --- If a task completes with an error, the error is returned as the second
  --- value. Otherwise, the results of the task are returned as subsequent values.
  ---
  --- Example:
  --- ```lua
  --- local task1 = vim.async.run(function()
  ---   return 1, 'a'
  --- end)
  ---
  --- local task2 = vim.async.run(function()
  ---   return 2, 'b'
  --- end)
  ---
  --- local task3 = vim.async.run(function()
  ---   error('task3 error')
  --- end)
  ---
  --- vim.async.run(function()
  ---   for i, err, r1, r2 in vim.async.iter({task1, task2, task3}) do
  ---     print(i, err, r1, r2)
  ---   end
  --- end)
  --- ```
  ---
  --- Prints:
  --- ```
  --- 1 nil 1 'a'
  --- 2 nil 2 'b'
  --- 3 'task3 error' nil nil
  --- ```
  ---
  --- @async
  --- @generic R
  --- @param tasks vim.async.Task<R>[] A list of tasks to wait for and iterate over.
  --- @return async fun(): (integer?, any?, ...R) iterator that yields the index, error, and results of each task.
  function M.iter(tasks)
    return iter(tasks)
  end

  --- Wait for all tasks to finish and return their results.
  ---
  --- Example:
  --- ```lua
  --- local task1 = vim.async.run(function()
  ---   return 1, 'a'
  --- end)
  ---
  --- local task2 = vim.async.run(function()
  ---   return 1, 'a'
  --- end)
  ---
  --- local task3 = vim.async.run(function()
  ---   error('task3 error')
  --- end)
  ---
  --- vim.async.run(function()
  ---   local results = vim.async.await_all({task1, task2, task3})
  ---   print(vim.inspect(results))
  --- end)
  --- ```
  ---
  --- Prints:
  --- ```
  --- {
  ---   [1] = { nil, 1, 'a' },
  ---   [2] = { nil, 2, 'b' },
  ---   [3] = { 'task2 error' },
  --- }
  --- ```
  --- @async
  --- @param tasks vim.async.Task<any>[]
  --- @return table<integer,[any?,...?]>
  function M.await_all(tasks)
    assert(running(), 'Not in async context')
    local itr = iter(tasks)
    local results = {} --- @type table<integer,table>

    local function collect(i, ...)
      if i then
        results[i] = pack_len(...)
      end
      return i ~= nil
    end

    while collect(itr()) do
    end

    return results
  end

  --- Wait for the first task to complete and return its result.
  ---
  --- Example:
  --- ```lua
  --- local task1 = vim.async.run(function()
  ---   vim.async.sleep(100)
  ---   return 1, 'a'
  --- end)
  ---
  --- local task2 = vim.async.run(function()
  ---   return 2, 'b'
  --- end)
  ---
  --- vim.async.run(function()
  ---   local i, err, r1, r2 = vim.async.await_any({task1, task2})
  ---   assert(i == 2)
  ---   assert(err == nil)
  ---   assert(r1 == 2)
  ---   assert(r2 == 'b')
  --- end)
  --- ```
  --- @async
  --- @param tasks vim.async.Task<any>[]
  --- @return integer? index
  --- @return any? err
  --- @return any ... results
  function M.await_any(tasks)
    return iter(tasks)()
  end
end

--- Asynchronously sleep for a given duration.
---
--- Blocks the current task for the given duration, but does not block the main
--- thread.
--- @async
--- @param duration integer ms
function M.sleep(duration)
  vim.validate('duration', duration, 'number')
  M.await(1, function(callback)
    -- TODO(lewis6991): should return the result of defer_fn here.
    vim.defer_fn(callback, duration)
  end)
end

--- Run a task with a timeout.
---
--- If the task does not complete within the specified duration, it is closed
--- and an error is thrown.
--- @async
--- @generic R
--- @param duration integer Timeout duration in milliseconds
--- @param task vim.async.Task<R>
--- @return R
function M.timeout(duration, task)
  vim.validate('duration', duration, 'number')
  vim.validate('task', task, 'table')
  local timer = M.run(M.await, function(callback)
    local t = assert(vim.uv.new_timer())
    t:start(duration, 0, callback)
    return t
  end)
  if M.await_any({ task, timer }) == 2 then
    -- Timer completed first, close the task
    task:close()
    error('timeout')
  end
  return M.await(task)
end

do --- M._future()
  --- Future objects are used to bridge low-level callback-based code with
  --- high-level async/await code.
  --- @class vim.async.Future<R>
  --- @field private _callbacks table<integer,fun(err?: any, ...: R...)>
  --- @field private _callback_pos integer
  --- Error result of the task is an error occurs.
  --- Must use `await` to get the result.
  --- @field package _err? any
  ---
  --- Result of the task.
  --- Must use `await` to get the result.
  --- @field private _result? R[]
  local Future = {}
  Future.__index = Future

  --- Return `true` if the Future is completed.
  --- @return boolean
  function Future:completed()
    return (self._err or self._result) ~= nil
  end

  --- Return the result of the Future.
  ---
  --- If the Future is done and has a result set by the `complete()` method, the
  --- result is returned.
  ---
  --- If the Future’s result isn’t yet available, this method raises a
  --- "Future has not completed" error.
  --- @return boolean stat true if the Future completed successfully, false otherwise.
  --- @return any ... error or result
  function Future:result()
    if not self:completed() then
      error('Future has not completed', 2)
    end
    if self._err then
      return false, self._err
    else
      return true, unpack_len(self._result)
    end
  end

  --- Add a callback to be run when the Future is done.
  ---
  --- The callback is called with the arguments:
  --- - (`err: string`) - if the Future completed with an error.
  --- - (`nil`, `...:any`) - the results of the Future if it completed successfully.
  ---
  --- If the Future is already done when this method is called, the callback is
  --- called immediately with the results.
  --- @param callback fun(err?: any, ...: any)
  function Future:wait(callback)
    if self:completed() then
      -- Already completed or closed
      callback(self._err, unpack_len(self._result))
    else
      self._callbacks[self._callback_pos] = callback
      self._callback_pos = self._callback_pos + 1
    end
  end

  --- Mark the Future as complete and set its result.
  ---
  --- If an error is provided, the Future is marked as failed. Otherwise, it is
  --- marked as successful with the provided result.
  ---
  --- This will trigger any callbacks that are waiting on the Future.
  --- @param err? any
  --- @param ... any result
  function Future:complete(err, ...)
    if err ~= nil then
      self._err = err
    else
      self._result = pack_len(...)
    end

    local errs = {} --- @type string[]
    -- Need to use pairs to avoid gaps caused by removed callbacks
    for _, cb in pairs(self._callbacks) do
      local ok, cb_err = pcall(cb, err, ...)
      if not ok then
        errs[#errs + 1] = cb_err
      end
    end

    if #errs > 0 then
      error(table.concat(errs, '\n'), 0)
    end
  end

  --- @package
  --- Removes a callback from the Future.
  --- @param cb fun(err?: any, ...: any)
  function Future:_remove_cb(cb)
    for j, fcb in pairs(self._callbacks) do
      if fcb == cb then
        self._callbacks[j] = nil
        break
      end
    end
  end

  --- @package
  --- Create a new future.
  ---
  --- A Future is a low-level awaitable that is not intended to be used in
  --- application-level code.
  --- @return vim.async.Future
  function M._future()
    return setmetatable({
      _callbacks = {},
      _callback_pos = 1,
    }, Future)
  end
end

do --- M._event()
  --- An event can be used to notify multiple tasks that some event has
  --- happened. An Event object manages an internal flag that can be set to true
  --- with the `set()` method and reset to `false` with the `clear()` method.
  --- The `wait()` method blocks until the flag is set to `true`. The flag is
  --- set to `false` initially.
  --- @class vim.async.Event
  --- @field private _is_set boolean
  --- @field private _waiters function[]
  local Event = {}
  Event.__index = Event

  --- Set the event.
  ---
  --- All tasks waiting for event to be set will be immediately awakened.
  ---
  --- If `max_woken` is provided, only up to `max_woken` waiters will be woken.
  --- The event will be reset to `false` if there are more waiters remaining.
  --- @param max_woken? integer
  function Event:set(max_woken)
    if self._is_set then
      return
    end
    self._is_set = true
    local waiters = self._waiters
    local waiters_to_notify = {} --- @type function[]
    max_woken = max_woken or #waiters
    while #waiters > 0 and #waiters_to_notify < max_woken do
      waiters_to_notify[#waiters_to_notify + 1] = table.remove(waiters, 1)
    end
    if #waiters > 0 then
      self._is_set = false
    end
    for _, waiter in ipairs(waiters_to_notify) do
      waiter()
    end
  end

  --- Wait until the event is set.
  ---
  --- If the event is set, return immediately. Otherwise block until another
  --- task calls set().
  --- @async
  function Event:wait()
    M.await(function(callback)
      if self._is_set then
        callback()
      else
        table.insert(self._waiters, callback)
      end
    end)
  end

  --- Clear (unset) the event.
  ---
  --- Tasks awaiting on wait() will now block until the set() method is called
  --- again.
  function Event:clear()
    self._is_set = false
  end

  --- @package
  --- Create a new event.
  ---
  --- An event can signal to multiple listeners to resume execution
  --- The event can be set from a non-async context.
  ---
  --- ```lua
  ---  local event = vim.async._event()
  ---
  ---  local worker = vim.async.run(function()
  ---    vim.async.sleep(1000)
  ---    event.set()
  ---  end)
  ---
  ---  local listeners = {
  ---    vim.async.run(function()
  ---      event:wait()
  ---      print("First listener notified")
  ---    end),
  ---    vim.async.run(function()
  ---      event:wait()
  ---      print("Second listener notified")
  ---    end),
  ---  }
  --- ```
  --- @return vim.async.Event
  function M._event()
    return setmetatable({
      _waiters = {},
      _is_set = false,
    }, Event)
  end
end

do --- M._queue()
  --- @class vim.async.Queue<R>
  --- @field private _non_empty vim.async.Event
  --- @field package _non_full vim.async.Event
  --- @field private _max_size? integer
  --- @field private _items R[]
  --- @field private _right_i integer
  --- @field private _left_i integer
  local Queue = {}
  Queue.__index = Queue

  --- Returns the number of items in the queue.
  --- @return integer
  function Queue:size()
    return self._right_i - self._left_i
  end

  --- Returns the maximum number of items in the queue.
  --- @return integer?
  function Queue:max_size()
    return self._max_size
  end

  --- Put an item into the queue.
  ---
  --- If the queue is full, wait until a free slot is available.
  --- @async
  --- @param value any
  function Queue:put(value)
    self._non_full:wait()
    self:put_nowait(value)
  end

  --- Get an item from the queue.
  ---
  --- If the queue is empty, wait until an item is available.
  --- @async
  --- @return any
  function Queue:get()
    self._non_empty:wait()
    return self:get_nowait()
  end

  --- Get an item from the queue without blocking.
  ---
  --- If the queue is empty, raise an error.
  --- @return any
  function Queue:get_nowait()
    if self:size() == 0 then
      error('Queue is empty', 2)
    end
    -- TODO(lewis6991): For a long_running queue, _left_i might overflow.
    self._left_i = self._left_i + 1
    local item = self._items[self._left_i]
    self._items[self._left_i] = nil
    if self._left_i == self._right_i then
      self._non_empty:clear()
    end
    self._non_full:set(1)
    return item
  end

  --- Put an item into the queue without blocking.
  --- If no free slot is immediately available, raise "Queue is full" error.
  --- @param value any
  function Queue:put_nowait(value)
    if self:size() == self:max_size() then
      error('Queue is full', 2)
    end
    self._right_i = self._right_i + 1
    self._items[self._right_i] = value
    self._non_empty:set(1)
    if self:size() == self.max_size then
      self._non_full:clear()
    end
  end

  --- @package
  --- Create a new FIFO queue with async support.
  --- ```lua
  ---  local queue = vim.async._queue()
  ---
  ---  local producer = vim.async.run(function()
  ---    for i = 1, 10 do
  ---      vim.async.sleep(100)
  ---      queue:put(i)
  ---    end
  ---    queue:put(nil)
  ---  end)
  ---
  ---  vim.async.run(function()
  ---    while true do
  ---      local value = queue:get()
  ---      if value == nil then
  ---        break
  ---      end
  ---      print(value)
  ---    end
  ---    print("Done")
  ---  end)
  --- ```
  --- @param max_size? integer The maximum number of items in the queue, defaults to no limit
  --- @return vim.async.Queue
  function M._queue(max_size)
    local self = setmetatable({
      _items = {},
      _left_i = 0,
      _right_i = 0,
      _max_size = max_size,
      _non_empty = M._event(),
      _non_full = M._event(),
    }, Queue)

    self._non_full:set()

    return self
  end
end

do --- M.semaphore()
  --- A semaphore manages an internal counter which is decremented by each
  --- `acquire()` call and incremented by each `release()` call. The counter can
  --- never go below zero; when `acquire()` finds that it is zero, it blocks,
  --- waiting until some task calls `release()`.
  ---
  --- The preferred way to use a Semaphore is with the `with()` method, which
  --- automatically acquires and releases the semaphore around a function call.
  --- @class vim.async.Semaphore
  --- @field private _permits integer
  --- @field private _max_permits integer
  --- @field package _event vim.async.Event
  local Semaphore = {}
  Semaphore.__index = Semaphore

  --- Executes a function within the semaphore.
  ---
  --- This acquires the semaphore before running the function and releases it
  --- after the function completes, even if it errors.
  --- @async
  --- @generic R
  --- @param fn async fun(): R... # Function to execute within the semaphore's context.
  --- @return R... # Result(s) of the executed function.
  function Semaphore:with(fn)
    self:acquire()
    local r = pack_len(pcall(fn))
    self:release()
    local stat = r[1]
    if not stat then
      local err = r[2]
      error(err)
    end
    return unpack_len(r, 2)
  end

  --- Acquire a semaphore.
  ---
  --- If the internal counter is greater than zero, decrement it by `1` and
  --- return immediately. If it is `0`, wait until a `release()` is called.
  --- @async
  function Semaphore:acquire()
    self._event:wait()
    self._permits = self._permits - 1
    assert(self._permits >= 0, 'Semaphore value is negative')
    if self._permits == 0 then
      self._event:clear()
    end
  end

  --- Release a semaphore.
  ---
  --- Increments the internal counter by `1`. Can wake
  --- up a task waiting to acquire the semaphore.
  function Semaphore:release()
    if self._permits >= self._max_permits then
      error('Semaphore value is greater than max permits', 2)
    end
    self._permits = self._permits + 1
    self._event:set(1)
  end

  --- Create an async semaphore that allows up to a given number of acquisitions.
  ---
  --- ```lua
  --- vim.async.run(function()
  ---   local semaphore = vim.async.semaphore(2)
  ---
  ---   local tasks = {}
  ---
  ---   local value = 0
  ---   for i = 1, 10 do
  ---     tasks[i] = vim.async.run(function()
  ---       semaphore:with(function()
  ---         value = value + 1
  ---         vim.async.sleep(10)
  ---         print(value) -- Never more than 2
  ---         value = value - 1
  ---       end)
  ---     end)
  ---   end
  ---
  ---   vim.async.await_all(tasks)
  ---   assert(value <= 2)
  --- end)
  --- ```
  --- @param permits? integer (default: 1)
  --- @return vim.async.Semaphore
  function M.semaphore(permits)
    vim.validate('permits', permits, 'number', true)
    permits = permits or 1
    local obj = setmetatable({
      _max_permits = permits,
      _permits = permits,
      _event = M._event(),
    }, Semaphore)
    obj._event:set()
    return obj
  end
end

do --- M._inspect_tree()
  --- @private
  --- @param parent? vim.async.Task
  --- @param prefix? string
  --- @return string[]
  local function inspect(parent, prefix)
    local tasks = {} --- @type table<any, vim.async.Task<any>?>
    if parent then
      for _, task in pairs(parent._children) do
        if not task._internal then
          tasks[#tasks + 1] = task
        end
      end
    else
      -- Gather for all detached tasks
      for _, task in pairs(threads) do
        if not task._parent and not task._internal then
          tasks[#tasks + 1] = task
        end
      end
    end

    local r = {} --- @type string[]
    for i, task in ipairs(tasks) do
      local last = i == #tasks
      r[#r + 1] = ('%s%s%s%s [%s]'):format(
        prefix or '',
        parent and (last and '└─ ' or '├─ ') or '',
        task.name or '',
        task._caller,
        task:status()
      )
      local child_prefix = (prefix or '') .. (parent and (last and '   ' or '│  ') or '')
      vim.list_extend(r, inspect(task, child_prefix))
    end
    return r
  end

  --- Inspect the current async task tree.
  ---
  --- Returns a string representation of the task tree, showing the names and
  --- statuses of each task.
  --- @return string
  function M._inspect_tree()
    -- Inspired by https://docs.python.org/3.14/whatsnew/3.14.html#asyncio-introspection-capabilities
    return table.concat(inspect(), '\n')
  end
end

return M
