local fs = require("udir.fs")
local store = require("udir.store")
local u = require("udir.util")
local api = vim.api
local uv = vim.loop
local M = {}
M["keymap"] = {cd = "<Cmd>lua require'udir'.cd()<CR>", copy = "<Cmd>lua require'udir'.copy()<CR>", create = "<Cmd>lua require'udir'.create()<CR>", delete = "<Cmd>lua require'udir'.delete()<CR>", move = "<Cmd>lua require'udir'.move()<CR>", open = "<Cmd>lua require'udir'.open()<CR>", open_split = "<Cmd>lua require'udir'.open('split')<CR>", open_tab = "<Cmd>lua require'udir'.open('tabedit')<CR>", open_vsplit = "<Cmd>lua require'udir'.open('vsplit')<CR>", quit = "<Cmd>lua require'udir'.quit()<CR>", reload = "<Cmd>lua require'udir'.reload()<CR>", toggle_hidden_files = "<Cmd>lua require'udir'[\"toggle-hidden-files\"]()<CR>", up_dir = "<Cmd>lua require'udir'[\"up-dir\"]()<CR>"}
local config
local function _1_()
  return false
end
config = {["is-file-hidden"] = _1_, ["show-hidden-files"] = true, keymaps = {C = M.keymap.cd, R = M.keymap.reload, ["+"] = M.keymap.create, ["-"] = M.keymap.up_dir, ["<CR>"] = M.keymap.open, c = M.keymap.copy, d = M.keymap.delete, gh = M.keymap.toggle_hidden_files, h = M.keymap.up_dir, l = M.keymap.open, m = M.keymap.move, q = M.keymap.quit, r = M.keymap.move, s = M.keymap.open_split, t = M.keymap.open_tab, v = M.keymap.open_vsplit}}
M.setup = function(cfg)
  local cfg0 = (cfg or {})
  if cfg0["auto-open"] then
    vim.cmd("aug udir")
    vim.cmd("au!")
    vim.cmd("au BufEnter * if !empty(expand('%')) && isdirectory(expand('%')) && !get(b:, 'is_udir') | Udir | endif")
    vim.cmd("aug END")
  end
  if cfg0.keymaps then
    config["keymaps"] = cfg0.keymaps
  end
  if (nil ~= cfg0["show-hidden-files"]) then
    config["show-hidden-files"] = cfg0["show-hidden-files"]
  end
  if cfg0["is-file-hidden"] then
    config["is-file-hidden"] = cfg0["is-file-hidden"]
    return nil
  end
end
local function sort_in_place(files)
  assert((nil ~= files), string.format("Missing argument %s on %s:%s", "files", "lua/udir.fnl", 66))
  local function _6_(_241, _242)
    if (_241.type == _242.type) then
      return (_241.name < _242.name)
    elseif "else" then
      return (_241.type == "directory")
    end
  end
  table.sort(files, _6_)
  return nil
