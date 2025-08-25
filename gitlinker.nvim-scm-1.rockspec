rockspec_format = "3.0"
package = "gitlinker.nvim"
version = "scm-1"

test_dependencies = {
  "lua >= 5.1",
  "nlua",
}

source = {
  url = "git+https://github.com/linrongbin16/" .. package,
}

build = {
  type = "builtin",
}
