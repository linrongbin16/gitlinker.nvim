local log = require("gitlinker.commons.log")
local str = require("gitlinker.commons.str")
local async = require("gitlinker.commons.async")

--- @class gitlinker.GitResult
--- @field code integer  exit code, `0` means success, `GitResult.SPAWN_FAILED` means the command never ran.
--- @field stdout string[]
--- @field stderr string[]
local GitResult = {}

-- Exit code recorded when the command could not even be started (vim.system
-- raised). A merely failed command reports an exit status in the `0..255` range
-- (`255` and `-1` are common), which would be indistinguishable from a spawn
-- error. This sentinel is INT32_MIN: far outside that range, and small enough to
-- stay exactly representable, since Lua numbers are doubles holding integers
-- precisely up to 2^53.
GitResult.SPAWN_FAILED = -2147483648

--- @return gitlinker.GitResult
function GitResult:new()
  local o = {
    code = 0,
    stdout = {},
    stderr = {},
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

-- Exit code is the only reliable success signal. Reading stdout is not enough:
-- `git rev-parse <bad-rev>` exits 128 but still echoes the argument to stdout.
--- @return boolean
function GitResult:ok()
  return self.code == 0
end

-- True when the command never ran at all, as opposed to running and failing.
--- @return boolean
function GitResult:spawn_failed()
  return self.code == GitResult.SPAWN_FAILED
end

-- True when the command left nothing usable behind: it either failed, or it
-- exited successfully but wrote nothing to stdout. Callers that need a value out
-- of the command have to bail out in both cases, and a bare `ok()` check is not
-- enough for them, because a zero exit status promises nothing about the output
-- (`git rev-parse <bad-rev>` exits 128 yet still echoes its argument).
-- Note this is NOT the same as `not ok()`: commands such as `git cat-file -e`
-- report success silently and must keep using `ok()` alone.
--- @return boolean
function GitResult:silent_failed()
  return not self:ok() or type(self.stdout) ~= "table" or #self.stdout == 0
end

-- Build a single error message from the command output, without printing it.
-- Callers decide whether and when to report the failure.
--- @param fallback string  message used when the command wrote nothing to stderr.
--- @return string
function GitResult:errmsg(fallback)
  if type(self.stderr) == "table" and #self.stderr > 0 then
    return table.concat(self.stderr, "\n")
  end
  return "fatal: " .. fallback
end

--- @param args string[]
--- @param dir string
--- @param callback fun(gitlinker.GitResult):any
local function _run_cmd_async(args, dir, callback)
  log.debug(string.format("|_run_cmd_async| args:%s, dir:%s", vim.inspect(args), vim.inspect(dir)))

  --- @param completed vim.SystemCompleted
  local function on_exit(completed)
    local result = GitResult:new()
    result.code = completed.code or 0
    if str.not_blank(completed.stdout) then
      result.stdout = str.split(str.trim(completed.stdout), "\n", { trimempty = true })
    end
    if str.not_blank(completed.stderr) then
      result.stderr = str.split(str.trim(completed.stderr), "\n", { trimempty = true })
    end
    log.debug(string.format("|_run_cmd_async| result:%s", vim.inspect(result)))
    callback(result)
  end

  local ok, spawn_err = pcall(vim.system, args, {
    cwd = dir,
    text = true,
  }, on_exit)
  if not ok then
    -- vim.system raises instead of invoking on_exit when the directory or the
    -- binary is missing, so surface this as a normal command failure.
    local result = GitResult:new()
    result.code = GitResult.SPAWN_FAILED
    -- Drop the `[string "..."]:NNN: ` prefix vim adds, it is noise in a message
    -- that ends up in a user-facing notification.
    local msg = tostring(spawn_err):gsub('^%[string ".*"%]:%d+: ', "")
    result.stderr = { "fatal: " .. msg }
    log.debug(string.format("|_run_cmd_async| spawn failed:%s", vim.inspect(spawn_err)))
    callback(result)
  end
end

-- wrap the git command to do the right thing always
--- @package
--- @type fun(args:string[], dir:string): gitlinker.GitResult
local function run_cmd(args, dir)
  --- @type fun(args:string[], dir:string): gitlinker.GitResult
  local _run_cmd = async.wrap(3, _run_cmd_async)
  return _run_cmd(args, dir)
end

--- @package
--- @param root string
--- @return string[]|nil, string?
local function _get_remote(root)
  local args = { "git", "remote" }
  local result = run_cmd(args, root)
  if result:silent_failed() then
    return nil, result:errmsg("git repo has no remote")
  end
  return result.stdout, nil
end

--- @param remote string
--- @param root string
--- @return string?, string?
local function get_remote_url(remote, root)
  assert(remote, "remote cannot be nil")
  local args = { "git", "remote", "get-url", remote }
  local result = run_cmd(args, root)
  if result:silent_failed() then
    return nil, result:errmsg("failed to get remote url by remote '" .. remote .. "'")
  end
  return result.stdout[1], nil
end

--- @package
--- @param revspec string?
--- @param root string
--- @return string?, string?
local function _get_rev(revspec, root)
  local args = { "git", "rev-parse", revspec }
  local result = run_cmd(args, root)
  if result:silent_failed() then
    return nil, result:errmsg(string.format("failed to resolve revision '%s'", tostring(revspec)))
  end
  return result.stdout[1], nil
end

--- @package
--- @param revspec string
--- @param root string
--- @return string?, string?
local function _get_rev_name(revspec, root)
  local args = { "git", "rev-parse", "--abbrev-ref", revspec }
  local result = run_cmd(args, root)
  if result:silent_failed() then
    return nil, result:errmsg("git branch has no remote")
  end
  return result.stdout[1], nil
end

--- @param file string
--- @param revspec string
--- @param root string
--- @return boolean?, string?
local function is_file_in_rev(file, revspec, root)
  local args = { "git", "cat-file", "-e", revspec .. ":" .. file }
  local result = run_cmd(args, root)
  if not result:ok() then
    return nil, result:errmsg("'" .. file .. "' does not exist in remote '" .. revspec .. "'")
  end
  return true, nil
end

--- @param file string
--- @param rev string
--- @param root string
--- @return boolean?, string?
local function file_has_changed(file, rev, root)
  local args = { "git", "diff", rev, "--", file }
  local result = run_cmd(args, root)
  if not result:ok() then
    return nil, result:errmsg(string.format("failed to diff '%s' against '%s'", file, rev))
  end
  return type(result.stdout) == "table" and #result.stdout > 0, nil
end

--- @package
--- @param revspec string
--- @param remote string
--- @param root string
--- @return boolean?, string?
local function _is_rev_in_remote(revspec, remote, root)
  local args = { "git", "branch", "--remotes", "--contains", revspec }
  local result = run_cmd(args, root)
  if not result:ok() then
    return nil, result:errmsg(string.format("failed to check rev '%s' in remote", revspec))
  end
  for _, rbranch in ipairs(result.stdout) do
    if rbranch:match(remote) then
      return true, nil
    end
  end
  return false, nil
end

--- @package
--- @param remote string
--- @param root string
--- @return boolean?, string?
local function _has_remote_fetch_config(remote, root)
  local args = { "git", "config", string.format("remote.%s.fetch", remote) }
  local result = run_cmd(args, root)
  -- `git config` exits 1 when the key is simply absent, which is a valid
  -- "no fetch refspec" answer rather than a failure.
  if result.code ~= 0 and result.code ~= 1 then
    return nil, result:errmsg(string.format("failed to read fetch config of remote '%s'", remote))
  end
  for _, fetch in ipairs(result.stdout) do
    if type(fetch) == "string" and string.len(vim.trim(fetch)) > 0 then
      return true, nil
    end
  end
  return false, nil
end

--- @param host string
--- @param root string
--- @return string?, string?
local function resolve_host(host, root)
  if vim.fn.executable("ssh") <= 0 then
    return host, nil
  end
  local errmsg = string.format("failed to resolve host %s via ssh", vim.inspect(host))
  local args = { "ssh", "-ttG", host }
  local result = run_cmd(args, root)

  if result:silent_failed() then
    return nil, result:errmsg(errmsg)
  end

  local stdout_map = {}
  for _, item in ipairs(result.stdout) do
    if type(item) == "string" then
      local key, value = item:match("(%S+)%s+(%S+)")
      if type(key) == "string" and type(value) == "string" then
        stdout_map[key] = value
      end
    end
  end
  local hostname = "hostname"
  if stdout_map[hostname] ~= nil then
    return vim.trim(stdout_map[hostname]), nil
  end

  return nil, "fatal: " .. errmsg
end

--- @param remote string
--- @param root string
--- @return string?, string?
local function get_closest_remote_compatible_rev(remote, root)
  assert(remote, "remote cannot be nil")

  -- try upstream branch HEAD (a.k.a @{u})
  local upstream_rev = _get_rev("@{u}", root)
  if upstream_rev then
    return upstream_rev, nil
  end

  -- Failing to read the fetch config only degrades the search to the
  -- conservative branch below, so it is not worth aborting here.
  local remote_fetch_configured = _has_remote_fetch_config(remote, root) == true

  -- With a fetch refspec configured only revisions that really exist in the
  -- remote make valid permalink targets, otherwise the local history is good
  -- enough. `_is_rev_in_remote` returns nil when it fails, which is falsy too.
  --- @param revspec string
  --- @return boolean
  local function is_usable(revspec)
    if not remote_fetch_configured then
      return true
    end
    return _is_rev_in_remote(revspec, remote, root) == true
  end

  -- try HEAD
  if is_usable("HEAD") then
    local head_rev = _get_rev("HEAD", root)
    if head_rev then
      return head_rev, nil
    end
  end

  -- try last 50 parent commits
  for i = 1, 50 do
    local revspec = "HEAD~" .. i
    if is_usable(revspec) then
      local rev = _get_rev(revspec, root)
      if rev then
        return rev, nil
      end
    end
  end

  -- try remote HEAD
  local remote_rev = _get_rev(remote, root)
  if remote_rev then
    return remote_rev, nil
  end

  return nil,
    string.format(
      "fatal: failed to get closest revision in that exists in remote: %s",
      vim.inspect(remote)
    )
end

--- @param dir string  any directory, usually the buffer directory
--- @return string?, string?
local function get_root(dir)
  local args = { "git", "rev-parse", "--show-toplevel" }
  local result = run_cmd(args, dir)
  if result:silent_failed() then
    return nil, result:errmsg("not in a git repository")
  end
  return result.stdout[1], nil
end

-- --- NOTE: async functions for `vim.ui.select`.
-- local _run_select = async.wrap(function(remotes, callback)
--   vim.ui.select(remotes, {
--     prompt = "Detect multiple git remotes:",
--     format_item = function(item)
--       return item
--     end,
--   }, function(choice)
--     callback(choice)
--   end)
-- end, 2)
--
-- -- wrap the select function.
-- --- @package
-- --- @type fun(remotes:string[]):string?
-- local function run_select(remotes)
--   return _run_select(remotes)
-- end

--- @package
--- @param remotes string[]
--- @param root string
--- @return string?, string?
local function _select_remotes(remotes, root)
  local formatted_remotes = { "Please select remote index:" }
  for i, remote in ipairs(remotes) do
    local remote_url = get_remote_url(remote, root)
    table.insert(formatted_remotes, string.format("%d. %s (%s)", i, remote, remote_url))
  end

  async.await(1, vim.schedule)

  local result = vim.fn.inputlist(formatted_remotes)

  if type(result) ~= "number" or result < 1 or result > #remotes then
    return nil, "fatal: user cancelled multiple git remotes"
  end

  for i, remote in ipairs(remotes) do
    if result == i then
      return remote, nil
    end
  end

  return nil, "fatal: user cancelled multiple git remotes, please select an index"
end

--- @param root string
--- @return string?, string?
local function get_branch_remote(root)
  -- origin/upstream
  local remotes, err = _get_remote(root)
  log.debug(string.format("git remotes:%s", vim.inspect(remotes)))
  if not remotes then
    return nil, err
  end

  if #remotes == 1 then
    return remotes[1], nil
  end

  if #remotes > 1 then
    return _select_remotes(remotes, root)
  end

  -- origin/linrongbin16/add-rule2
  local upstream_branch, upstream_err = _get_rev_name("@{u}", root)
  if not upstream_branch then
    return nil, upstream_err
  end

  local upstream_branch_allowed_chars = "[_%-%w%.]+"

  -- origin
  local remote_from_upstream_branch =
    upstream_branch:match("^(" .. upstream_branch_allowed_chars .. ")%/")

  if not remote_from_upstream_branch then
    return nil, "fatal: cannot parse remote name from remote branch: " .. upstream_branch
  end

  for _, remote in ipairs(remotes) do
    if remote_from_upstream_branch == remote then
      return remote, nil
    end
  end

  return nil,
    string.format(
      "fatal: parsed remote '%s' from remote branch '%s' is not a valid remote",
      remote_from_upstream_branch,
      upstream_branch
    )
end

--- @param remote string
--- @param root string
--- @return string?, string?
local function get_default_branch(remote, root)
  local args = { "git", "rev-parse", "--abbrev-ref", string.format("%s/HEAD", remote) }
  local result = run_cmd(args, root)
  if result:silent_failed() then
    return nil, result:errmsg(string.format("failed to get default branch of remote '%s'", remote))
  end
  log.debug(
    string.format(
      "|get_default_branch| running %s: %s",
      vim.inspect(args),
      vim.inspect(result.stdout)
    )
  )
  local splits = vim.split(result.stdout[1], "/", { plain = true, trimempty = true })
  return splits[#splits], nil
end

--- @param root string
--- @return string?, string?
local function get_current_branch(root)
  local args = { "git", "rev-parse", "--abbrev-ref", "HEAD" }
  local result = run_cmd(args, root)
  if result:silent_failed() then
    return nil, result:errmsg("failed to get current branch")
  end
  log.debug(
    string.format(
      "|get_current_branch| running %s: %s",
      vim.inspect(args),
      vim.inspect(result.stdout)
    )
  )
  return result.stdout[1], nil
end

local M = {
  GitResult = GitResult,
  _get_remote = _get_remote,
  _get_rev = _get_rev,
  _get_rev_name = _get_rev_name,
  get_root = get_root,
  get_remote_url = get_remote_url,
  is_file_in_rev = is_file_in_rev,
  file_has_changed = file_has_changed,
  get_closest_remote_compatible_rev = get_closest_remote_compatible_rev,
  get_branch_remote = get_branch_remote,
  resolve_host = resolve_host,
  get_default_branch = get_default_branch,
  get_current_branch = get_current_branch,
}

return M