end
local function render_virttext(ns, files)
  assert((nil ~= files), string.format("Missing argument %s on %s:%s", "files", "lua/udir.fnl", 71))
  assert((nil ~= ns), string.format("Missing argument %s on %s:%s", "ns", "lua/udir.fnl", 71))
  api.nvim_buf_clear_namespace(0, ns, 0, -1)
  for i, file in ipairs(files) do
    local virttext, hl = nil, nil
    do
      local _8_ = file.type
      if (_8_ == "directory") then
        virttext, hl = u.sep, "Directory"
      elseif (_8_ == "link") then
        virttext, hl = "@", "Constant"
      else
      virttext, hl = nil
      end
    end
    if virttext then
      api.nvim_buf_set_extmark(0, ns, (i - 1), #file.name, {virt_text = {{virttext, "Comment"}}, virt_text_pos = "overlay"})
      api.nvim_buf_set_extmark(0, ns, (i - 1), 0, {end_col = #file.name, hl_group = hl})
    end
  end
  return nil
end
local function render(state)
  assert((nil ~= state), string.format("Missing argument %s on %s:%s", "state", "lua/udir.fnl", 85))
  local _let_11_ = state
  local buf = _let_11_["buf"]
  local cwd = _let_11_["cwd"]
  local files = fs.list(cwd)
  local files0
  if config["show-hidden-files"] then
    files0 = files
  elseif "else" then
    local function _12_(_241)
      return not config["is-file-hidden"](_241, cwd)
    end
    files0 = vim.tbl_filter(_12_, files)
  else
  files0 = nil
  end
  local _ = sort_in_place(files0)
  local filenames
  local function _14_(_241)
    return _241.name
  end
  filenames = vim.tbl_map(_14_, files0)
  u["set-lines"](buf, 0, -1, false, filenames)
  return render_virttext(state.ns, files0)
end
local function noremap(mode, buf, mappings)
  assert((nil ~= mappings), string.format("Missing argument %s on %s:%s", "mappings", "lua/udir.fnl", 100))
  assert((nil ~= buf), string.format("Missing argument %s on %s:%s", "buf", "lua/udir.fnl", 100))
  assert((nil ~= mode), string.format("Missing argument %s on %s:%s", "mode", "lua/udir.fnl", 100))
  for lhs, rhs in pairs(mappings) do
    api.nvim_buf_set_keymap(buf, mode, lhs, rhs, {noremap = true, nowait = true, silent = true})
  end
  return nil
end
local function setup_keymaps(buf)
  assert((nil ~= buf), string.format("Missing argument %s on %s:%s", "buf", "lua/udir.fnl", 105))
  return noremap("n", buf, config.keymaps)
end
local function cleanup(state)
  assert((nil ~= state), string.format("Missing argument %s on %s:%s", "state", "lua/udir.fnl", 108))
  api.nvim_buf_delete(state.buf, {force = true})
  return store.remove(state.buf)
end
local function update_cwd(state, path)
  assert((nil ~= path), string.format("Missing argument %s on %s:%s", "path", "lua/udir.fnl", 112))
  assert((nil ~= state), string.format("Missing argument %s on %s:%s", "state", "lua/udir.fnl", 112))
  do end (state)["cwd"] = path
  return nil
end
M.quit = function()
  local state = store.get()
  local _let_15_ = state
  local alt_buf = _let_15_["alt-buf"]
  local origin_buf = _let_15_["origin-buf"]
  if alt_buf then
    u["set-current-buf"](alt_buf)
  end
  u["set-current-buf"](origin_buf)
  cleanup(state)
  return nil
end
M["up-dir"] = function()
  do
    local state = store.get()
    local cwd = state.cwd
    local parent_dir = fs["get-parent-dir"](state.cwd)
    local hovered_filename = u["get-line"]()
    if hovered_filename then
      state["hovered-filenames"][state.cwd] = hovered_filename
    end
    update_cwd(state, parent_dir)
    render(state)
    u["update-statusline"](state.cwd)
    u["set-cursor-pos"](fs.basename(cwd), "or-top")
  end
  return nil
end
M.open = function(cmd)
  local state = store.get()
  local filename = u["get-line"]()
  if ("" ~= filename) then
    local path = u["join-path"](state.cwd, filename)
    local realpath = fs.canonicalize(path)
    fs["assert-readable"](path)
    if fs["is-dir?"](path) then
      if cmd then
        return vim.cmd((cmd .. " " .. vim.fn.fnameescape(realpath)))
      elseif "else" then
        update_cwd(state, realpath)
        render(state)
        local hovered_file = (state["hovered-filenames"])[realpath]
        u["update-statusline"](state.cwd)
        return u["set-cursor-pos"](hovered_file, "or-top")
      end
    elseif "else" then
      u["set-current-buf"](state["origin-buf"])
      vim.cmd(((cmd or "edit") .. " " .. vim.fn.fnameescape(realpath)))
      return cleanup(state)
    end
  end
end
M.reload = function()
  local state = store.get()
  return render(state)
end
M.delete = function()
  local state = store.get()
  local filename = u["get-line"]()
  if ("" == filename) then
    return u.err("Empty filename")
  elseif "else" then
    local path = u["join-path"](state.cwd, filename)
    local _ = print(string.format("Are you sure you want to delete %q? (y/n)", path))
    local input = vim.fn.getchar()
    local confirmed_3f = (vim.fn.nr2char(input) == "y")
    if confirmed_3f then
      fs.delete(path)
      render(state)
    end
    return u["clear-prompt"]()
  end
end
local function copy_or_move(move_3f, prompt)
  local state = store.get()
  local filename = u["get-line"]()
  if ("" == filename) then
    return u.err("Empty filename")
  elseif "else" then
    local src = u["join-path"](state.cwd, filename)
    local name = vim.fn.input(prompt)
    if ("" ~= name) then
      local dest = u["join-path"](state.cwd, name)
      fs["copy-or-move"](move_3f, src, dest)
      render(state)
      u["clear-prompt"]()
      return u["set-cursor-pos"](fs.basename(dest))
    end
  end
end
M.move = function()
  return copy_or_move(true, "Move to: ")
end
M.copy = function()
  return copy_or_move(false, "Copy to: ")
end
M.create = function()
  local state = store.get()
  local name = vim.fn.input("New file: ")
  if (name ~= "") then
    local path = u["join-path"](state.cwd, name)
    if vim.endswith(name, u.sep) then
      fs["create-dir"](path)
    elseif "else" then
      fs["create-file"](path)
    end
    render(state)
    u["clear-prompt"]()
    return u["set-cursor-pos"](fs.basename(path))
  end
end
M["toggle-hidden-files"] = function()
  local state = store.get()
  local hovered_filename = u["get-line"]()
  config["show-hidden-files"] = not config["show-hidden-files"]
  render(state)
  return u["set-cursor-pos"](fs.basename(hovered_filename))
end
M.cd = function()
  local _let_27_ = store.get()
  local cwd = _let_27_["cwd"]
  vim.cmd(("cd " .. vim.fn.fnameescape(cwd)))
  return vim.cmd("pwd")
end
M.udir = function()
  local origin_buf = api.nvim_get_current_buf()
  local alt_buf
  do
    local n = vim.fn.bufnr("#")
    if (n == -1) then
      alt_buf = nil
    else
      alt_buf = n
    end
  end
  local cwd
  do
    local p = vim.fn.expand("%:p:h")
    if ("" ~= p) then
      cwd = fs.canonicalize(p)
    else
      cwd = nil
    end
  end
  local origin_filename
  do
    local p = vim.fn.expand("%")
    if ("" ~= p) then
      origin_filename = fs.basename(fs.canonicalize(p))
    else
      origin_filename = nil
    end
  end
  local win = vim.fn.win_getid()
  local buf = assert(u["find-or-create-buf"](cwd, win))
  local ns = api.nvim_create_namespace(("udir." .. buf))
  local hovered_filenames = {}
  local state = {["alt-buf"] = alt_buf, ["hovered-filenames"] = hovered_filenames, ["origin-buf"] = origin_buf, buf = buf, cwd = cwd, ns = ns, win = win}
  setup_keymaps(buf)
  store["set!"](buf, state)
  render(state)
  return u["set-cursor-pos"](origin_filename)
end
return M
