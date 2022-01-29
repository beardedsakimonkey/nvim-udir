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
config = {["is-file-hidden"] = _1_, ["show-hidden-files"] = true, keymaps = {C = M.keymap.cd, R = M.keymap.reload, ["+"] = M.keymap.create, ["-"] = M.keymap.up_dir, ["."] = M.keymap.toggle_hidden_files, ["<CR>"] = M.keymap.open, c = M.keymap.copy, d = M.keymap.delete, h = M.keymap.up_dir, l = M.keymap.open, m = M.keymap.move, q = M.keymap.quit, r = M.keymap.move, s = M.keymap.open_split, t = M.keymap.open_tab, v = M.keymap.open_vsplit}}
M.setup = function(_3fcfg)
  local cfg = (_3fcfg or {})
  if cfg["auto-open"] then
    vim.cmd("aug udir")
    vim.cmd("au!")
    vim.cmd("au BufEnter * if !empty(expand('%')) && isdirectory(expand('%')) && !get(b:, 'is_udir') | Udir | endif")
    vim.cmd("aug END")
  end
  if cfg.keymaps then
    config["keymaps"] = cfg.keymaps
  end
  if (nil ~= cfg["show-hidden-files"]) then
    config["show-hidden-files"] = cfg["show-hidden-files"]
  end
  if cfg["is-file-hidden"] then
    config["is-file-hidden"] = cfg["is-file-hidden"]
    return nil
  end
end
local function sort_21(files)
  assert((nil ~= files), string.format("Missing argument %s on %s:%s", "files", "lua/udir.fnl", 66))
  local function _6_(_241, _242)
    if (_241.type == _242.type) then
      return (_241.name < _242.name)
    else
      return ("directory" == _241.type)
    end
  end
  table.sort(files, _6_)
  return files
end
local function render_virttext(ns, files)
  assert((nil ~= files), string.format("Missing argument %s on %s:%s", "files", "lua/udir.fnl", 72))
  assert((nil ~= ns), string.format("Missing argument %s on %s:%s", "ns", "lua/udir.fnl", 72))
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
  assert((nil ~= state), string.format("Missing argument %s on %s:%s", "state", "lua/udir.fnl", 86))
  local _local_11_ = state
  local buf = _local_11_["buf"]
  local cwd = _local_11_["cwd"]
  local files
  local function _12_(_241)
    if config["show-hidden-files"] then
      return not config["is-file-hidden"](_241, cwd)
    else
      return true
    end
  end
  files = sort_21(vim.tbl_filter(_12_, fs.list(cwd)))
  local filenames
  local function _14_(_241)
    return _241.name
  end
  filenames = vim.tbl_map(_14_, files)
  u["set-lines"](buf, 0, -1, false, filenames)
  return render_virttext(state.ns, files)
end
local function noremap(mode, buf, mappings)
  assert((nil ~= mappings), string.format("Missing argument %s on %s:%s", "mappings", "lua/udir.fnl", 101))
  assert((nil ~= buf), string.format("Missing argument %s on %s:%s", "buf", "lua/udir.fnl", 101))
  assert((nil ~= mode), string.format("Missing argument %s on %s:%s", "mode", "lua/udir.fnl", 101))
  for lhs, rhs in pairs(mappings) do
    api.nvim_buf_set_keymap(buf, mode, lhs, rhs, {noremap = true, nowait = true, silent = true})
  end
  return nil
end
local function setup_keymaps(buf)
  assert((nil ~= buf), string.format("Missing argument %s on %s:%s", "buf", "lua/udir.fnl", 106))
  return noremap("n", buf, config.keymaps)
end
local function cleanup(state)
  assert((nil ~= state), string.format("Missing argument %s on %s:%s", "state", "lua/udir.fnl", 109))
  api.nvim_buf_delete(state.buf, {force = true})
  store["remove!"](state.buf)
  return nil
end
local function update_cwd(state, path)
  assert((nil ~= path), string.format("Missing argument %s on %s:%s", "path", "lua/udir.fnl", 114))
  assert((nil ~= state), string.format("Missing argument %s on %s:%s", "state", "lua/udir.fnl", 114))
  do end (state)["cwd"] = path
  return nil
end
M.quit = function()
  local state = store.get()
  local _local_15_ = state
  local _3falt_buf = _local_15_["?alt-buf"]
  local origin_buf = _local_15_["origin-buf"]
  if _3falt_buf then
    u["set-current-buf"](_3falt_buf)
  end
  u["set-current-buf"](origin_buf)
  return cleanup(state)
