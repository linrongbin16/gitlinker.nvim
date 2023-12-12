-- Render text with terminal colors

local M = {}

--- @param attr "fg"|"bg"
--- @param code string
--- @return string
M.escape = function(attr, code)
  assert(type(code) == "string")
  assert(attr == "bg" or attr == "fg")

  local control = attr == "fg" and 38 or 48
  local r, g, b = code:match("#(..)(..)(..)")
  if r and g and b then
    r = tonumber(r, 16)
    g = tonumber(g, 16)
    b = tonumber(b, 16)
    return string.format("%d;2;%d;%d;%d", control, r, g, b)
  else
    return string.format("%d;5;%s", control, code)
  end
end

-- Pre-defined CSS colors
-- Also see: https://www.quackit.com/css/css_color_codes.cfm
local CSS_COLORS = {
  black = "0;30",
  grey = M.escape("fg", "#808080"),
  silver = M.escape("fg", "#c0c0c0"),
  white = M.escape("fg", "#ffffff"),
  violet = M.escape("fg", "#EE82EE"),
  magenta = "0;35",
  fuchsia = M.escape("fg", "#FF00FF"),
  red = "0;31",
  purple = M.escape("fg", "#800080"),
  indigo = M.escape("fg", "#4B0082"),
  yellow = "0;33",
  gold = M.escape("fg", "#FFD700"),
  orange = M.escape("fg", "#FFA500"),
  chocolate = M.escape("fg", "#D2691E"),
  olive = M.escape("fg", "#808000"),
  green = "0;32",
  lime = M.escape("fg", "#00FF00"),
  teal = M.escape("fg", "#008080"),
  cyan = "0;36",
  aqua = M.escape("fg", "#00FFFF"),
  blue = "0;34",
  navy = M.escape("fg", "#000080"),
  slateblue = M.escape("fg", "#6A5ACD"),
  steelblue = M.escape("fg", "#4682B4"),
}

--- @param attr "fg"|"bg"
--- @param hl string
--- @return string?
M.retrieve = function(attr, hl)
  assert(type(hl) == "string")
  assert(attr == "bg" or attr == "fg")

  local gui = vim.fn.has("termguicolors") > 0 and vim.o.termguicolors
  local family = gui and "gui" or "cterm"
  local pattern = gui and "^#[%l%d]+" or "^[%d]+$"
  local code =
    vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID(hl)), attr, family) --[[@as string]]
  if string.find(code, pattern) then
    return code
  end
  return nil
end

--- @param text string   the text content to be rendered
--- @param name string      the ANSI color name or RGB color codes
--- @param hl string?       the highlighting group name
--- @return string
M.render = function(text, name, hl)
  local strings = require("gitlinker.commons.strings")

  local fgfmt = nil
  local fgcode = strings.not_empty(hl) and M.retrieve("fg", hl --[[@as string]])
    or nil
  if type(fgcode) == "string" then
    fgfmt = M.escape("fg", fgcode)
  elseif CSS_COLORS[name] then
    fgfmt = CSS_COLORS[name]
  else
    fgfmt = M.escape("fg", name)
  end

  local fmt = nil
  local bgcode = strings.not_empty(hl) and M.retrieve("bg", hl --[[@as string]])
    or nil
  if type(bgcode) == "string" then
    local bgcolor = M.escape("bg", bgcode)
    fmt = string.format("%s;%s", fgfmt, bgcolor)
  else
    fmt = fgfmt
  end
  return string.format("[%sm%s[0m", fmt, text)
end

-- Unescape(erase) the terminal colors from `text` content.
--
-- Returns the raw text content.
--
--- @param text string?
--- @return string?
M.erase = function(text)
  assert(type(text) == "string")

  local result, pos = text
    :gsub("\x1b%[%d+m\x1b%[K", "")
    :gsub("\x1b%[m\x1b%[K", "")
    :gsub("\x1b%[%d+;%d+;%d+;%d+;%d+m", "")
    :gsub("\x1b%[%d+;%d+;%d+;%d+m", "")
    :gsub("\x1b%[%d+;%d+;%d+m", "")
    :gsub("\x1b%[%d+;%d+m", "")
    :gsub("\x1b%[%d+m", "")
  return result
end

-- Helper functions for the `render` API.
-- Render `text` content with pre-defined CSS color (see CSS_COLORS), or vim's syntax highlighting group (only if been provided).
do
  for name, code in pairs(CSS_COLORS) do
    --- @param text string
    --- @param hl string?
    --- @return string
    M[name] = function(text, hl)
      return M.render(text, name, hl)
    end
  end
end

return M
