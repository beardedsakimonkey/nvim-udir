local api = vim.api
local M = {}
local buf_name_id = 1
local function get_buf_name_id()
  local id = buf_name_id
  buf_name_id = (buf_name_id + 1)
  return id
end
M["update-buf-name"] = function(buf, cwd)
  _G.assert((nil ~= cwd), "Missing argument cwd on lua/udir/util.fnl:32")
  _G.assert((nil ~= buf), "Missing argument buf on lua/udir/util.fnl:32")
  local old_name = vim.fn.bufname()
  local active_bufs
  local function _1_(_241)
    return _241.name
  end
  local function _2_(_241)
    return ((1 == _241.loaded) and (0 == _241.hidden))
  end
  active_bufs = vim.tbl_map(_1_, vim.tbl_filter(_2_, vim.fn.getbufinfo()))
  local new_name
  if vim.tbl_contains(active_bufs, cwd) then
    new_name = (cwd .. " " .. get_buf_name_id())
  else
    new_name = cwd
  end
  vim.cmd(("sil keepalt file " .. vim.fn.fnameescape(new_name)))
  return M["delete-buffer"](old_name)
end
M["update-statusline"] = function(cwd)
  _G.assert((nil ~= cwd), "Missing argument cwd on lua/udir/util.fnl:45")
  vim.opt_local.statusline = (" " .. cwd)
  return nil
end
M["find-or-create-buf"] = function(cwd)
  _G.assert((nil ~= cwd), "Missing argument cwd on lua/udir/util.fnl:48")
  local existing_buf = vim.fn.bufnr(("^" .. cwd .. "$"))
  local buf = nil
  if (existing_buf == -1) then
    buf = api.nvim_create_buf(false, true)
    assert(not (buf == -1))
    api.nvim_buf_set_name(buf, cwd)
  elseif "else" then
    buf = existing_buf
  else
  end
  api.nvim_buf_set_var(buf, "is_udir", true)
  api.nvim_set_current_buf(buf)
  api.nvim_buf_set_option(buf, "filetype", "udir")
  return buf
end
M["set-current-buf"] = function(buf)
  _G.assert((nil ~= buf), "Missing argument buf on lua/udir/util.fnl:69")
  if vim.fn.bufexists(buf) then
    pcall(api.nvim_set_current_buf, buf)
    return nil
  else
    return nil
  end
end
M["set-lines"] = function(buf, start, _end, strict_indexing, replacement)
  _G.assert((nil ~= replacement), "Missing argument replacement on lua/udir/util.fnl:75")
  _G.assert((nil ~= strict_indexing), "Missing argument strict-indexing on lua/udir/util.fnl:75")
  _G.assert((nil ~= _end), "Missing argument end on lua/udir/util.fnl:75")
  _G.assert((nil ~= start), "Missing argument start on lua/udir/util.fnl:75")
  _G.assert((nil ~= buf), "Missing argument buf on lua/udir/util.fnl:75")
  vim.opt_local.modifiable = true
  api.nvim_buf_set_lines(buf, start, _end, strict_indexing, replacement)
  vim.opt_local.modifiable = false
  return nil
end
M["get-line"] = function()
  local _local_6_ = api.nvim_win_get_cursor(0)
  local row = _local_6_[1]
  local _ = _local_6_[2]
  local _local_7_ = api.nvim_buf_get_lines(0, (row - 1), row, true)
  local line = _local_7_[1]
  return line
end
local function find_index(list, predicate)
  _G.assert((nil ~= predicate), "Missing argument predicate on lua/udir/util.fnl:86")
  _G.assert((nil ~= list), "Missing argument list on lua/udir/util.fnl:86")
  for i, item in ipairs(list) do
    if predicate(item) then
      return i
    else
    end
  end
  return nil
end
M["find-line"] = function(predicate)
  _G.assert((nil ~= predicate), "Missing argument predicate on lua/udir/util.fnl:93")
  local lines = api.nvim_buf_get_lines(0, 0, -1, false)
  return find_index(lines, predicate)
end
M["delete-buffer"] = function(name)
  _G.assert((nil ~= name), "Missing argument name on lua/udir/util.fnl:98")
  local bufs = vim.fn.getbufinfo()
  for _, buf in pairs(bufs) do
    if (buf.name == name) then
      api.nvim_buf_delete(buf.bufnr, {})
    else
    end
  end
  return nil
end
M["clear-prompt"] = function()
  return vim.cmd("norm! :")
end
M["sep"] = (package.config):sub(1, 1)
M["join-path"] = function(fst, snd)
  _G.assert((nil ~= snd), "Missing argument snd on lua/udir/util.fnl:109")
  _G.assert((nil ~= fst), "Missing argument fst on lua/udir/util.fnl:109")
  return (fst .. M.sep .. snd)
end
M["set-cursor-pos"] = function(_3ffilename, _3for_top)
  local line
  if _3for_top then
    line = 1
  else
    line = nil
  end
  if _3ffilename then
    local found
    local function _11_(_241)
      return (_241 == _3ffilename)
    end
    found = M["find-line"](_11_)
    if (found ~= nil) then
      line = found
    else
    end
  else
  end
  if (nil ~= line) then
    return api.nvim_win_set_cursor(0, {line, 0})
  else
    return nil
  end
end
M.err = function(msg)
  _G.assert((nil ~= msg), "Missing argument msg on lua/udir/util.fnl:119")
  return api.nvim_err_writeln(msg)
end
return M
