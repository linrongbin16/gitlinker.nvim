--- @class Range
--- @field lstart integer
--- @field lend integer
local Range = {}

--- @param m string
--- @return boolean
local function _is_visual_mode(m)
    return type(m) == "string" and string.upper(m) == "V"
        or string.upper(m) == "CTRL-V"
        or string.upper(m) == "<C-V>"
        or m == "\22"
end

--- @return LineRange
local function line_range() end

--- @param r Options?
--- @return Range
function Range:new(r)
    local lstart = nil
    local lend = nil
    if
        type(r) == "table"
        and type(r.lstart) == "number"
        and type(r.lend) == "number"
    then
        lstart = r.lstart --[[@as integer]]
        lend = r.lend --[[@as integer]]
    else
        local m = vim.fn.mode()
        local l1 = nil
        local l2 = nil
        if _is_visual_mode(m) then
            vim.cmd([[execute "normal! \<ESC>"]])
            l1 = vim.fn.getpos("'<")[2]
            l2 = vim.fn.getpos("'>")[2]
        else
            l1 = vim.fn.getcurpos()[2]
            l2 = l1
        end
        lstart = math.min(l1, l2)
        lend = math.max(l1, l2)
    end
    local o = {
        lstart = lstart,
        lend = lend,
    }
    setmetatable(o, self)
    self.__index = self
    return o
end

local M = {
    Range = Range,
}

return M
