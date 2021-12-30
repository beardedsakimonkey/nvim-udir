local fs = require("qdir.fs")
local store = require("qdir.store")
local u = require("qdir.util")
local api = vim.api
local uv = vim.loop
local M = {}
local function sort_in_place(files)
  assert((nil ~= files), string.format("Missing argument %s on %s:%s", "files", "lua/qdir.fnl", 13))
  local function _1_(_241, _242)
    if (_241.type == _242.type) then
      return (_241.name < _242.name)
    elseif "else" then
      return (_241.type == "directory")
    end
  end
  table.sort(files, _1_)
  return nil
end
local function render_virttext(ns, files)
  assert((nil ~= files), string.format("Missing argument %s on %s:%s", "files", "lua/qdir.fnl", 18))
  assert((nil ~= ns), string.format("Missing argument %s on %s:%s", "ns", "lua/qdir.fnl", 18))
  api.nvim_buf_clear_namespace(0, ns, 0, -1)
  for i, file in ipairs(files) do
    local virttext, hl = nil, nil
    do
      local _3_ = file.type
      if (_3_ == "directory") then
        virttext, hl = u.sep, "Directory"
      elseif (_3_ == "link") then
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
  assert((nil ~= state), string.format("Missing argument %s on %s:%s", "state", "lua/qdir.fnl", 32))
  local _let_6_ = state
  local buf = _let_6_["buf"]
  local cwd = _let_6_["cwd"]
  local files = fs.list(cwd)
  local _ = sort_in_place(files)
  local filenames
  local function _7_(_241)
    return _241.name
  end
  filenames = vim.tbl_map(_7_, files)
  u["set-lines"](buf, 0, -1, false, filenames)
  return render_virttext(state.ns, files)
end
local function noremap(mode, buf, mappings)
  assert((nil ~= mappings), string.format("Missing argument %s on %s:%s", "mappings", "lua/qdir.fnl", 45))
  assert((nil ~= buf), string.format("Missing argument %s on %s:%s", "buf", "lua/qdir.fnl", 45))
  assert((nil ~= mode), string.format("Missing argument %s on %s:%s", "mode", "lua/qdir.fnl", 45))
  for lhs, rhs in pairs(mappings) do
    api.nvim_buf_set_keymap(buf, mode, lhs, rhs, {noremap = true, nowait = true, silent = true})
  end
  return nil
end
local function setup_keymaps(buf)
  assert((nil ~= buf), string.format("Missing argument %s on %s:%s", "buf", "lua/qdir.fnl", 50))
  return noremap("n", buf, {R = "<Cmd>lua require'qdir'.reload()<CR>", ["+"] = "<Cmd>lua require'qdir'.create()<CR>", ["-"] = "<Cmd>lua require'qdir'[\"up-dir\"]()<CR>", ["<CR>"] = "<Cmd>lua require'qdir'.open()<CR>", c = "<Cmd>lua require'qdir'.copy()<CR>", d = "<Cmd>lua require'qdir'.delete()<CR>", h = "<Cmd>lua require'qdir'[\"up-dir\"]()<CR>", l = "<Cmd>lua require'qdir'.open()<CR>", m = "<Cmd>lua require'qdir'.rename()<CR>", q = "<Cmd>lua require'qdir'.quit()<CR>", r = "<Cmd>lua require'qdir'.rename()<CR>", s = "<Cmd>lua require'qdir'.open('split')<CR>", t = "<Cmd>lua require'qdir'.open('tabedit')<CR>", v = "<Cmd>lua require'qdir'.open('vsplit')<CR>"})
end
local function cleanup(state)
  assert((nil ~= state), string.format("Missing argument %s on %s:%s", "state", "lua/qdir.fnl", 66))
  api.nvim_buf_delete(state.buf, {force = true})
  do end (state.event):stop()
  return store.remove(state.buf)
end
local function on_fs_event(err, filename, _events)
  assert(not err)
  local state = store.get()
  return render(state)
