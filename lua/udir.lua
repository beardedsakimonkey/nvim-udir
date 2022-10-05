local fs = require("udir.fs")
local store = require("udir.store")
local u = require("udir.util")
local api = vim.api
local uv = vim.loop
local M = {}
local function sort_by_name(files)
  local function _1_(a, b)
    if (("directory" == a.type) == ("directory" == b.type)) then
      return (a.name < b.name)
    else
      return ("directory" == a.type)
    end
  end
  return table.sort(files, _1_)
end
local function add_hl_and_virttext(cwd, ns, files)
  api.nvim_buf_clear_namespace(0, ns, 0, -1)
  for i, file in ipairs(files) do
    local path = u["join-path"](cwd, file.name)
    local _3fvirttext, _3fhl = nil, nil
    do
      local _3_ = file.type
      if (_3_ == "directory") then
        _3fvirttext, _3fhl = u.sep, "UdirDirectory"
      elseif (_3_ == "link") then
        _3fvirttext, _3fhl = ("@ \226\134\146 " .. (uv.fs_readlink(path) or "???")), "UdirSymlink"
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
  local _local_7_ = state
  local buf = _local_7_["buf"]
  local cwd = _local_7_["cwd"]
  local files = fs.list(cwd)
  local function visible_3f(file)
    if M.config.show_hidden_files then
      return true
    else
      return not M.config.is_file_hidden(file, files, cwd)
    end
  end
  local visible_files = vim.tbl_filter(visible_3f, files)
  do end (M.config.sort or sort_by_name)(visible_files)
  local function _9_(_241)
    return _241.name
  end
  u["set-lines"](buf, 0, -1, false, vim.tbl_map(_9_, visible_files))
  return add_hl_and_virttext(cwd, state.ns, visible_files)
end
local function noremap(mode, buf, mappings)
  for lhs, rhs in pairs(mappings) do
    vim.keymap.set(mode, lhs, rhs, {nowait = true, silent = true, buffer = buf})
  end
  return nil
end
local function setup_keymaps(buf)
  return noremap("n", buf, M.config.keymaps)
end
local function cleanup(state)
  api.nvim_buf_delete(state.buf, {force = true})
  return store["remove!"](state.buf)
end
local function update_cwd(state, path)
  state["cwd"] = path
  return nil
end
M.quit = function()
  local _local_10_ = store.get()
  local _3falt_buf = _local_10_["?alt-buf"]
  local origin_buf = _local_10_["origin-buf"]
  local state = _local_10_
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
  u["update-buf-name"](state.cwd)
  return u["set-cursor-pos"](fs.basename(cwd), "or-top")
end
M.open = function(_3fcmd)
  local state = store.get()
  local filename = u["get-line"]()
  if ("" ~= filename) then
    local path, msg = uv.fs_realpath(u["join-path"](state.cwd, filename))
    if not path then
      return u.err(msg)
    else
      if fs["dir?"](path) then
        if _3fcmd then
          return vim.cmd((_3fcmd .. " " .. vim.fn.fnameescape(path)))
        else
          update_cwd(state, path)
          render(state)
          u["update-buf-name"](state.cwd)
          local _3fhovered_file = (state["hovered-files"])[path]
          return u["set-cursor-pos"](_3fhovered_file, "or-top")
        end
      else
        u["set-current-buf"](state["origin-buf"])
        vim.cmd(((_3fcmd or "edit") .. " " .. vim.fn.fnameescape(path)))
        return cleanup(state)
      end
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
    u["clear-prompt"]()
    if confirmed_3f then
      local ok_3f, msg = pcall(fs.delete, path)
      if not ok_3f then
        return u.err(msg)
      else
        return render(state)
      end
    else
      return nil
    end
  end
end
local function copy_or_move(move_3f)
  local filename = u["get-line"]()
  if ("" == filename) then
    return u.err("Empty filename")
  else
    local state = store.get()
    local _20_
    if move_3f then
      _20_ = "Move to: "
    else
      _20_ = "Copy to: "
    end
    local function _22_(name)
      u["clear-prompt"]()
      local src = u["join-path"](state.cwd, filename)
      local ok_3f, msg = pcall(fs["copy-or-move"], move_3f, src, name, state.cwd)
      if not ok_3f then
        return u.err(msg)
      else
        render(state)
        return u["set-cursor-pos"](fs.basename(name))
      end
    end
    return vim.ui.input({prompt = _20_, completion = "file"}, _22_)
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
  local function _25_(name)
    vim.opt_local.path = path_saved
    u["clear-prompt"]()
    if name then
      local path = u["join-path"](state.cwd, name)
      local ok_3f, msg = nil, nil
      if vim.endswith(name, u.sep) then
        ok_3f, msg = pcall(fs["create-dir"], path)
      else
        ok_3f, msg = pcall(fs["create-file"], path)
      end
      if not ok_3f then
        return u.err(msg)
      else
        render(state)
        return u["set-cursor-pos"](fs.basename(path))
      end
    else
      return nil
    end
  end
  return vim.ui.input({prompt = "New file: ", completion = "file_in_path"}, _25_)
end
M.toggle_hidden_files = function()
  local state = store.get()
  local _3fhovered_file = u["get-line"]()
  M.config.show_hidden_files = not M.config.show_hidden_files
  render(state)
  return u["set-cursor-pos"](_3fhovered_file)
end
M["map"] = {quit = "<Cmd>lua require'udir'.quit()<CR>", up_dir = "<Cmd>lua require'udir'.up_dir()<CR>", open = "<Cmd>lua require'udir'.open()<CR>", open_split = "<Cmd>lua require'udir'.open('split')<CR>", open_vsplit = "<Cmd>lua require'udir'.open('vsplit')<CR>", open_tab = "<Cmd>lua require'udir'.open('tabedit')<CR>", reload = "<Cmd>lua require'udir'.reload()<CR>", delete = "<Cmd>lua require'udir'.delete()<CR>", create = "<Cmd>lua require'udir'.create()<CR>", move = "<Cmd>lua require'udir'.move()<CR>", copy = "<Cmd>lua require'udir'.copy()<CR>", toggle_hidden_files = "<Cmd>lua require'udir'.toggle_hidden_files()<CR>"}
local function _29_()
  return false
end
M["config"] = {keymaps = {q = M.map.quit, h = M.map.up_dir, ["-"] = M.map.up_dir, l = M.map.open, ["<CR>"] = M.map.open, s = M.map.open_split, v = M.map.open_vsplit, t = M.map.open_tab, R = M.map.reload, d = M.map.delete, ["+"] = M.map.create, m = M.map.move, c = M.map.copy, ["."] = M.map.toggle_hidden_files}, show_hidden_files = true, is_file_hidden = _29_, sort = sort_by_name}
M.setup = function(_3fcfg)
  u.warn("`setup()` is now deprecated. Please see the readme.")
  local cfg = (_3fcfg or {})
  if (false == cfg.auto_open) then
    u.warn("`auto_open` is no longer configurable.")
  else
  end
  if cfg.keymaps then
    M.config["keymaps"] = cfg.keymaps
  else
  end
  if (nil ~= cfg.show_hidden_files) then
    M.config["show_hidden_files"] = cfg.show_hidden_files
  else
  end
  if cfg.is_file_hidden then
    M.config["is_file_hidden"] = cfg.is_file_hidden
    return nil
  else
    return nil
  end
end
M.udir = function(dir, _3ffrom_au)
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
      cwd = assert(uv.cwd())
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
