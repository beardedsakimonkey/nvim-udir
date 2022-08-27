# Udir

Udir is a small (~400 sloc) directory viewer for neovim (>= 0.6). Similar to
[vim-dirvish](https://github.com/justinmk/vim-dirvish), udir opens within the
current window and is not meant to be used as a project drawer as found in IDEs.

However, udir differs from vim-dirvish in a few key ways.

1) **Udir does not use modifiable buffers.** I found myself seldom using this
   feature and I prefer the extra keymap availability from not having modifiable
   buffers.

2) **Udir buffers don't populate the jumplist.**  Hitting `<C-o>` will never take
   you to a udir buffer. This is partly a matter of personal preference, and dirvish
   opts [against it](https://github.com/justinmk/vim-dirvish/issues/110).

3) **Udir ensures that each instance is isolated.** This means that if you open
   udir to the same directory in two different windows, those buffers are distinct,
   and as such, opening a file or navigating in one won't affect the other.
   
   To achieve isolation, udir must give each buffer a unique name. Usually, this is
   the directory path, such that commands like `:cd %` work. However, if you have
   multiple loaded udir buffers on the same directory, the buffer names will be made
   unique by appending an id like "[2]" to the name (in which case `cd %` won't work).
   
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
vim.api.nvim_set_keymap("n", "-", "<Cmd>Udir<CR>", {noremap = true})
```


## Configuration

Udir does not require any configuration, but can be configured by mutating `udir.config`.
The defaults are listed below.

```lua
local udir = require'udir'
local map = udir.map

udir.config = {
	-- Whether to automatically open Udir when editing a directory
	auto_open = true,
	-- Whether hidden files should be shown by default
	show_hidden_files = false,
	-- Function used to determine what files should be hidden
	is_file_hidden = function (file, files, dir) return false end,
	keymaps = {
		q = map.quit,
		h = map.up_dir,
		["-"] = map.up_dir,
		l = map.open,
		["<CR>"] = map.open,
		s = map.open_split,
		v = map.open_vsplit,
		t = map.open_tab,
		R = map.reload,
		d = map.delete,
		["+"] = map.create,
		m = map.move,
		c = map.copy,
		["."] = map.toggle_hidden_files
		-- You can also create your own mapping like so:
		-- C = "<Cmd>lua vim.cmd('lcd ' .. vim.fn.fnameescape(require('udir.store').get().cwd))<Bar>pwd<CR>",
	}
}
```

The `is_file_hidden()` function has the following API:
```typescript
type file = {
	name: string, // The file name
	type: "file" | "directory" | "link" // The file type
}

// A sequential table containing all files in the current directory
type files = list<file>

// The absolute path of the current directory
type dir = string

type is_file_hidden = (file, files, dir) => boolean
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