end
local function update_cwd(state, path)
  assert((nil ~= path), string.format("Missing argument %s on %s:%s", "path", "lua/qdir.fnl", 79))
  assert((nil ~= state), string.format("Missing argument %s on %s:%s", "state", "lua/qdir.fnl", 79))
  do end (state)["cwd"] = path
  assert((state.event):stop())
  assert((state.event):start(path, {}, vim.schedule_wrap(on_fs_event)))
  return nil
end
M.quit = function()
  local state = store.get()
  local _let_8_ = state
  local alt_buf = _let_8_["alt-buf"]
  local origin_buf = _let_8_["origin-buf"]
  if alt_buf then
    u["set-current-buf"](alt_buf)
  end
  u["set-current-buf"](origin_buf)
  vim.opt_local.modifiable = true
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
    u["set-cursor-pos"](fs.basename(cwd))
  end
  return nil
end
M.open = function(cmd)
  local state = store.get()
  local filename = u["get-line"]()
  if (filename == "") then
    return u.err("Empty filename")
  elseif "else" then
    local path = u["join-path"](state.cwd, filename)
    local realpath = fs.canonicalize(path)
    if fs["is-dir?"](path) then
      if cmd then
        return vim.cmd((cmd .. " " .. vim.fn.fnameescape(realpath)))
      elseif "else" then
        update_cwd(state, realpath)
        render(state)
        local hovered_file = (state["hovered-filenames"])[realpath]
        u["update-statusline"](state.cwd)
        return u["set-cursor-pos"](hovered_file)
      end
    elseif "else" then
      u["set-current-buf"](state["origin-buf"])
      vim.cmd(((cmd or "edit") .. " " .. vim.fn.fnameescape(realpath)))
      vim.opt_local.modifiable = true
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
  if (filename == "") then
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
local function copy_or_rename(operation, prompt)
  local state = store.get()
  local filename = u["get-line"]()
  if (filename == "") then
    return u.err("Empty filename")
  elseif "else" then
    local path = u["join-path"](state.cwd, filename)
    local name = vim.fn.input(prompt)
    if (name ~= "") then
      local newpath = u["join-path"](state.cwd, name)
      operation(path, newpath)
      render(state)
      u["clear-prompt"]()
      return u["set-cursor-pos"](fs.basename(newpath))
    end
  end
end
M.rename = function()
  return copy_or_rename(fs.rename, "New name: ")
end
M.copy = function()
  return copy_or_rename(fs.copy, "Copy to: ")
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
M.init = function(cfg)
  local cfg0 = (cfg or {})
  if cfg0["auto-open"] then
    vim.cmd("aug qdir")
    vim.cmd("au!")
    vim.cmd("au BufEnter * if !empty(expand('%')) && isdirectory(expand('%')) && !get(b:, 'is_qdir') | Qdir | endif")
    return vim.cmd("aug END")
  end
end
M.qdir = function()
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
    if (p ~= "") then
      cwd = fs.canonicalize(p)
    else
      cwd = nil
    end
  end
  local origin_filename
  do
    local p = vim.fn.expand("%")
    if (p ~= "") then
      origin_filename = fs.basename(fs.canonicalize(p))
    else
      origin_filename = nil
    end
  end
  local win = vim.fn.win_getid()
  local buf = assert(u["find-or-create-buf"](cwd, win))
  local ns = api.nvim_create_namespace(("qdir." .. buf))
  local hovered_filenames = {}
  local event = assert(uv.new_fs_event())
  local state = {["alt-buf"] = alt_buf, ["hovered-filenames"] = hovered_filenames, ["origin-buf"] = origin_buf, buf = buf, cwd = cwd, event = event, ns = ns, win = win}
  setup_keymaps(buf)
  store["set!"](buf, state)
  render(state)
  u["set-cursor-pos"](origin_filename)
  return event:start(cwd, {}, vim.schedule_wrap(on_fs_event))
end
return M
