local fs = require("udir.fs")
local store = require("udir.store")
local u = require("udir.util")
local api = vim.api
local uv = vim.loop
local M = {}
local function sort_by_name(files)
  _G.assert((nil ~= files), "Missing argument files on lua/udir.fnl:13")
  local function _1_(a, b)
    if (("directory" == a.type) == ("directory" == b.type)) then
      return (a.name < b.name)
    else
      return ("directory" == a.type)
    end
  end
  table.sort(files, _1_)
  return files
end
local function add_hl_and_virttext(cwd, ns, files)
  _G.assert((nil ~= files), "Missing argument files on lua/udir.fnl:20")
  _G.assert((nil ~= ns), "Missing argument ns on lua/udir.fnl:20")
  _G.assert((nil ~= cwd), "Missing argument cwd on lua/udir.fnl:20")
  api.nvim_buf_clear_namespace(0, ns, 0, -1)
  for i, file in ipairs(files) do
    local path = u["join-path"](cwd, file.name)
    local _3fvirttext, _3fhl = nil, nil
    do
      local _3_ = file.type
      if (_3_ == "directory") then
        _3fvirttext, _3fhl = u.sep, "UdirDirectory"
      elseif (_3_ == "link") then
        _3fvirttext, _3fhl = ("@ \226\134\146 " .. assert(uv.fs_readlink(path))), "UdirSymlink"
      elseif (_3_ == "file") then
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
  _G.assert((nil ~= state), "Missing argument state on lua/udir.fnl:39")
  local _local_7_ = state
  local buf = _local_7_["buf"]
  local cwd = _local_7_["cwd"]
  local files = fs.list(cwd)
  local function not_hidden_3f(file)
    if M.config.show_hidden_files then
      return true
    else
      return not M.config.is_file_hidden(file, files, cwd)
    end
  end
  local visible_files = vim.tbl_filter(not_hidden_3f, files)
  do end (M.config.sort or sort_by_name)(visible_files)
  local function _9_(_241)
    return _241.name
  end
  u["set-lines"](buf, 0, -1, false, vim.tbl_map(_9_, visible_files))
  return add_hl_and_virttext(cwd, state.ns, visible_files)
end
local function noremap(mode, buf, mappings)
  _G.assert((nil ~= mappings), "Missing argument mappings on lua/udir.fnl:56")
  _G.assert((nil ~= buf), "Missing argument buf on lua/udir.fnl:56")
  _G.assert((nil ~= mode), "Missing argument mode on lua/udir.fnl:56")
  for lhs, rhs in pairs(mappings) do
    local _11_
    do
      local t_10_ = vim
      if (nil ~= t_10_) then
        t_10_ = (t_10_).keymap
      else
      end
      if (nil ~= t_10_) then
        t_10_ = (t_10_).set
      else
      end
      _11_ = t_10_
    end
    if _11_ then
      vim.keymap.set(mode, lhs, rhs, {nowait = true, silent = true, buffer = buf})
    else
      api.nvim_buf_set_keymap(buf, mode, lhs, rhs, {nowait = true, noremap = true, silent = true})
    end
  end
  return nil
end
local function setup_keymaps(buf)
  _G.assert((nil ~= buf), "Missing argument buf on lua/udir.fnl:64")
  return noremap("n", buf, M.config.keymaps)
end
local function cleanup(state)
  _G.assert((nil ~= state), "Missing argument state on lua/udir.fnl:67")
  api.nvim_buf_delete(state.buf, {force = true})
  return store["remove!"](state.buf)
end
local function update_cwd(state, path)
  _G.assert((nil ~= path), "Missing argument path on lua/udir.fnl:71")
  _G.assert((nil ~= state), "Missing argument state on lua/udir.fnl:71")
  do end (state)["cwd"] = path
  return nil
end
M.quit = function()
  local _local_15_ = store.get()
  local _3falt_buf = _local_15_["?alt-buf"]
  local origin_buf = _local_15_["origin-buf"]
  local state = _local_15_
  if _3falt_buf then
    u["set-current-buf"](_3falt_buf)
  else
  end
  u["set-current-buf"](origin_buf)
  return cleanup(state)
end
M.up_dir = function()
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
  _G.assert((nil ~= should_move), "Missing argument should-move on lua/udir.fnl:132")
  local _23_ = u["get-line"]()
  if (_23_ == "") then
    return u.err("Empty filename")
  elseif (nil ~= _23_) then
    local filename = _23_
    local state = store.get()
    local path_saved = vim.opt_local.path
    vim.opt_local.path = state.cwd
    local _24_
    if should_move then
      _24_ = "Move to: "
    else
      _24_ = "Copy to: "
    end
    local function _26_(name)
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
    return vim.ui.input({prompt = _24_, completion = "file_in_path"}, _26_)
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
  local function _29_(name)
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
  return vim.ui.input({prompt = "New file: ", completion = "file_in_path"}, _29_)
end
M["toggle-hidden-files"] = function()
  local state = store.get()
  local _3fhovered_file = u["get-line"]()
  M.config.show_hidden_files = not M.config.show_hidden_files
  render(state)
  return u["set-cursor-pos"](_3fhovered_file)
end
local function _32_()
  return M.open("split")
end
local function _33_()
  return M.open("vsplit")
end
local function _34_()
  return M.open("tabedit")
end
local function _35_()
  return false
end
M["config"] = {keymaps = {q = M.quit, h = M.up_dir, ["-"] = M.up_dir, l = M.open, ["<CR>"] = M.open, s = _32_, v = _33_, t = _34_, R = M.reload, d = M.delete, ["+"] = M.create, m = M.move, c = M.copy, ["."] = M.toggle_hidden_files}, show_hidden_files = true, is_file_hidden = _35_, sort = sort_by_name}
local function init(dir, _3ffrom_au)
  _G.assert((nil ~= dir), "Missing argument dir on lua/udir.fnl:206")
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
local function update_instance(dir)
  _G.assert((nil ~= dir), "Missing argument dir on lua/udir.fnl:233")
  local state = store.get(vim.fn.bufnr("#"))
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
  vim.cmd("noau bd")
  update_cwd(state, cwd)
  render(state)
  return u["update-buf-name"](state.buf, state.cwd)
end
M.udir = function(dir, _3ffrom_au)
  _G.assert((nil ~= dir), "Missing argument dir on lua/udir.fnl:244")
  local is_altbuf_udir
  if _3ffrom_au then
    is_altbuf_udir = vim.fn.getbufvar(vim.fn.bufnr("#"), "is_udir", false)
  else
    is_altbuf_udir = false
  end
  if is_altbuf_udir then
    return update_instance(dir)
  else
    return init(dir, _3ffrom_au)
  end
end
return M
