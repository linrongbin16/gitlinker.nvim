local logging = require("gitlinker.commons.logging")
local git = require("gitlinker.git")
local path = require("gitlinker.path")
local giturlparser = require("gitlinker.giturlparser")
local async = require("gitlinker.commons.async")

--- @alias gitlinker.Linker {remote_url:string,protocol:string,username:string?,password:string?,host:string,org:string?,user:string?,repo:string,rev:string,file:string,lstart:integer,lend:integer,file_changed:boolean,default_branch:string?,current_branch:string?}
--- @param remote string?
--- @return gitlinker.Linker?
local function make_linker(remote)
  local logger = logging.get("gitlinker") --[[@as commons.logging.Logger]]

  local root = git.get_root()
  if not root then
    return nil
  end

  remote = (type(remote) == "string" and string.len(remote) > 0) and remote
    or git.get_branch_remote()
  if not remote then
    return nil
  end
  -- logger.debug("|linker - Linker:make| remote:%s", vim.inspect(remote))

  local remote_url = git.get_remote_url(remote)
  if not remote_url then
    return nil
  end

  local parsed_url, parsed_err = giturlparser.parse(remote_url)
  logger:debug(
    "|make_linker| remote:%s, parsed_url:%s, parsed_err:%s",
    vim.inspect(remote),
    vim.inspect(parsed_url),
    vim.inspect(parsed_err)
  )
  assert(
    parsed_url ~= nil,
    string.format(
      "failed to parse git remote url:%s, error:%s",
      vim.inspect(remote_url),
      vim.inspect(parsed_err)
    )
  )

  local resolved_host = git.resolve_host(parsed_url.host)
  if not resolved_host then
    return nil
  end

  -- logger.debug(
  --     "|linker - Linker:make| remote_url:%s",
  --     vim.inspect(remote_url)
  -- )

  local rev = git.get_closest_remote_compatible_rev(remote)
  if not rev then
    return nil
  end
  -- logger.debug("|linker - Linker:make| rev:%s", vim.inspect(rev))

  async.scheduler()
  local buf_path_on_root = path.buffer_relpath(root) --[[@as string]]
  -- logger.debug(
  --     "|linker - Linker:make| root:%s, buf_path_on_root:%s",
  --     vim.inspect(root),
  --     vim.inspect(buf_path_on_root)
  -- )

  local file_in_rev_result = git.is_file_in_rev(buf_path_on_root, rev)
  if not file_in_rev_result then
    return nil
  end
  -- logger.debug(
  --     "|linker - Linker:make| file_in_rev_result:%s",
  --     vim.inspect(file_in_rev_result)
  -- )

  async.scheduler()
  local buf_path_on_cwd = path.buffer_relpath() --[[@as string]]
  local file_changed = git.file_has_changed(buf_path_on_cwd, rev)
  -- logger.debug(
  --     "|linker - Linker:make| buf_path_on_cwd:%s",
  --     vim.inspect(buf_path_on_cwd)
  -- )

  local default_branch = git.get_default_branch(remote)
  local current_branch = git.get_current_branch()

  local o = {
    remote_url = remote_url,
    protocol = parsed_url.protocol,
    host = resolved_host,
    username = parsed_url.user,
    password = parsed_url.password,
    --- @deprecated please use 'org'
    user = parsed_url.org,
    org = parsed_url.org,
    repo = parsed_url.repo,
    rev = rev,
    file = buf_path_on_root,
    ---@diagnostic disable-next-line: need-check-nil
    lstart = nil,
    ---@diagnostic disable-next-line: need-check-nil
    lend = nil,
    file_changed = file_changed,
    default_branch = default_branch,
    current_branch = current_branch,
  }

  logger:debug("|make_linker| o:%s", vim.inspect(o))
  return o
end

local M = {
  make_linker = make_linker,
}

return M