end
M["up-dir"] = function()
  local state = store.get()
  local cwd = state.cwd
  local parent_dir = fs["get-parent-dir"](state.cwd)
  local _3fhovered_file = u["get-line"]()
  if _3fhovered_file then
    state["hovered-files"][state.cwd] = _3fhovered_file
  end
  update_cwd(state, parent_dir)
  render(state)
  u["update-buf-name"](state.buf, state.cwd)
  return u["set-cursor-pos"](fs.basename(cwd), "or-top")
end
M.open = function(_3fcmd)
  local state = store.get()
  local filename = u["get-line"]()
  if ("" ~= filename) then
    local path = u["join-path"](state.cwd, filename)
    local realpath = fs.canonicalize(path)
    fs["assert-readable"](path)
    if fs["dir?"](path) then
      if _3fcmd then
        return vim.cmd((_3fcmd .. " " .. vim.fn.fnameescape(realpath)))
      else
        update_cwd(state, realpath)
        render(state)
        u["update-buf-name"](state.buf, state.cwd)
        local _3fhovered_file = (state["hovered-files"])[realpath]
        return u["set-cursor-pos"](_3fhovered_file, "or-top")
      end
    else
      u["set-current-buf"](state["origin-buf"])
      vim.cmd(((_3fcmd or "edit") .. " " .. vim.fn.fnameescape(realpath)))
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
  else
    local path = u["join-path"](state.cwd, filename)
    local _ = print(string.format("Are you sure you want to delete %q? (y/n)", path))
    local input = vim.fn.getchar()
    local confirmed_3f = ("y" == vim.fn.nr2char(input))
    if confirmed_3f then
      fs.delete(path)
      render(state)
    end
    return u["clear-prompt"]()
  end
end
local function copy_or_move(should_move)
  assert((nil ~= should_move), string.format("Missing argument %s on %s:%s", "should-move", "lua/udir.fnl", 180))
  local state = store.get()
  local filename = u["get-line"]()
  if ("" == filename) then
    return u.err("Empty filename")
  else
    local src = u["join-path"](state.cwd, filename)
    local prompt
    if should_move then
      prompt = "Move to:"
    else
      prompt = "Copy to:"
    end
    local name = vim.fn.input(prompt)
    if ("" ~= name) then
      local dest = u["join-path"](state.cwd, name)
      fs["copy-or-move"](should_move, src, dest)
      render(state)
      u["clear-prompt"]()
      return u["set-cursor-pos"](fs.basename(dest))
    end
  end
end
M.move = function()
  return copy_or_move(true)
end
M.copy = function()
  return copy_or_move(false)
end
M.create = function()
  local state = store.get()
  local name = vim.fn.input("New file: ")
  if (name ~= "") then
    local path = u["join-path"](state.cwd, name)
    if vim.endswith(name, u.sep) then
      fs["create-dir"](path)
    else
      fs["create-file"](path)
    end
    render(state)
    u["clear-prompt"]()
    return u["set-cursor-pos"](fs.basename(path))
  end
end
M["toggle-hidden-files"] = function()
  local state = store.get()
  local _3fhovered_file = u["get-line"]()
  config["show-hidden-files"] = not config["show-hidden-files"]
  render(state)
  return u["set-cursor-pos"](_3fhovered_file)
end
M.cd = function()
  local _local_28_ = store.get()
  local cwd = _local_28_["cwd"]
  vim.cmd(("cd " .. vim.fn.fnameescape(cwd)))
  return vim.cmd("pwd")
end
M.udir = function()
  local origin_buf = assert(api.nvim_get_current_buf())
  local _3falt_buf
  do
    local n = vim.fn.bufnr("#")
    if (n == -1) then
      _3falt_buf = nil
    else
      _3falt_buf = n
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
  local _3forigin_filename
  do
    local p = vim.fn.expand("%:p:t")
    if ("" == p) then
      _3forigin_filename = nil
    else
      _3forigin_filename = p
    end
  end
  local buf = assert(u["find-or-create-buf"](cwd))
  local ns = api.nvim_create_namespace(("udir." .. buf))
  local hovered_files = {}
  local state = {["?alt-buf"] = _3falt_buf, ["hovered-files"] = hovered_files, ["origin-buf"] = origin_buf, buf = buf, cwd = cwd, ns = ns}
  setup_keymaps(buf)
  store["set!"](buf, state)
  render(state)
  return u["set-cursor-pos"](_3forigin_filename)
end
return M
