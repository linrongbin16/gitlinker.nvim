local log = require("gitlinker.log")
local types = require("gitlinker.types")
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
  if types.str_empty(buf_dir) or vim.fn.isdirectory(buf_dir or "") <= 0 then
    return nil,
      string.format(
        "fatal: current buffer is not in a valid git repository: %s",
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
  local buf_dir, buf_dir_err = _get_buf_dir()
  if not buf_dir then
    return nil, buf_dir_err
  end

  -- Locate the repository root once: every git command below runs there, so
  -- that pathspecs and `rev:path` tree lookups share a single, stable base
  -- instead of the buffer directory (which `git diff` would resolve against).
  local root, root_err = git.get_root(buf_dir)
  if not root then
    return nil, root_err
  end

  -- `remote` is optional on the public API, but every git call below needs a
  -- concrete name, so resolve it once into a non-optional local.
  --- @type string
  local selected_remote
  if types.str_empty(remote) then
    local detected_remote, detected_remote_err = git.get_branch_remote(root)
    if not detected_remote then
      return nil, detected_remote_err
    end
    selected_remote = detected_remote
  else
    selected_remote = remote --[[@as string]]
  end

  local remote_url, remote_url_err = git.get_remote_url(selected_remote, root)
  if not remote_url then
    return nil, remote_url_err
  end

  local parsed_url, parsed_url_err = giturlparser.parse(remote_url) --[[@as table, string?]]
  log.debug(
    string.format(
      "|make_linker| remote:%s, parsed_url:%s, parsed_err:%s",
      vim.inspect(remote),
      vim.inspect(parsed_url),
      vim.inspect(parsed_url_err)
    )
  )
  if not parsed_url then
    return nil,
      string.format(
        "fatal: failed to parse git remote url:%s, error:%s",
        vim.inspect(remote_url),
        vim.inspect(parsed_url_err)
      )
  end
  local resolved_host, resolved_host_err = git.resolve_host(parsed_url.host, root)
  if not resolved_host then
    return nil, resolved_host_err
  end

  local saved_rev = rev

  -- If rev (git commit ID) is not provided, detect with current git HEAD commit
  if not types.str_empty(rev) then
    -- Resolve the revspec so callers can pass 'HEAD', a branch or a tag and
    -- still get a permanent link. A full commit ID resolves to itself.
    local resolved_rev, resolved_rev_err = git._get_rev(rev --[[@as string]], root)
    if not resolved_rev then
      return nil, resolved_rev_err
    end
    rev = resolved_rev
  else
    local closest_rev, closest_rev_err =
      git.get_closest_remote_compatible_rev(selected_remote, root)
    if not closest_rev then
      return nil, closest_rev_err
    end
    rev = closest_rev
  end
  if types.str_empty(rev) then
    return nil,
      string.format("fatal: failed to resolve the revision %s to link to", vim.inspect(saved_rev))
  end
  -- logger.debug("|linker - Linker:make| rev:%s", vim.inspect(rev))

  async.await(1, vim.schedule)

  local file_changed = false

  -- If file parameter is not provided, detect file with current buffer
  if types.str_empty(file) then
    -- Both the tree lookup and the diff below run in the repository root, so
    -- the path handed to them has to be root-relative. A path relative to the
    -- buffer directory matches nothing there: `git diff` then exits 0 with
    -- empty output, which reads as "the file has not changed".
    local relpath = path.buffer_relpath(root)
    if not relpath then
      return nil,
        string.format(
          "fatal: failed to resolve the buffer path relative to the git repository root: %s (root: %s)",
          vim.inspect(vim.api.nvim_buf_get_name(0)),
          vim.inspect(root)
        )
    end

    local file_in_rev, file_in_rev_err = git.is_file_in_rev(relpath, rev, root)
    if not file_in_rev then
      return nil, file_in_rev_err
    end
    file = vim.uri_encode(relpath)

    -- `git` resumed this coroutine in a fast event context, and the checks
    -- below touch the editor again, so hop back to the main loop first.
    async.await(1, vim.schedule)

    local changed, changed_err = git.file_has_changed(relpath, rev, root)
    if changed == nil then
      return nil, changed_err
    end
    file_changed = changed
  else
    file = vim.uri_encode(file)
  end

  -- A missing default/current branch must not stop the link from being built,
  -- the router simply renders an empty value for it. Report and carry on.
  local default_branch, default_branch_err = git.get_default_branch(selected_remote, root)
  if default_branch_err then
    log.warn(default_branch_err)
  end
  local current_branch, current_branch_err = git.get_current_branch(root)
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
