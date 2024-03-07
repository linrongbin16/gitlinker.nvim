local str = require("gitlinker.commons.str")
local logging = require("gitlinker.commons.logging")

local range = require("gitlinker.range")

--- @class gitlinker.Builder
--- @field domain string?
--- @field org string?
--- @field repo string?
--- @field rev string?
--- @field location string?
local Builder = {}

--- @alias gitlinker.RangeStringify fun(r:gitlinker.Range?):string?

--- @param r gitlinker.Range?
--- @return string?
local function LC_range(r)
  if not range.is_range(r) then
    return nil
  end
  assert(r ~= nil)
  local tmp = string.format([[#L%d]], r.lstart)
  if type(r.lend) == "number" and r.lend > r.lstart then
    tmp = tmp .. string.format([[-L%d]], r.lend)
  end
  return tmp
end

--- @param r gitlinker.Range?
--- @return string?
local function github_LC_range(r)
  if not range.is_range(r) then
    return nil
  end
  assert(r ~= nil)
  local tmp = string.format([[?plain=1#L%d]], r.lstart)
  if type(r.lend) == "number" and r.lend > r.lstart then
    tmp = tmp .. string.format([[-L%d]], r.lend)
  end
  return tmp
end

--- @param r gitlinker.Range?
--- @return string?
local function codeberg_LC_range(r)
  if not range.is_range(r) then
    return nil
  end
  assert(r ~= nil)
  local tmp = string.format([[?display=source#L%d]], r.lstart)
  if type(r.lend) == "number" and r.lend > r.lstart then
    tmp = tmp .. string.format([[-L%d]], r.lend)
  end
  return tmp
end

--- @param r gitlinker.Range?
--- @return string?
local function lines_range(r)
  if not range.is_range(r) then
    return nil
  end
  assert(r ~= nil)
  local tmp = string.format([[#lines-%d]], r.lstart)
  if type(r.lend) == "number" and r.lend > r.lstart then
    tmp = tmp .. string.format([[:%d]], r.lend)
  end
  return tmp
end

-- example:
-- https://github.com/linrongbin16/gitlinker.nvim/blob/c798df0f482bd00543023c4ec016218a2a6293a0/lua/gitlinker/routers.lua#L44-L49
-- https://bitbucket.org/gitlinkernvim/gitlinker.nvim/src/dbf3922382576391fbe50b36c55066c1768b08b6/.gitignore#lines-1:6
--
--- @param lk gitlinker.Linker
--- @param range_maker gitlinker.RangeStringify
--- @return gitlinker.Builder
function Builder:new(lk, range_maker)
  local r = range_maker({ lstart = lk.lstart, lend = lk.lend })
  local o = {
    domain = string.format("https://%s", lk.host),
    org = lk.org,
    repo = str.endswith(lk.repo, ".git") and lk.repo:sub(1, #lk.repo - 4) or lk.repo,
    rev = lk.rev,
    location = string.format(
      "%s%s",
      lk.file .. (str.endswith(lk.file, ".md", { ignorecase = true }) and "?plain=1" or ""),
      type(r) == "string" and r or ""
    ),
  }
  setmetatable(o, self)
  self.__index = self

  return o
end

--- @param url string
--- @return string
function Builder:build(url)
  return table.concat({
    self.domain,
    self.org,
    self.repo,
    url,
    self.rev,
    self.location,
  }, "/")
end

-- browse {

-- example: https://git.samba.org/?p=samba.git;a=blob;f=wscript;hb=399b1d05473c711fc5592a6ffc724e231c403486#l12
--- @param lk gitlinker.Linker
--- @return string
local function samba_browse(lk)
  local logger = logging.get("gitlinker")

  logger:debug("|samba_browse| lk:%s", vim.inspect(lk))
  local builder = "https://git.samba.org/?p="
  -- org
  builder = builder .. (string.len(lk.org) > 0 and string.format("%s/", lk.org) or "")
  -- repo
  builder = builder .. string.format("%s;a=blob;", lk.repo)
  -- file: 'wscript'
  builder = builder .. string.format("f=%s;", lk.file)
  -- rev
  builder = builder .. string.format("hb=%s", lk.rev)
  -- line number
  builder = builder .. string.format("#l%d", lk.lstart)
  return builder
end

--- @param lk gitlinker.Linker
--- @return string
local function github_browse(lk)
  local builder = Builder:new(lk, github_LC_range)
  return builder:build("blob")
end

--- @param lk gitlinker.Linker
--- @return string
local function gitlab_browse(lk)
  local builder = Builder:new(lk, LC_range)
  return builder:build("blob")
end

--- @param lk gitlinker.Linker
--- @return string
local function bitbucket_browse(lk)
  local builder = Builder:new(lk, lines_range)
  return builder:build("src")
end

--- @param lk gitlinker.Linker
--- @return string
local function codeberg_browse(lk)
  local builder = Builder:new(lk, codeberg_LC_range)
  return builder:build("src/commit")
end

-- browse }

-- blame {

--- @param lk gitlinker.Linker
--- @return string
local function github_blame(lk)
  local builder = Builder:new(lk, github_LC_range)
  return builder:build("blame")
end

--- @param lk gitlinker.Linker
--- @return string
local function gitlab_blame(lk)
  local builder = Builder:new(lk, LC_range)
  return builder:build("blame")
end

--- @param lk gitlinker.Linker
--- @return string
local function bitbucket_blame(lk)
  local builder = Builder:new(lk, lines_range)
  return builder:build("annotate")
end

--- @param lk gitlinker.Linker
--- @return string
local function codeberg_blame(lk)
  local builder = Builder:new(lk, codeberg_LC_range)
  return builder:build("blame/commit")
end

-- blame }

local M = {
  -- Builder
  Builder = Builder,

  -- line ranges
  LC_range = LC_range,
  lines_range = lines_range,

  -- browse: `/blob`, `/src`
  samba_browse = samba_browse,
  github_browse = github_browse,
  gitlab_browse = gitlab_browse,
  bitbucket_browse = bitbucket_browse,
  codeberg_browse = codeberg_browse,

  -- blame: `/blame`, `/annotate`
  github_blame = github_blame,
  gitlab_blame = gitlab_blame,
  bitbucket_blame = bitbucket_blame,
  codeberg_blame = codeberg_blame,
}

return M
