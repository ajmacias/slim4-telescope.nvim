# slim4-telescope.nvim
Ugly and dirty plugin for better handling of Slim Framework.

## Requirements
* Treesitter
* Telescope
* `fd` to look for files

## Configuration

```lua
return {
  "ajmacias/slim4-telescope.nvim",
  dependencies = {
    "nvim-telescope/telescope.nvim",
    "nvim-treesitter/nvim-treesitter",
  },
  config = function()
    require('slim4-telescope').setup()
  end,
  keys = {
    {
      "<leader>sr", ":Slim4routes<CR>", { desc = "Slim4 routes", opts = { silent = true } }
    },
    {
      "<leader>sm", ":Slim4models<CR>", { desc = "Slim4 models", opts = { silent = true } }
    },
    {
      "<leader>st", ":Slim4views<CR>", { desc = "Slim4 views (twig)", opts = { silent = true } }
    },
  }
}
```

### To-do / known issues
- [ ] Lot of stuff!!!

