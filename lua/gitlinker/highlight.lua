local M = {}

local hl_namespace = "NvimGitLinker"

-- highlight groups
M.hlgroups = { NvimGitLinkerHighlightTextObject = "Search" }

-- Highlights the text selected by the specified range.
--- @param range Range?
M.show = function(range)
    if not range then
        return
    end
    local namespace = vim.api.nvim_create_namespace(hl_namespace)
    local lstart, lend = range.lstart, range.lend
    if lend and lend < lstart then
        lstart, lend = lend, lstart
    end
    local pos1 = { lstart - 1, 1 }
    local pos2 = { (lend or lstart) - 1, vim.fn.col("$") }
    vim.schedule(function()
        vim.highlight.range(
            0,
            namespace,
            "NvimGitLinkerHighlightTextObject",
            pos1,
            pos2,
            { inclusive = true }
        )
        -- Force the screen to highlight the text immediately
        vim.cmd("redraw")
    end)
end

-- Clears the gitlinker highlights for the buffer.
M.clear = function()
    local namespace = vim.api.nvim_create_namespace(hl_namespace)
    vim.api.nvim_buf_clear_namespace(0, namespace, 0, -1)
    -- Force the screen to clear the highlight immediately
    vim.schedule(function()
        vim.cmd("redraw")
    end)
end

return M
