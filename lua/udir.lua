local fs = require("udir.fs")
local store = require("udir.store")
local u = require("udir.util")
local api = vim.api
local uv = vim.loop
local M = {}
M["map"] = {quit = "<Cmd>lua require'udir'.quit()<CR>", up_dir = "<Cmd>lua require'udir'[\"up-dir\"]()<CR>", open = "<Cmd>lua require'udir'.open()<CR>", open_split = "<Cmd>lua require'udir'.open('split')<CR>", open_vsplit = "<Cmd>lua require'udir'.open('vsplit')<CR>", open_tab = "<Cmd>lua require'udir'.open('tabedit')<CR>", reload = "<Cmd>lua require'udir'.reload()<CR>", delete = "<Cmd>lua require'udir'.delete()<CR>", create = "<Cmd>lua require'udir'.create()<CR>", move = "<Cmd>lua require'udir'.move()<CR>", copy = "<Cmd>lua require'udir'.copy()<CR>", toggle_hidden_files = "<Cmd>lua require'udir'[\"toggle-hidden-files\"]()<CR>"}
local config
local function _1_()
  return false
end
config = {keymaps = {q = M.map.quit, h = M.map.up_dir, ["-"] = M.map.up_dir, l = M.map.open, ["<CR>"] = M.map.open, s = M.map.open_split, v = M.map.open_vsplit, t = M.map.open_tab, R = M.map.reload, d = M.map.delete, ["+"] = M.map.create, m = M.map.move, c = M.map.copy, ["."] = M.map.toggle_hidden_files}, ["show-hidden-files"] = true, ["is-file-hidden"] = _1_}
M.setup = function(_3fcfg)
  local cfg = (_3fcfg or {})
  if (false ~= cfg.auto_open) then
    vim.cmd("aug udir | au!")
    vim.cmd("au BufEnter * if !empty(expand('%')) && isdirectory(expand('%')) && !get(b:, 'is_udir') | call luaeval(\"require'udir'.udir('', true)\") | endif")
    vim.cmd("aug END")
  else
  end
  if cfg.keymaps then
    config["keymaps"] = cfg.keymaps
  else
  end
  if (nil ~= cfg.show_hidden_files) then
    config["show-hidden-files"] = cfg.show_hidden_files
  else
  end
  if cfg.is_file_hidden then
    config["is-file-hidden"] = cfg.is_file_hidden
    return nil
  else
    return nil
  end
