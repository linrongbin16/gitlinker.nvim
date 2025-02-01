local logging = require("gitlinker.commons.logging")
local str = require("gitlinker.commons.str")

local async = require("gitlinker.commons.async")
local git = require("gitlinker.git")
local path = require("gitlinker.path")
local giturlparser = require("gitlinker.giturlparser")

--- @return string?
local function _get_buf_dir()
  local logger = logging.get("gitlinker")
  local buf_path = vim.api.nvim_buf_get_name(0)
  local buf_dir = vim.fn.fnamemodify(buf_path, ":p:h")
  logger:debug(
    string.format(
      "|_get_buf_dir| buf_path:%s, buf_dir:%s",
      vim.inspect(buf_path),
      vim.inspect(buf_dir)
    )
  )
  if str.empty(buf_dir) or vim.fn.isdirectory(buf_dir or "") <= 0 then
    return nil
  end
  return buf_dir
end

--- @alias gitlinker.Linker {remote_url:string,protocol:string?,username:string?,password:string?,host:string,port:string?,org:string?,user:string?,repo:string,rev:string,file:string,lstart:integer,lend:integer,file_changed:boolean,default_branch:string?,current_branch:string?}
--- @param remote string?
--- @param file string?
--- @param rev string?
--- @return gitlinker.Linker?
local function make_linker(remote, file, rev)
  local logger = logging.get("gitlinker")
  local cwd = _get_buf_dir()

  local file_provided = str.not_empty(file)
  local rev_provided = str.not_empty(rev)

  local root = git.get_root(cwd)
  if not root then
    return nil
  end

  if str.empty(remote) then
    remote = git.get_branch_remote(cwd)
  end
  if not remote then
    return nil
  end
  -- logger.debug("|linker - Linker:make| remote:%s", vim.inspect(remote))

  local remote_url = git.get_remote_url(remote, cwd)
  if not remote_url then
    return nil
  end

  local parsed_url, parsed_err = giturlparser.parse(remote_url) --[[@as table, string?]]
  logger:debug(
    string.format(
      "|make_linker| remote:%s, parsed_url:%s, parsed_err:%s",
      vim.inspect(remote),
      vim.inspect(parsed_url),
      vim.inspect(parsed_err)
    )
  )
  logger:ensure(
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

  if not rev_provided then
    rev = git.get_closest_remote_compatible_rev(remote, cwd)
  end
  if str.empty(rev) then
    return nil
  end
  -- logger.debug("|linker - Linker:make| rev:%s", vim.inspect(rev))

  async.schedule()

  if not file_provided then
    local buf_path_on_root = path.buffer_relpath(root) --[[@as string]]
    local buf_path_encoded = vim.uri_encode(buf_path_on_root) --[[@as string]]
    -- logger.debug(
    --     "|linker - Linker:make| root:%s, buf_path_on_root:%s",
    --     vim.inspect(root),
    --     vim.inspect(buf_path_on_root)
    -- )

    local file_in_rev_result = git.is_file_in_rev(buf_path_on_root, rev --[[@as string]], cwd)
    if not file_in_rev_result then
      return nil
    end
    file = buf_path_encoded
  else
    file = vim.uri_encode(file)
  end

  -- logger.debug(
  --     "|linker - Linker:make| file_in_rev_result:%s",
  --     vim.inspect(file_in_rev_result)
  -- )

  async.schedule()

  local file_changed = false
  if not file_provided then
    local buf_path_on_cwd = path.buffer_relpath() --[[@as string]]
    file_changed = git.file_has_changed(buf_path_on_cwd, rev --[[@as string]], cwd)
    -- logger.debug(
    --     "|linker - Linker:make| buf_path_on_cwd:%s",
    --     vim.inspect(buf_path_on_cwd)
    -- )
  end

  local default_branch = git.get_default_branch(remote, cwd)
  local current_branch = git.get_current_branch(cwd)

  local o = {
    remote_url = remote_url,
    protocol = parsed_url.protocol,
    username = parsed_url.user,
    password = parsed_url.password,
    host = resolved_host,
    port = parsed_url.port,
    --- @deprecated please use 'org'
    user = parsed_url.org,
    org = parsed_url.org,
    repo = parsed_url.repo,
    rev = rev,
    file = file,
    ---@diagnostic disable-next-line: need-check-nil
    lstart = nil,
    ---@diagnostic disable-next-line: need-check-nil
    lend = nil,
    file_changed = file_changed,
    default_branch = default_branch,
    current_branch = current_branch,
  }

  logger:debug(string.format("|make_linker| o:%s", vim.inspect(o)))
  return o
end

local M = {
  make_linker = make_linker,
}

return M
