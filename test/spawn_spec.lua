local cwd = vim.fn.getcwd()

describe("spawn", function()
    local assert_eq = assert.is_equal
    local assert_true = assert.is_true
    local assert_false = assert.is_false

    before_each(function()
        vim.api.nvim_command("cd " .. cwd)
    end)

    local spawn = require("gitlinker.spawn")

    describe("[_string_find]", function()
        it("found", function()
            assert_eq(spawn._string_find("abcdefg", "a"), 1)
            assert_eq(spawn._string_find("abcdefg", "a", 1), 1)
            assert_eq(spawn._string_find("abcdefg", "g"), 7)
            assert_eq(spawn._string_find("abcdefg", "g", 1), 7)
            assert_eq(spawn._string_find("abcdefg", "g", 7), 7)
            assert_eq(spawn._string_find("fzfx -- -w -g *.lua", "--"), 6)
            assert_eq(spawn._string_find("fzfx -- -w -g *.lua", "--", 1), 6)
            assert_eq(spawn._string_find("fzfx -- -w -g *.lua", "--", 2), 6)
            assert_eq(spawn._string_find("fzfx -- -w -g *.lua", "--", 3), 6)
            assert_eq(spawn._string_find("fzfx -- -w -g *.lua", "--", 6), 6)
            assert_eq(spawn._string_find("fzfx -w -- -g *.lua", "--"), 9)
            assert_eq(spawn._string_find("fzfx -w -- -g *.lua", "--", 1), 9)
            assert_eq(spawn._string_find("fzfx -w -- -g *.lua", "--", 2), 9)
            assert_eq(spawn._string_find("fzfx -w ---g *.lua", "--", 8), 9)
            assert_eq(spawn._string_find("fzfx -w ---g *.lua", "--", 9), 9)
        end)
        it("not found", function()
            assert_eq(spawn._string_find("abcdefg", "a", 2), nil)
            assert_eq(spawn._string_find("abcdefg", "a", 7), nil)
            assert_eq(spawn._string_find("abcdefg", "g", 8), nil)
            assert_eq(spawn._string_find("abcdefg", "g", 9), nil)
            assert_eq(spawn._string_find("fzfx -- -w -g *.lua", "--", 7), nil)
            assert_eq(spawn._string_find("fzfx -- -w -g *.lua", "--", 8), nil)
            assert_eq(spawn._string_find("fzfx -w -- -g *.lua", "--", 10), nil)
            assert_eq(spawn._string_find("fzfx -w -- -g *.lua", "--", 11), nil)
            assert_eq(spawn._string_find("fzfx -w ---g *.lua", "--", 11), nil)
            assert_eq(spawn._string_find("fzfx -w ---g *.lua", "--", 12), nil)
            assert_eq(spawn._string_find("", "--"), nil)
            assert_eq(spawn._string_find("", "--", 1), nil)
            assert_eq(spawn._string_find("-", "--"), nil)
            assert_eq(spawn._string_find("--", "---", 1), nil)
        end)
    end)
end)
