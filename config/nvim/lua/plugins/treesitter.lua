return {
    {
      "nvim-treesitter/nvim-treesitter",
      build = ":TSUpdate",
      config = function()
        local config = require("nvim-treesitter.configs")
        config.setup({
          ensure_installed = {"lua" , "javascript", "c", "vim", "vimdoc", "markdown", "c_sharp", "cmake", "cpp", "go", "json", "python", "java"},
          auto_install = true,
          highlight = { enable = true },
          indent = { enable = true },
        })
      end
    }
  }