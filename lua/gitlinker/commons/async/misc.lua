local async = require('gitlinker.commons.async')

-- Examples of functions built on top of async.lua

local M = {}

--- Like async.join, but with a limit on the number of concurrent tasks.
--- @async
--- @param max_jobs integer
--- @param funs (async fun())[]
function M.join_n_1(max_jobs, funs)
  if #funs == 0 then
    return
  end

  max_jobs = math.min(max_jobs, #funs)

  local running = {} --- @type async.Task<any>[]

  -- Start the first batch of tasks
  for i = 1, max_jobs do
    running[i] = assert(funs[i])()
  end

  -- As tasks finish, add new ones
  for i = max_jobs + 1, #funs do
    local finished = async.await_any(running)
    --- @cast finished -?
    running[finished] = async.run(assert(funs[i]))
  end

  -- Wait for all tasks to finish
  async.await_all(running)
end

--- Like async.join, but with a limit on the number of concurrent tasks.
--- (different implementation and doesn't use `async.await_any()`)
--- @async
--- @param max_jobs integer
--- @param funs (async fun())[]
function M.join_n_2(max_jobs, funs)
  if #funs == 0 then
    return
  end

  max_jobs = math.min(max_jobs, #funs)

  --- @type (async fun())[]
  local remaining = { select(max_jobs + 1, unpack(funs)) }
  local to_go = #funs

  async.await(1, function(finish)
    local function cb()
      to_go = to_go - 1
      if to_go == 0 then
        finish()
      elseif #remaining > 0 then
        local next_task = table.remove(remaining)
        async.run(next_task):await(cb)
      end
    end

    for i = 1, max_jobs do
      async.run(assert(funs[i])):await(cb)
    end
  end)
end

--- Like async.join, but with a limit on the number of concurrent tasks.
--- @async
--- @param max_jobs integer
--- @param funs (async fun())[]
function M.join_n_3(max_jobs, funs)
  if #funs == 0 then
    return
  end

  local semaphore = async.semaphore(max_jobs)

  local tasks = {} --- @type async.Task<any>[]

  for _, fun in ipairs(funs) do
    tasks[#tasks + 1] = async.run(function()
      semaphore:with(fun)
    end)
  end

  async.await_all(tasks)
end

return M
