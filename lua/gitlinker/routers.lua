local utils = require("gitlinker.utils")

--- @class Builder
--- @field protocol string?
--- @field host string?
--- @field user string?
--- @field repo string?
--- @field rev string?
--- @field file string?
--- @field range string?
local Builder = {}

--- @param r Range?
--- @return string?
local function _range_LC(r)
  if type(r) ~= "table" or type(r.lstart) ~= "number" then
    return nil
  end
  local tmp = string.format([[#L%d]], r.lstart)
  if type(r.lend) == "number" and r.lend > r.lstart then
    tmp = tmp .. string.format([[-L%d]], r.lend)
  end
  return tmp
end

--- @param r {lstart:integer?,lend:integer?,cstart:integer?,cend:integer?}?
--- @return string?
local function _range_lines(r)
  if type(r) ~= "table" or type(r.lstart) ~= "number" then
    return nil
  end
  local tmp = string.format([[#lines-%d]], r.lstart)
  if type(r.lend) == "number" and r.lend > r.lstart then
    tmp = tmp .. string.format([[:%d]], r.lend)
  end
  return tmp
end

--- @param lk Linker
--- @param range_maker fun()
--- @return Builder
function Builder:new(lk)
  local r = _range_LC({ lstart = lk.lstart, lend = lk.lend })
  local o = {
    protocol = lk.protocol == "git" and "https://" or (lk.protocol .. "://"),
    host = lk.host .. "/",
    user = lk.user .. "/",
    repo = (utils.string_endswith(lk.repo, ".git") and lk.repo:sub(
      1,
      #lk.repo - 4
    ) or lk.repo) .. "/",
    rev = lk.rev .. "/",
    file = lk.file .. (utils.string_endswith(
      lk.file,
      ".md",
      { ignorecase = true }
    ) and "?plain=1" or ""),
    range = type(r) == "string" and r or "",
  }
  setmetatable(o, self)
  self.__index = self

  return o
end

--- @param url "blob"|"blame"|"src"
--- @return string
function Builder:build(url)
  return table.concat({
    self.protocol,
    self.host,
    self.user,
    self.repo,
    url .. "/",
    self.rev,
    self.file,
    self.range,
  }, "")
end

--- @param lk Linker
--- @return string
local function blob(lk)
  local builder = Builder:new(lk)
  return builder:build("blob")
end

--- @param lk Linker
--- @return string
local function src(lk)
  local builder = Builder:new(lk)
  return builder:build("src")
end

--- @param lk Linker
--- @return string
local function blame(lk)
  local builder = Builder:new(lk)
  return builder:build("blame")
end

local M = {
  blob = blob,
  blame = blame,
  src = src,
}

return M
