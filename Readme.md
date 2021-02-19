# telescope-hoogle.nvim

`telescope-hoogle` is an extension for [telescope.nvim][] that provides its users with option to browse  [ndmitchell/hoogle][] database.

[telescope.nvim]: https://github.com/nvim-telescope/telescope.nvim
[ndmitchell/hoogle]: https://github.com/ndmitchell/hoogle

## Installation

```lua
require'telescope'.load_extension'hoogle'
```

## Requirements

Local installation of hoogle available on the path.

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
