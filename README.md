# Udir

Udir is a small (~500 sloc) directory viewer for neovim (>= 0.7). Similar to
[vim-dirvish](https://github.com/justinmk/vim-dirvish), udir opens within the
current window and is not meant to be used as a project drawer as found in IDEs.

However, udir differs from vim-dirvish in a few key ways.

1) **Udir does not use modifiable buffers.** I found myself seldom using this
   feature and I prefer the extra keymap availability from not having modifiable
   buffers.

2) **Udir buffers don't populate the jumplist.**  Hitting `<C-o>` typically won't take
   you to a udir buffer. This is partly a matter of personal preference, and dirvish
   opts [against it](https://github.com/justinmk/vim-dirvish/issues/110).

3) **Udir ensures that each instance is isolated.** This means that if you open
   udir to the same directory in two different windows, those buffers are distinct,
   and as such, opening a file or navigating in one won't affect the other.

   To achieve isolation, udir must give each buffer a unique name. Usually, this is
   the directory path, such that commands like `:cd %` work. However, if you have
   multiple loaded udir buffers on the same directory, the buffer names will be made
   unique by appending an id like "[2]" to the name (in which case `:cd %` won't work).

   Admittedly, this is a hack; vim buffers are intended to have a 1-to-1 mapping
   with files. When naming a buffer with something that looks like a path, vim
   internally canonicalizes the name in order to avoid having multiple buffers
   correspond to the same file. However, this approach avoids surprising and
   inconvenient behavior that occurs when windows share the same buffer.

## Screenshot
<img width="676" alt="Screen Shot 2022-02-12 at 1 19 51 PM" src="https://user-images.githubusercontent.com/54521218/153728813-bcad4cb8-3494-482f-be05-7032f35fed81.png">

## Usage

You can use the `:Udir [dir]` command to open udir, or create your own mapping:
``` lua
vim.keymap.set('n', '-', '<Cmd>Udir<CR>')
```


## Configuration

Udir does not require any configuration, but can be configured by mutating `udir.config`.
The defaults are listed below.
```lua
---@alias File {name: string, type: 'file'|'directory'|'link'}
require'udir'.config = {
    keymaps = {
        q = "<Cmd>lua require'udir.core'.quit()<CR>",
        h = "<Cmd>lua require'udir.core'.up_dir()<CR>",
        ['-'] = "<Cmd>lua require'udir.core'.up_dir()<CR>",
        l = "<Cmd>lua require'udir.core'.open()<CR>",
        ['<CR>'] = "<Cmd>lua require'udir.core'.open()<CR>",
        s = "<Cmd>lua require'udir.core'.open('split')<CR>",
        v = "<Cmd>lua require'udir.core'.open('vsplit')<CR>",
        t = "<Cmd>lua require'udir.core'.open('tabedit')<CR>",
        R = "<Cmd>lua require'udir.core'.reload()<CR>",
        d = "<Cmd>lua require'udir.core'.delete()<CR>",
        ['+'] = "<Cmd>lua require'udir.core'.create()<CR>",
        m = "<Cmd>lua require'udir.core'.move()<CR>",
        c = "<Cmd>lua require'udir.core'.copy()<CR>",
        ['.'] = "<Cmd>lua require'udir.core'.toggle_hidden_files()<CR>",
    },
    -- Whether hidden files should be shown by default
    show_hidden_files = true,
    -- Function used to determine what files should be hidden
    ---@type fun(file: File, files: File[], dir: string): boolean
    is_file_hidden = function() return false end,
    -- Function used to sort files
    ---@type fun(files: File[])
    sort = nil,
}
```

Configuration can be applied by mutating the `config` table:
```lua
local udir = require'udir'

udir.config = vim.tbl_deep_extend('force', udir.config, {
    show_hidden_files = false,
    keymaps = {
        i = "<Cmd>lua require'udir'.open()<CR>",
        C = function() --[[...]] end,  -- keymaps can also be lua functions
    },
})

-- or...

udir.config.show_hidden_files = false
udir.config.keymaps.i = "<Cmd>lua require'udir'.open()<CR>"
```

You can also customize the colors in udir using the following highlight groups:
```
UdirDirectory
UdirSymlink
UdirExecutable
UdirVirtText
```

## Roadmap

Udir is intended to be a small, simple plugin. Future changes are unlikely to
include major feature additions and will probably be limited to bugfixes and
small, quality of life improvements. However, if you have a suggestion for
something, feel free to file an issue.

## Acknowledgements

Some minor bits of code were adapted from vim-dirvish and nvim-tree.

## Similar plugins

- [vim-vinegar](https://github.com/tpope/vim-vinegar)
- [vim-filebeagle](https://github.com/jeetsukumaran/vim-filebeagle)
- [vim-dirvish](https://github.com/justinmk/vim-dirvish)
- [lir.nvim](https://github.com/tamago324/lir.nvim)
