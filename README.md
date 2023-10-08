<!-- badges: start -->
[![GitHub license](https://badgen.net/github/license/echasnovski/mini.nvim)](https://github.com/echasnovski/mini.nvim/blob/main/LICENSE)
<!-- badges: end -->

### Visualize and work with indent scope

- Customizable debounce delay, animation style, and scope computation options.
- Implements scope-related motions and textobjects.

See more details in [Features](#features) and [help file](doc/indentscope.txt).

## Features

- There are textobjects and motions to operate on scope. Support `v:count` and dot-repeat (in operator pending mode).

## Installation

```lua
{
  "hellupline/indentscope",
  opts = {
    -- Whether to use cursor column when computing reference indent.
    -- Useful to see incremental scopes with horizontal cursor movements.
    indent_at_cursor = true,
  
    -- Whether to first check input line to be a border of adjacent scope.
    -- Use it if you want to place cursor on function header to get scope of
    -- its body.
    try_as_border = false,
  
    -- Type of scope's border: which line(s) with smaller indent to
    -- categorize as border. Can be one of: 'both', 'top', 'bottom', 'none'.
    border = 'both',
  },
}
```

**Important**: don't forget to call `require('indentscope').setup()` to enable its functionality.

**Note**: if you are on Windows, there might be problems with too long file paths (like `error: unable to create file <some file name>: Filename too long`). Try doing one of the following:
- Enable corresponding git global config value: `git config --system core.longpaths true`. Then try to reinstall.
- Install plugin in other place with shorter path.