end
local function sort_21(files)
  _G.assert((nil ~= files), "Missing argument files on lua/udir.fnl:62")
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
local function render_virttext(cwd, ns, files)
  _G.assert((nil ~= files), "Missing argument files on lua/udir.fnl:68")
  _G.assert((nil ~= ns), "Missing argument ns on lua/udir.fnl:68")
  _G.assert((nil ~= cwd), "Missing argument cwd on lua/udir.fnl:68")
  api.nvim_buf_clear_namespace(0, ns, 0, -1)
  for i, file in ipairs(files) do
    local path = u["join-path"](cwd, file.name)
    local _3fvirttext, _3fhl = nil, nil
    do
      local _8_ = file.type
      if (_8_ == "directory") then
        _3fvirttext, _3fhl = u.sep, "UdirDirectory"
      elseif (_8_ == "link") then
        _3fvirttext, _3fhl = ("@ \226\134\146 " .. assert(uv.fs_readlink(path))), "UdirSymlink"
      elseif (_8_ == "file") then
        if fs["executable?"](path) then
          _3fvirttext, _3fhl = "*", "UdirExecutable"
        else
          _3fvirttext, _3fhl = nil, "UdirFile"
        end
      else
        _3fvirttext, _3fhl = nil
      end
    end
    if _3fvirttext then
      api.nvim_buf_set_extmark(0, ns, (i - 1), #file.name, {virt_text = {{_3fvirttext, "UdirVirtText"}}, virt_text_pos = "overlay"})
      api.nvim_buf_set_extmark(0, ns, (i - 1), 0, {end_col = #file.name, hl_group = _3fhl})
    else
    end
  end
  return nil
end
local function render(state)
  _G.assert((nil ~= state), "Missing argument state on lua/udir.fnl:88")
  local _local_12_ = state
  local buf = _local_12_["buf"]
  local cwd = _local_12_["cwd"]
  local files = fs.list(cwd)
  local function not_hidden_3f(file)
    if config["show-hidden-files"] then
      return true
    else
      return not config["is-file-hidden"](file, files, cwd)
    end
  end
  local visible_files = vim.tbl_filter(not_hidden_3f, files)
  sort_21(visible_files)
  local function _14_(_241)
    return _241.name
  end
  u["set-lines"](buf, 0, -1, false, vim.tbl_map(_14_, visible_files))
  return render_virttext(cwd, state.ns, visible_files)
end
local function noremap(mode, buf, mappings)
  _G.assert((nil ~= mappings), "Missing argument mappings on lua/udir.fnl:105")
  _G.assert((nil ~= buf), "Missing argument buf on lua/udir.fnl:105")
  _G.assert((nil ~= mode), "Missing argument mode on lua/udir.fnl:105")
  for lhs, rhs in pairs(mappings) do
    local _16_
    do
      local t_15_ = vim
      if (nil ~= t_15_) then
        t_15_ = (t_15_).keymap
      else
      end
      if (nil ~= t_15_) then
        t_15_ = (t_15_).set
      else
      end
      _16_ = t_15_
    end
    if _16_ then
      vim.keymap.set(mode, lhs, rhs, {nowait = true, silent = true, buffer = buf})
    else
      api.nvim_buf_set_keymap(buf, mode, lhs, rhs, {nowait = true, noremap = true, silent = true})
    end
  end
  return nil
end
local function setup_keymaps(buf)
  _G.assert((nil ~= buf), "Missing argument buf on lua/udir.fnl:113")
  return noremap("n", buf, config.keymaps)
end
local function cleanup(state)
  _G.assert((nil ~= state), "Missing argument state on lua/udir.fnl:116")
  api.nvim_buf_delete(state.buf, {force = true})
  return store["remove!"](state.buf)
end
local function update_cwd(state, path)
  _G.assert((nil ~= path), "Missing argument path on lua/udir.fnl:120")
  _G.assert((nil ~= state), "Missing argument state on lua/udir.fnl:120")
  do end (state)["cwd"] = path
  return nil
end
M.quit = function()
  local _local_20_ = store.get()
  local _3falt_buf = _local_20_["?alt-buf"]
  local origin_buf = _local_20_["origin-buf"]
  local state = _local_20_
  if _3falt_buf then
    u["set-current-buf"](_3falt_buf)
  else
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
  else
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
    local path = fs.realpath(u["join-path"](state.cwd, filename))
    fs["assert-readable"](path)
    if fs["dir?"](path) then
      if _3fcmd then
        return vim.cmd((_3fcmd .. " " .. vim.fn.fnameescape(path)))
      else
        update_cwd(state, path)
        render(state)
        u["update-buf-name"](state.buf, state.cwd)
        local _3fhovered_file = (state["hovered-files"])[path]
        return u["set-cursor-pos"](_3fhovered_file, "or-top")
      end
    else
      u["set-current-buf"](state["origin-buf"])
      vim.cmd(((_3fcmd or "edit") .. " " .. vim.fn.fnameescape(path)))
      return cleanup(state)
    end
  else
    return nil
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
    else
    end
    return u["clear-prompt"]()
  end
end
local function copy_or_move(should_move)
  _G.assert((nil ~= should_move), "Missing argument should-move on lua/udir.fnl:181")
  local _28_ = u["get-line"]()
  if (_28_ == "") then
    return u.err("Empty filename")
  elseif (nil ~= _28_) then
    local filename = _28_
    local state = store.get()
    local path_saved = vim.opt_local.path
    vim.opt_local.path = state.cwd
    local _29_
    if should_move then
      _29_ = "Move to: "
    else
      _29_ = "Copy to: "
    end
    local function _31_(name)
      vim.opt_local.path = path_saved
      if name then
        local src = u["join-path"](state.cwd, filename)
        local dest = u["join-path"](state.cwd, name)
        fs["copy-or-move"](should_move, src, dest)
        render(state)
        u["clear-prompt"]()
        return u["set-cursor-pos"](fs.basename(dest))
      else
        return nil
      end
    end
    return vim.ui.input({prompt = _29_, completion = "file_in_path"}, _31_)
  else
    return nil
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
  local path_saved = vim.opt_local.path
  vim.opt_local.path = state.cwd
  local function _34_(name)
    vim.opt_local.path = path_saved
    if name then
      local path = u["join-path"](state.cwd, name)
      if vim.endswith(name, u.sep) then
        fs["create-dir"](path)
      else
        fs["create-file"](path)
      end
      render(state)
      u["clear-prompt"]()
      return u["set-cursor-pos"](fs.basename(path))
    else
      return nil
    end
  end
  return vim.ui.input({prompt = "New file: ", completion = "file_in_path"}, _34_)
end
M["toggle-hidden-files"] = function()
  local state = store.get()
  local _3fhovered_file = u["get-line"]()
  config["show-hidden-files"] = not config["show-hidden-files"]
  render(state)
  return u["set-cursor-pos"](_3fhovered_file)
end
M.udir = function(dir, _3ffrom_au)
  _G.assert((nil ~= dir), "Missing argument dir on lua/udir.fnl:233")
  local has_altbuf = (0 ~= vim.fn.bufexists(0))
  local origin_buf
  if (_3ffrom_au and has_altbuf) then
    origin_buf = vim.fn.bufnr("#")
  else
    origin_buf = api.nvim_get_current_buf()
  end
  local _3falt_buf
  if (_3ffrom_au or not has_altbuf) then
    _3falt_buf = nil
  else
    _3falt_buf = vim.fn.bufnr("#")
  end
  local cwd
  if ("" ~= dir) then
    cwd = fs.realpath(vim.fn.expand(dir))
  else
    local p = vim.fn.expand("%:p:h")
    if ("" ~= p) then
      cwd = fs.realpath(p)
    else
      cwd = assert(vim.loop.cwd())
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
  local buf = u["create-buf"](cwd)
  local ns = api.nvim_create_namespace(("udir." .. buf))
  local hovered_files = {}
  local state = {buf = buf, ["origin-buf"] = origin_buf, ["?alt-buf"] = _3falt_buf, cwd = cwd, ns = ns, ["hovered-files"] = hovered_files}
  setup_keymaps(buf)
  store["set!"](buf, state)
  render(state)
  return u["set-cursor-pos"](_3forigin_filename)
end
return M
