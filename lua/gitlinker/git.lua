local logging = require("gitlinker.commons.logging")
local spawn = require("gitlinker.commons.spawn")
local async = require("gitlinker.commons.async")
local uv = require("gitlinker.commons.uv")

--- @class gitlinker.CmdResult
--- @field stdout string[]
--- @field stderr string[]
local CmdResult = {}

--- @return gitlinker.CmdResult
function CmdResult:new()
  local o = {
    stdout = {},
    stderr = {},
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

--- @return boolean
function CmdResult:has_out()
  return type(self.stdout) == "table" and #self.stdout > 0
end

--- @return boolean
function CmdResult:has_err()
  return type(self.stderr) == "table" and #self.stderr > 0
end

--- @param default string
function CmdResult:print_err(default)
  local logger = logging.get("gitlinker")
  if self:has_err() then
    for _, e in ipairs(self.stderr) do
      logger:err(e)
    end
  else
    logger:err("fatal: " .. default)
  end
end

--- NOTE: async functions can't have optional parameters so wrap it into another function without '_'
local _run_cmd = async.wrap(function(args, cwd, callback)
  local result = CmdResult:new()

  spawn.run(args, {
    cwd = cwd,
    on_stdout = function(line)
      if type(line) == "string" then
        table.insert(result.stdout, line)
      end
    end,
    on_stderr = function(line)
      if type(line) == "string" then
        table.insert(result.stderr, line)
      end
    end,
  }, function()
    callback(result)
  end)
end, 3)

-- wrap the git command to do the right thing always
--- @package
--- @type fun(args:string[], cwd:string?): gitlinker.CmdResult
local function run_cmd(args, cwd)
  return _run_cmd(args, cwd or uv.cwd())
end

--- @package
--- @return string[]|nil
local function _get_remote()
  local args = { "git", "remote" }
  local result = run_cmd(args)
  if type(result.stdout) ~= "table" or #result.stdout == 0 then
    result:print_err("fatal: git repo has no remote")
    return nil
  end
  -- logger.debug(
  --   "|git._get_remote| running %s: %s",
  --   vim.inspect(args),
  --   vim.inspect(result.stdout)
  -- )
  return result.stdout
end

--- @param remote string
--- @return string?
local function get_remote_url(remote)
  assert(remote, "remote cannot be nil")
  local args = { "git", "remote", "get-url", remote }
  local result = run_cmd(args)
  if not result:has_out() then
    result:print_err("fatal: failed to get remote url by remote '" .. remote .. "'")
    return nil
  end
  -- logger.debug(
  --   "|git.get_remote_url| running %s: %s",
  --   vim.inspect(args),
  --   vim.inspect(result.stdout)
  -- )
  return result.stdout[1]
end

--- @package
--- @param revspec string?
--- @return string?
local function _get_rev(revspec)
  local args = { "git", "rev-parse", revspec }
  local result = run_cmd(args)
  -- logger.debug(
  --   "|git._get_rev| running %s: %s (error:%s)",
  --   vim.inspect(args),
  --   vim.inspect(result.stdout),
  --   vim.inspect(result.stderr)
  -- )
  return result:has_out() and result.stdout[1] or nil
end

--- @package
--- @param revspec string
--- @return string?
local function _get_rev_name(revspec)
  local args = { "git", "rev-parse", "--abbrev-ref", revspec }
  local result = run_cmd(args)
  if not result:has_out() then
    result:print_err("fatal: git branch has no remote")
    return nil
  end
  -- logger.debug(
  --   "|git._get_rev_name| running %s: %s",
  --   vim.inspect(args),
  --   vim.inspect(result.stdout)
  -- )
  return result.stdout[1]
end

--- @param file string
--- @param revspec string
--- @return boolean
local function is_file_in_rev(file, revspec)
  local args = { "git", "cat-file", "-e", revspec .. ":" .. file }
  local result = run_cmd(args)
  if result:has_err() then
    result:print_err("fatal: '" .. file .. "' does not exist in remote '" .. revspec .. "'")
    return false
  end
  -- logger.debug(
  --   "|git.is_file_in_rev| running %s: %s",
  --   vim.inspect(args),
  --   vim.inspect(result.stdout)
  -- )
  return true
end

--- @param file string
--- @param rev string
--- @return boolean
local function file_has_changed(file, rev)
  local args = { "git", "diff", rev, "--", file }
  local result = run_cmd(args)
  -- logger.debug(
  --   "|git.has_file_changed| running %s: %s",
  --   vim.inspect(args),
  --   vim.inspect(result.stdout)
  -- )
  return result:has_out()
end

--- @package
--- @param revspec string
--- @param remote string
--- @return boolean
local function _is_rev_in_remote(revspec, remote)
  local args = { "git", "branch", "--remotes", "--contains", revspec }
  local result = run_cmd(args)
  -- logger.debug(
  --   "|git._is_rev_in_remote| running %s: %s (error:%s)",
  --   vim.inspect(args),
  --   vim.inspect(result.stdout),
  --   vim.inspect(result.stderr)
  -- )
  local output = result.stdout
  for _, rbranch in ipairs(output) do
    if rbranch:match(remote) then
      return true
    end
  end
  return false
end

--- @package
--- @param remote string
--- @return boolean
local function _has_remote_fetch_config(remote)
  local args = { "git", "config", string.format("remote.%s.fetch", remote) }
  local result = run_cmd(args)
  -- logger.debug(
  --   "|git._has_remote_fetch_config| running %s: %s (error:%s)",
  --   vim.inspect(args),
  --   vim.inspect(result.stdout),
  --   vim.inspect(result.stderr)
  -- )
  local output = result.stdout
  for _, fetch in ipairs(output) do
    if type(fetch) == "string" and string.len(vim.trim(fetch)) > 0 then
      return true
    end
  end
  return false
end

--- @param host string
--- @return string?
local function resolve_host(host)
  if vim.fn.executable("ssh") <= 0 then
    return host
  end
  local errmsg = string.format("fatal: failed to resolve host %s via ssh", vim.inspect(host))
  local args = { "ssh", "-ttG", host }
  local result = run_cmd(args)

  if not result:has_out() then
    result:print_err(errmsg)
    return nil
  end
  -- logger.debug(
  --   "|git.resolve_host| running %s: %s",
  --   vim.inspect(args),
  --   vim.inspect(result.stdout)
  -- )

  local stdout_map = {}
  for _, item in ipairs(result.stdout) do
    if type(item) == "string" then
      local key, value = item:match("(%S+)%s+(%S+)")
      -- logger.debug(
      --   "|git.resolve_host| ssh key:%s, value:%s",
      --   vim.inspect(key),
      --   vim.inspect(value)
      -- )
      if type(key) == "string" and type(value) == "string" then
        stdout_map[key] = value
      end
    end
  end
  -- logger.debug("|git.resolve_host| stdout_map: %s", vim.inspect(stdout_map))
  local hostname = "hostname"
  if stdout_map[hostname] ~= nil then
    local alias_host = stdout_map[hostname]
    return vim.trim(alias_host)
  end

  result:print_err(errmsg)
  return nil
end

--- @param remote string
--- @return string?
local function get_closest_remote_compatible_rev(remote)
  local logger = logging.get("gitlinker")
  assert(remote, "remote cannot be nil")

  -- try upstream branch HEAD (a.k.a @{u})
  local upstream_rev = _get_rev("@{u}")
  -- logger.debug(
  --   "|git.get_closest_remote_compatible_rev| running _get_rev:%s",
  --   vim.inspect(upstream_rev)
  -- )
  if upstream_rev then
    return upstream_rev
  end

  local remote_fetch_configured = _has_remote_fetch_config(remote)

  -- try HEAD
  if remote_fetch_configured then
    if _is_rev_in_remote("HEAD", remote) then
      local head_rev = _get_rev("HEAD")
      if head_rev then
        return head_rev
      end
    end
  else
    local head_rev = _get_rev("HEAD")
    if head_rev then
      return head_rev
    end
  end

  -- try last 50 parent commits
  if remote_fetch_configured then
    for i = 1, 50 do
      local revspec = "HEAD~" .. i
      if _is_rev_in_remote(revspec, remote) then
        local rev = _get_rev(revspec)
        if rev then
          return rev
        end
      end
    end
  else
    for i = 1, 50 do
      local revspec = "HEAD~" .. i
      local rev = _get_rev(revspec)
      if rev then
        return rev
      end
    end
  end

  -- try remote HEAD
  local remote_rev = _get_rev(remote)
  if remote_rev then
    return remote_rev
  end

  logger:err("fatal: failed to get closest revision in that exists in remote: " .. remote)
  return nil
end

--- @return string?
local function get_root()
  local buf_path = vim.api.nvim_buf_get_name(0)
  local buf_dir = vim.fn.fnamemodify(buf_path, ":p:h")
  local args = { "git", "rev-parse", "--show-toplevel" }
  local result = run_cmd(args, buf_dir)
  -- logger.debug(
  --     "|git.get_root| buf_path:%s, buf_dir:%s, result:%s",
  --     vim.inspect(buf_path),
  --     vim.inspect(buf_dir),
  --     vim.inspect(result)
  -- )
  if not result:has_out() then
    result:print_err("fatal: not in a git repository")
    return nil
  end
  -- logger.debug(
  --   "|git.get_root| %s (at %s): %s",
  --   vim.inspect(args),
  --   vim.inspect(buf_dir),
  --   vim.inspect(result.stdout)
  -- )
  return result.stdout[1]
end

--- @return string?
local function get_branch_remote()
  local logger = logging.get("gitlinker")
  -- origin/upstream
  local remotes = _get_remote()
  if not remotes then
    return nil
  end

  if #remotes == 1 then
    return remotes[1]
  end

  -- origin/linrongbin16/add-rule2
  local upstream_branch = _get_rev_name("@{u}")
  if not upstream_branch then
    return nil
  end

  local upstream_branch_allowed_chars = "[_%-%w%.]+"

  -- origin
  local remote_from_upstream_branch =
    upstream_branch:match("^(" .. upstream_branch_allowed_chars .. ")%/")

  if not remote_from_upstream_branch then
    logger:err("fatal: cannot parse remote name from remote branch: " .. upstream_branch)
    return nil
  end

  for _, remote in ipairs(remotes) do
    if remote_from_upstream_branch == remote then
      return remote
    end
  end

  logger:err(
    string.format(
      "fatal: parsed remote '%s' from remote branch '%s' is not a valid remote",
      remote_from_upstream_branch,
      upstream_branch
    )
  )
  return nil
end

--- @param remote string
--- @return string?
local function get_default_branch(remote)
  local logger = logging.get("gitlinker")
  local args = { "git", "rev-parse", "--abbrev-ref", string.format("%s/HEAD", remote) }
  local result = run_cmd(args)
  if type(result.stdout) ~= "table" or #result.stdout == 0 then
    return nil
  end
  logger:debug(
    string.format(
      "|get_default_branch| running %s: %s",
      vim.inspect(args),
      vim.inspect(result.stdout)
    )
  )
  local splits = vim.split(result.stdout[1], "/", { plain = true, trimempty = true })
  return splits[#splits]
end

--- @return string?
local function get_current_branch()
  local logger = logging.get("gitlinker")
  local args = { "git", "rev-parse", "--abbrev-ref", "HEAD" }
  local result = run_cmd(args)
  if type(result.stdout) ~= "table" or #result.stdout == 0 then
    return nil
  end
  logger:debug(
    string.format(
      "|get_current_branch| running %s: %s",
      vim.inspect(args),
      vim.inspect(result.stdout)
    )
  )
  return result.stdout[1]
end

local M = {
  CmdResult = CmdResult,
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
