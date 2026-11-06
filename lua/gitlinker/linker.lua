local log = require("gitlinker.commons.log")
local str = require("gitlinker.commons.str")
local async = require("gitlinker.commons.async")

local git = require("gitlinker.git")
local path = require("gitlinker.path")
local giturlparser = require("gitlinker.giturlparser")

--- @return string?, string?
local function _get_buf_dir()
  local buf_path = vim.api.nvim_buf_get_name(0)
  local buf_dir = vim.fn.fnamemodify(buf_path, ":p:h")
  log.debug(
    string.format(
      "|_get_buf_dir| buf_path:%s, buf_dir:%s",
      vim.inspect(buf_path),
      vim.inspect(buf_dir)
    )
  )
  if str.empty(buf_dir) or vim.fn.isdirectory(buf_dir or "") <= 0 then
    return nil,
      string.format(
        "fatal: current buffer has no valid directory, buffer:%s",
        vim.inspect(buf_path)
      )
  end
  return buf_dir, nil
end

--- @alias gitlinker.Linker {remote_url:string,protocol:string?,username:string?,password:string?,host:string,port:string?,org:string?,user:string?,repo:string,rev:string,file:string,lstart:integer,lend:integer,file_changed:boolean,default_branch:string?,current_branch:string?}
--- @param remote string?
--- @param file string?
--- @param rev string?
--- @return gitlinker.Linker?, string?
local function make_linker(remote, file, rev)
  local cwd, cwd_err = _get_buf_dir()
  if not cwd then
    return nil, cwd_err
  end

  local file_provided = str.not_empty(file)
  local rev_provided = str.not_empty(rev)

  local root, root_err = git.get_root(cwd)
  if not root then
    return nil, root_err
  end

  -- `remote` is optional on the public API, but every git call below needs a
  -- concrete name, so resolve it once into a non-optional local.
  --- @type string
  local selected_remote
  if str.empty(remote) then
    local detected_remote, detected_err = git.get_branch_remote(cwd)
    if not detected_remote then
      return nil, detected_err
    end
    selected_remote = detected_remote
  else
    selected_remote = remote --[[@as string]]
  end

  local remote_url, remote_url_err = git.get_remote_url(selected_remote, cwd)
  if not remote_url then
    return nil, remote_url_err
  end

  local parsed_url, parsed_err = giturlparser.parse(remote_url) --[[@as table, string?]]
  log.debug(
    string.format(
      "|make_linker| remote:%s, parsed_url:%s, parsed_err:%s",
      vim.inspect(remote),
      vim.inspect(parsed_url),
      vim.inspect(parsed_err)
    )
  )
  if not parsed_url then
    return nil,
      string.format(
        "fatal: failed to parse git remote url:%s, error:%s",
        vim.inspect(remote_url),
        vim.inspect(parsed_err)
      )
  end
  local resolved_host, host_err = git.resolve_host(parsed_url.host, cwd)
  if not resolved_host then
    return nil, host_err
  end

  if rev_provided then
    -- Resolve the revspec so callers can pass 'HEAD', a branch or a tag and
    -- still get a permanent link. A full commit ID resolves to itself.
    local resolved_rev, rev_err = git._get_rev(rev --[[@as string]], cwd)
    if not resolved_rev then
      return nil, rev_err
    end
    rev = resolved_rev
  else
    local closest_rev, closest_err = git.get_closest_remote_compatible_rev(selected_remote, cwd)
    if not closest_rev then
      return nil, closest_err
    end
    rev = closest_rev
  end
  if str.empty(rev) then
    return nil, "fatal: failed to resolve the revision to link to"
  end
  -- logger.debug("|linker - Linker:make| rev:%s", vim.inspect(rev))

  async.await(1, vim.schedule)

  if not file_provided then
    local buf_path_on_root = path.buffer_relpath(root) --[[@as string]]
    local buf_path_encoded = vim.uri_encode(buf_path_on_root) --[[@as string]]

    local file_in_rev_result, file_in_rev_err =
      git.is_file_in_rev(buf_path_on_root, rev --[[@as string]], cwd)
    if not file_in_rev_result then
      return nil, file_in_rev_err
    end
    file = buf_path_encoded
  else
    file = vim.uri_encode(file)
  end

  async.await(1, vim.schedule)

  local file_changed = false
  if not file_provided then
    local buf_path_on_cwd = path.buffer_relpath() --[[@as string]]
    local changed, changed_err = git.file_has_changed(buf_path_on_cwd, rev --[[@as string]], cwd)
    if changed == nil then
      return nil, changed_err
    end
    file_changed = changed
  end

  -- A missing default/current branch must not stop the link from being built,
  -- the router simply renders an empty value for it. Report and carry on.
  local default_branch, default_branch_err = git.get_default_branch(selected_remote, cwd)
  if default_branch_err then
    log.warn(default_branch_err)
  end
  local current_branch, current_branch_err = git.get_current_branch(cwd)
  if current_branch_err then
    log.warn(current_branch_err)
  end

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

  log.debug(string.format("|make_linker| o:%s", vim.inspect(o)))
  return o, nil
end

local M = {
  make_linker = make_linker,
}

return M
