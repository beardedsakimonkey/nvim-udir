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
  if cfg.auto_open then
    vim.cmd("aug udir")
    vim.cmd("au!")
    vim.cmd("au BufEnter * if !empty(expand('%')) && isdirectory(expand('%')) && !get(b:, 'is_udir') | Udir | endif")
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
  _G.assert((nil ~= files), "Missing argument files on lua/udir.fnl:63")
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
  _G.assert((nil ~= files), "Missing argument files on lua/udir.fnl:69")
  _G.assert((nil ~= ns), "Missing argument ns on lua/udir.fnl:69")
  _G.assert((nil ~= cwd), "Missing argument cwd on lua/udir.fnl:69")
  api.nvim_buf_clear_namespace(0, ns, 0, -1)
  for i, file in ipairs(files) do
    local path = u["join-path"](cwd, file.name)
    local _3fvirttext, _3fhl = nil, nil
    do
      local _8_ = file.type
      if (_8_ == "directory") then
        _3fvirttext, _3fhl = u.sep, "UdirDirectory"
      elseif (_8_ == "link") then
        _3fvirttext, _3fhl = ("@ -> " .. assert(uv.fs_readlink(path))), "UdirSymlink"
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
  _G.assert((nil ~= state), "Missing argument state on lua/udir.fnl:89")
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
  local files_filtered = vim.tbl_filter(not_hidden_3f, files)
  sort_21(files_filtered)
  local filenames
  local function _14_(_241)
    return _241.name
  end
  filenames = vim.tbl_map(_14_, files_filtered)
  u["set-lines"](buf, 0, -1, false, filenames)
  return render_virttext(cwd, state.ns, files_filtered)
end
local function noremap(mode, buf, mappings)
  _G.assert((nil ~= mappings), "Missing argument mappings on lua/udir.fnl:107")
  _G.assert((nil ~= buf), "Missing argument buf on lua/udir.fnl:107")
  _G.assert((nil ~= mode), "Missing argument mode on lua/udir.fnl:107")
  for lhs, rhs in pairs(mappings) do
    api.nvim_buf_set_keymap(buf, mode, lhs, rhs, {nowait = true, noremap = true, silent = true})
  end
  return nil
end
local function setup_keymaps(buf)
  _G.assert((nil ~= buf), "Missing argument buf on lua/udir.fnl:112")
  return noremap("n", buf, config.keymaps)
end
local function cleanup(state)
  _G.assert((nil ~= state), "Missing argument state on lua/udir.fnl:115")
  api.nvim_buf_delete(state.buf, {force = true})
  return store["remove!"](state.buf)
end
local function update_cwd(state, path)
  _G.assert((nil ~= path), "Missing argument path on lua/udir.fnl:119")
  _G.assert((nil ~= state), "Missing argument state on lua/udir.fnl:119")
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
    local path = u["join-path"](state.cwd, filename)
    local realpath = fs.realpath(path)
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
  _G.assert((nil ~= should_move), "Missing argument should-move on lua/udir.fnl:182")
  local state = store.get()
  local filename = u["get-line"]()
  if ("" == filename) then
    return u.err("Empty filename")
  else
    local src = u["join-path"](state.cwd, filename)
    local prompt
    if should_move then
      prompt = "Move to: "
    else
      prompt = "Copy to: "
    end
    local name = vim.fn.input(prompt)
    if ("" ~= name) then
      local dest = u["join-path"](state.cwd, name)
      fs["copy-or-move"](should_move, src, dest)
      render(state)
      u["clear-prompt"]()
      return u["set-cursor-pos"](fs.basename(dest))
    else
      return nil
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
  else
    return nil
  end
end
M["toggle-hidden-files"] = function()
  local state = store.get()
  local _3fhovered_file = u["get-line"]()
  config["show-hidden-files"] = not config["show-hidden-files"]
  render(state)
  return u["set-cursor-pos"](_3fhovered_file)
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
  local buf = assert(u["find-or-create-buf"](cwd))
  local ns = api.nvim_create_namespace(("udir." .. buf))
  local hovered_files = {}
  local state = {buf = buf, ["origin-buf"] = origin_buf, ["?alt-buf"] = _3falt_buf, cwd = cwd, ns = ns, ["hovered-files"] = hovered_files}
  setup_keymaps(buf)
  store["set!"](buf, state)
  render(state)
  return u["set-cursor-pos"](_3forigin_filename)
end
return M
