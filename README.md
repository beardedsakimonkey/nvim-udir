# Udir

Udir is a small (~500 sloc) directory viewer for neovim (>= 0.12). Similar to
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

In a udir buffer, `l`/`<CR>` navigates into a directory. Press `o` on a
directory to expand it inline using a tree-style view, and press `o` again on
that directory to expand one more level of subdirectories. Press `O` to expand
all nested subdirectories recursively. Press `u` on an expanded directory to
collapse only that directory; previously expanded descendants are remembered and
restored when the directory is expanded again. Press `U` to collapse a directory
and forget its expanded descendant state. Press `J` or `K` to jump to the next
or previous visible directory row. Press `H` to show keymap help.
Press `gx` to open the currently hovered path with `vim.ui.open()`.
Press `i` to show file metadata for the current row in a floating window.
Use `<Tab>` to toggle a mark on the current row, or select multiple rows in
visual mode and press `<Tab>` to toggle marks for every selected row. Press
`<S-Tab>` to clear all marks.


## Configuration

Udir does not require any configuration, but can be configured by mutating `udir.config`.
The defaults are listed below.
```lua
---@alias File {name: string, type: 'file'|'directory'|'link'}
require'udir'.config = {
    keymaps = {
        q = {"<Cmd>lua require'udir.core'.quit()<CR>", desc="Quit"},
        h = {"<Cmd>lua require'udir.core'.up_dir()<CR>", desc="Up directory"},
        ['-'] = {"<Cmd>lua require'udir.core'.up_dir()<CR>", desc="Up directory"},
        J = {"<Cmd>lua require'udir.core'.next_directory()<CR>", desc="Next directory"},
        K = {"<Cmd>lua require'udir.core'.prev_directory()<CR>", desc="Previous directory"},
        o = {"<Cmd>lua require'udir.core'.expand()<CR>", desc="Expand"},
        O = {"<Cmd>lua require'udir.core'.expand_recursive()<CR>", desc="Expand recursively"},
        u = {"<Cmd>lua require'udir.core'.collapse()<CR>", desc="Collapse"},
        U = {"<Cmd>lua require'udir.core'.collapse_reset()<CR>", desc="Collapse and reset"},
        l = {"<Cmd>lua require'udir.core'.open()<CR>", desc="Open"},
        ['<CR>'] = {"<Cmd>lua require'udir.core'.open()<CR>", desc="Open"},
        s = {"<Cmd>lua require'udir.core'.open('split')<CR>", desc="Open in split"},
        v = {"<Cmd>lua require'udir.core'.open('vsplit')<CR>", desc="Open in vertical split"},
        t = {"<Cmd>lua require'udir.core'.open('tabedit')<CR>", desc="Open in tab"},
        gx = {"<Cmd>lua require'udir.core'.open_external()<CR>", desc="Open externally"},
        R = {"<Cmd>lua require'udir.core'.reload()<CR>", desc="Reload"},
        i = {"<Cmd>lua require'udir.core'.info()<CR>", desc="Show info"},
        d = {"<Cmd>lua require'udir.core'.delete()<CR>", desc="Delete"},
        ['+'] = {"<Cmd>lua require'udir.core'.create()<CR>", desc="Create"},
        m = {"<Cmd>lua require'udir.core'.move()<CR>", desc="Move"},
        c = {"<Cmd>lua require'udir.core'.copy()<CR>", desc="Copy"},
        ['<Tab>'] = {"<Cmd>lua require'udir.core'.toggle_mark()<CR>", desc="Toggle mark"},
        ['<S-Tab>'] = {"<Cmd>lua require'udir.core'.clear_marks()<CR>", desc="Clear marks"},
        ['.'] = {"<Cmd>lua require'udir.core'.toggle_hidden_files()<CR>", desc="Toggle hidden files"},
        H = {"<Cmd>lua require'udir.core'.help()<CR>", desc="Show help"},
    },
    visual_keymaps = {
        ['<Tab>'] = {"<Cmd>lua require'udir.core'.toggle_mark_visual()<CR>", desc="Toggle marks"},
    },
    -- Whether hidden files should be shown by default
    show_hidden_files = true,
    -- Whether to sync the window's current directory with udir's current path
    sync_local_cwd = false,
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
        e = "<Cmd>lua require'udir.core'.open()<CR>",
        C = function() --[[...]] end,  -- keymaps can also be lua functions
    },
})

-- or...

udir.config.show_hidden_files = false
udir.config.keymaps.e = "<Cmd>lua require'udir.core'.open()<CR>"
```

Keymaps may also be provided as plain strings or functions. Use the table form
when you want to attach a description:
```lua
udir.config.keymaps.q = {"<Cmd>lua require'udir.core'.quit()<CR>", desc="Quit"}
```

You can also customize the colors in udir using the following highlight groups:
```
UdirDirectory
UdirSymlink
UdirExecutable
UdirTree
UdirVirtText
UdirPromptBorder
UdirPromptBorderValid
UdirPromptBorderInvalid
UdirPromptCompletion
UdirDeletePath
UdirDeleteMore
UdirDeleteCursor
UdirMarkedText
UdirMarkedSign
UdirMarkedFile
UdirHelpHeader
UdirHelpKey
UdirHelpDesc
UdirInfoLabel
UdirInfoValue
```

## Smoke test

Run the headless smoke test with:
```sh
sh scripts/smoke.sh
```

## Acknowledgements

Some minor bits of code were adapted from vim-dirvish and nvim-tree.

## Similar plugins

- [vim-vinegar](https://github.com/tpope/vim-vinegar)
- [vim-filebeagle](https://github.com/jeetsukumaran/vim-filebeagle)
- [vim-dirvish](https://github.com/justinmk/vim-dirvish)
- [lir.nvim](https://github.com/tamago324/lir.nvim)
