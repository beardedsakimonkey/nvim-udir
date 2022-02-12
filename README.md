# Udir

Udir is a small (~400 sloc) directory viewer for neovim (>= 0.6). Similar to
vim-dirvish, udir opens within the current window and is not meant to be used as
a project drawer as found in IDEs.

One notable aspect of udir is that it ensures that each instance is isolated.
This means that if you open udir to the same directory in two different windows,
those buffers are distinct, and as such, opening a file or navigating in one
won't affect the other.

To achieve isolation, udir gives each buffer a unique name. However, whenever
possible, udir will use the directory name as the buffer name so that it can be
used in commands like `:cd %`. Otherwise, it will append an id like "[2]" to the
buffer name.

Admittedly, this is a hack; vim buffers are intended to have a 1-to-1 mapping
with files. When naming a buffer with something that looks like a path, vim
internally canonicalizes the name in order to avoid having multiple buffers
correspond to the same file.

However, this approach avoids surprising and inconvenient behavior that occurs
when windows share the same buffer.

## Configuration

Udir does not require any configuration besides calling `setup()` one time:

```lua
require'udir'.setup()
```

`setup()` optionally takes a config table. The defaults are listed below:
```lua
local map = udir.map

udir.setup({
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
		-- C = "<Cmd>lua vim.cmd('lcd ' .. vim.fn.fnameescape(require('udir.store').get().cwd))<CR>",
	}
})
```

You can use the `:Udir [dir]` command to open udir, or create your own mapping:

``` lua
vim.api.nvim_set_keymap("n", "-", "<Cmd>Udir<CR>", {noremap = true})
```

The `is_file_hidden()` function has the following API:
```tyepscript
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