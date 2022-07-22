# telescope-hoogle.nvim

`telescope-hoogle` is an extension for [telescope.nvim][] that provides its users with option to browse  [ndmitchell/hoogle][] database.

[telescope.nvim]: https://github.com/nvim-telescope/telescope.nvim
[ndmitchell/hoogle]: https://github.com/ndmitchell/hoogle

## Installation and Configuration

```lua
-- These are the default options.
require("telescope").setup {
  extensions = {
    hoogle = {
      render = 'default',       -- Select the preview render engine: default|treesitter
                                -- default = simple approach to render the document
                                -- treesitter = render the document by utilizing treesitter's html parser
      renders = {               -- Render specific options
        treesitter = {
          remove_wrap = false   -- Remove hoogle's own text wrapping. E.g. if you uses neovim's buffer wrapping
                                -- (autocmd User TelescopePreviewerLoaded setlocal wrap)
        }
      }
    }
  },
}

require'telescope'.load_extension'hoogle'
```

## Requirements

Local installation of hoogle available on the path.

### Optional requirements

* [tree-sitter-html](https://github.com/tree-sitter/tree-sitter-html) - required by the treesitter preview render. The easiest method to install is to use [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) plugin.

## Usage

Now supports `hoogle list` only.


### list

`:Telescope hoogle list`

Runnnin `hoogle list` will display propmp window and once more than 3 chars are inserterd you will be presented with result from hoogle.

#### options

#### `bin`

Filepath for the binary `hoogle`.

```vim
" path can be expanded
:Telescope hoogle list bin=~/hoogle
```
