local git = require("gitlinker.git")
local path = require("gitlinker.path")
local logger = require("gitlinker.logger")
local utils = require("gitlinker.utils")

-- example:
-- git@github.com:linrongbin16/gitlinker.nvim.git
-- https://github.com/linrongbin16/gitlinker.nvim.git
-- ssh://git@git.xyz.abc/PROJECT_KEY/PROJECT.git
-- https://git.samba.org/samba.git (main repo without user component)
-- https://git.samba.org/ab/samba.git (dev repo with user component)
--
--- @param remote_url string
--- @return {protocol:string?,host:string?,host_delimiter:string?,user:string?,repo:string?}
local function _parse_remote_url(remote_url)
  local PROTOS = { "git@", "https://", "http://" }
  local INT32_MAX = 2 ^ 31 - 1

  local protocol = nil
  local protocol_end_pos = nil
  local host = nil
  local host_end_pos = nil
  local host_delimiter = nil
  local user = nil
  local repo = nil

  --- @type string
  local proto = nil
  --- @type integer?
  local proto_pos = nil
  for _, p in ipairs(PROTOS) do
    proto_pos = utils.string_find(remote_url, p)
    if type(proto_pos) == "number" and proto_pos > 0 then
      proto = p
      break
    end
  end
  if not proto_pos then
    error(
      string.format(
        "failed to parse remote url protocol:%s",
        vim.inspect(remote_url)
      )
    )
  end

  logger.debug(
    "|gitlinker.linker - _parse_remote_url| 1. remote_url:%s, proto_pos:%s (%s)",
    vim.inspect(remote_url),
    vim.inspect(proto_pos),
    vim.inspect(proto)
  )
  if type(proto_pos) == "number" and proto_pos > 0 then
    protocol_end_pos = proto_pos + string.len(proto) - 1
    protocol = remote_url:sub(1, protocol_end_pos)
    logger.debug(
      "|gitlinker.linker - _parse_remote_url| 2. remote_url:%s, proto_pos:%s (%s), protocol_end_pos:%s (%s)",
      vim.inspect(remote_url),
      vim.inspect(proto_pos),
      vim.inspect(proto),
      vim.inspect(protocol_end_pos),
      vim.inspect(protocol)
    )
    local first_slash_pos = utils.string_find(
      remote_url,
      "/",
      protocol_end_pos + 1
    ) or INT32_MAX
    local first_colon_pos = utils.string_find(
      remote_url,
      ":",
      protocol_end_pos + 1
    ) or INT32_MAX
    host_end_pos = math.min(first_slash_pos, first_colon_pos)
    if not host_end_pos then
      error(
        string.format(
          "failed to parse remote url host:%s",
          vim.inspect(remote_url)
        )
      )
    end
    host_delimiter = remote_url:sub(host_end_pos, host_end_pos)
    host = remote_url:sub(protocol_end_pos + 1, host_end_pos - 1)
    logger.debug(
      "|gitlinker.linker - _parse_remote_url| last. remote_url:%s, proto_pos:%s (%s), protocol_end_pos:%s (%s), host_end_pos:%s (%s), host_delimiter:%s",
      vim.inspect(remote_url),
      vim.inspect(proto_pos),
      vim.inspect(proto),
      vim.inspect(protocol_end_pos),
      vim.inspect(protocol),
      vim.inspect(host_end_pos),
      vim.inspect(host),
      vim.inspect(host_delimiter)
    )
  end

  local user_end_pos = utils.string_find(remote_url, "/", host_end_pos + 1)
  if type(user_end_pos) == "number" and user_end_pos > host_end_pos + 1 then
    user = remote_url:sub(host_end_pos + 1, user_end_pos - 1)
    repo = remote_url:sub(user_end_pos + 1)
  else
    -- if no slash '/', then don't have 'user', but only 'repo'
    -- example:
    -- * main repo: https://git.samba.org/?p=samba.git
    -- * user dev repo: https://git.samba.org/?p=bbaumbach/samba.git
    repo = remote_url:sub(host_end_pos + 1)
    user = ""
  end
  local result = {
    protocol = protocol,
    host = host,
    host_delimiter = host_delimiter,
    user = user,
    repo = repo,
  }
  logger.debug("linker._parse_remote_url| result:%s", vim.inspect(result))
  return result
end

--- @alias gitlinker.Linker {remote_url:string,protocol:string,host:string,host_delimiter:string,user:string,repo:string?,rev:string,file:string,lstart:integer,lend:integer,file_changed:boolean,default_branch:string?,current_branch:string?}
--- @param remote string?
--- @return gitlinker.Linker?
local function make_linker(remote)
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

  local parsed_remote_url = _parse_remote_url(remote_url)
  local resolved_host = git.resolve_host(parsed_remote_url.host)
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
    protocol = parsed_remote_url.protocol,
    host = resolved_host,
    host_delimiter = parsed_remote_url.host_delimiter,
    user = parsed_remote_url.user,
    repo = parsed_remote_url.repo,
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

  logger.debug("|linker.make_linker| o:%s", vim.inspect(o))
  return o
end

local M = {
  _parse_remote_url = _parse_remote_url,
  make_linker = make_linker,
}

return M
