return {
  "nvim-treesitter/nvim-treesitter",
  branch = 'master',
  lazy = false,
  build = ":TSUpdate",
  config = function()
    local configs = require("nvim-treesitter.configs")
    configs.setup({
      ensure_installed = {
        "bash", "lua", "vim", "json", "yaml", "markdown", "markdown_inline",
        "javascript", "typescript", "tsx", "html", "css", "scss",
        "sql", "dockerfile",
        "gitignore", "regex"
      },
      highlight = { enabled = true },
      indent = { enabled = true },
    })
  end
}
