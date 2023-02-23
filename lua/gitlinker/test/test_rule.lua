local opts = require("gitlinker.opts")

local rule = opts.get().rule

-- test data:
--  input data: git config
--  expect data: url link
local test_cases = {
  {
    "git@github.com:linrongbin16/gitlinker.nvim.git",
    "https://github.com/linrongbin16/gitlinker.nvim.git",
  },
  {
    "git@github.com:linrongbin16/gitlinker.nvim",
    "https://github.com/linrongbin16/gitlinker.nvim",
  },
  {
    "https://github.com/ruifm/gitlinker.nvim.git",
    "https://github.com/ruifm/gitlinker.nvim.git",
  },
  {
    "https://github.com/ruifm/gitlinker.nvim",
    "https://github.com/ruifm/gitlinker.nvim",
  },
  {
    "https://github.com/ruifm/gitlinker.nvim",
    "https://github.com/ruifm/gitlinker.nvim",
  },
  {
    "git@github.enterprise.io:organization/repository.git",
    "https://github.enterprise.io/organization/repository.git",
  },
  {
    "git@github.enterprise.io:organization/repository",
    "https://github.enterprise.io/organization/repository",
  },
  {
    "https://github.enterprise.io/organization/repository.git",
    "https://github.enterprise.io/organization/repository.git",
  },
  {
    "https://github.enterprise.io/organization/repository",
    "https://github.enterprise.io/organization/repository",
  },
}

for i, case in ipairs(test_cases) do
  local actual = rule(case[1])
  local expect = case[2]
  assert(
    actual == expect,
    string.format(
      "Failed test case [%d] - actual: `%s` != expect: `%s`",
      i,
      tostring(actual),
      tostring(expect)
    )
  )
end

-- Run tests in nvim: `lua require('gitlinker.test.test_rule')`
