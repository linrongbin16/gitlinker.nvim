local cwd = vim.fn.getcwd()

describe("highlight", function()
    local assert_eq = assert.is_equal
    local assert_true = assert.is_true
    local assert_false = assert.is_false

    before_each(function()
        vim.api.nvim_command("cd " .. cwd)
    end)

    local highlight = require("gitlinker.highlight")
    describe("[highlight]", function()
        it("is", function()
            assert_eq(type(highlight.hlgroups), "table")
            assert_eq(
                highlight.hlgroups.NvimGitLinkerHighlightTextObject,
                "Search"
            )
        end)
        it("shows", function()
            vim.cmd([[edit README.md]])
            highlight.show({ lstart = 0, lend = -1 })
        end)
        it("clear", function()
            highlight.clear()
        end)
    end)
end)
