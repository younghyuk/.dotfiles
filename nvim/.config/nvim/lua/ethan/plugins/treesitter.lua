return {
  "nvim-treesitter/nvim-treesitter",
  branch = "master",
  lazy = false,
  build = ":TSUpdate",
  config = function()
    local config = require("nvim-treesitter.configs")
    config.setup({
      ensure_installed = {
        "lua",
        "css",
        "go",
        "html",
        "bash",
        "http",
        "javascript",
        "json",
        "jsonc",
        "markdown",
        "markdown_inline",
        "prisma",
        "scss",
        "svelte",
        "tsx",
        "typescript",
        "query",
        "vimdoc",
        "dockerfile",
        "yaml"
      },
      highlight = {
        enable = true
      },
      indent = {
        enable = true
      }
    })
  end
}
