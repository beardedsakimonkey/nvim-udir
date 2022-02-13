local api = vim.api
local M = {}
local function find_index(list, predicate_3f)
  _G.assert((nil ~= predicate_3f), "Missing argument predicate? on lua/udir/util.fnl:5")
  _G.assert((nil ~= list), "Missing argument list on lua/udir/util.fnl:5")
  local _3fret = nil
  for i, item in ipairs(list) do
    if (nil ~= _3fret) then break end
    if predicate_3f(item) then
      _3fret = i
    else
    end
  end
  return _3fret
end
local function find_line(predicate_3f)
  _G.assert((nil ~= predicate_3f), "Missing argument predicate? on lua/udir/util.fnl:13")
  local lines = api.nvim_buf_get_lines(0, 0, -1, false)
  return find_index(lines, predicate_3f)
end
local function create_buf_name(cwd)
  _G.assert((nil ~= cwd), "Missing argument cwd on lua/udir/util.fnl:37")
  local loaded_bufs
  local function _2_(_241)
    return _241.name
  end
  local function _3_(_241)
    return (1 == _241.loaded)
  end
  loaded_bufs = vim.tbl_map(_2_, vim.tbl_filter(_3_, vim.fn.getbufinfo()))
  local new_name = cwd
  local i = 0
  while vim.tbl_contains(loaded_bufs, new_name) do
    i = (1 + i)
    new_name = (cwd .. " [" .. i .. "]")
  end
  return new_name
end
local function buf_has_var(buf, var_name)
  _G.assert((nil ~= var_name), "Missing argument var-name on lua/udir/util.fnl:50")
  _G.assert((nil ~= buf), "Missing argument buf on lua/udir/util.fnl:50")
  local success, ret = pcall(api.nvim_buf_get_var, buf, var_name)
  if success then
    return ret
  else
    return false
  end
end
M["update-buf-name"] = function(buf, cwd)
  _G.assert((nil ~= cwd), "Missing argument cwd on lua/udir/util.fnl:58")
  _G.assert((nil ~= buf), "Missing argument buf on lua/udir/util.fnl:58")
  local old_name = vim.fn.bufname()
  local new_name = create_buf_name(cwd)
  vim.cmd(("sil keepalt file " .. vim.fn.fnameescape(new_name)))
  return M["delete-buffers"](old_name)
end
M["create-buf"] = function(cwd)
  _G.assert((nil ~= cwd), "Missing argument cwd on lua/udir/util.fnl:65")
  local existing_buf = vim.fn.bufnr(("^" .. cwd .. "$"))
  local buf = nil
  if (-1 ~= existing_buf) then
    if buf_has_var(existing_buf, "is_udir") then
      buf = api.nvim_create_buf(false, true)
      api.nvim_buf_set_name(buf, create_buf_name(cwd))
    else
      buf = existing_buf
      vim.cmd(("sil file " .. vim.fn.fnameescape(cwd)))
    end
  else
    buf = api.nvim_create_buf(false, true)
    api.nvim_buf_set_name(buf, cwd)
  end
  assert((0 ~= buf))
  api.nvim_buf_set_var(buf, "is_udir", true)
  api.nvim_set_current_buf(buf)
  api.nvim_buf_set_option(buf, "filetype", "udir")
  return buf
end
M["set-current-buf"] = function(buf)
  _G.assert((nil ~= buf), "Missing argument buf on lua/udir/util.fnl:93")
  if vim.fn.bufexists(buf) then
    vim.cmd(("sil! keepj buffer " .. buf))
    return nil
  else
    return nil
  end
end
M["set-lines"] = function(buf, start, _end, strict_indexing, replacement)
  _G.assert((nil ~= replacement), "Missing argument replacement on lua/udir/util.fnl:98")
  _G.assert((nil ~= strict_indexing), "Missing argument strict-indexing on lua/udir/util.fnl:98")
  _G.assert((nil ~= _end), "Missing argument end on lua/udir/util.fnl:98")
  _G.assert((nil ~= start), "Missing argument start on lua/udir/util.fnl:98")
  _G.assert((nil ~= buf), "Missing argument buf on lua/udir/util.fnl:98")
  vim.opt_local.modifiable = true
  api.nvim_buf_set_lines(buf, start, _end, strict_indexing, replacement)
  vim.opt_local.modifiable = false
  return nil
end
M["get-line"] = function()
  local _local_8_ = api.nvim_win_get_cursor(0)
  local row = _local_8_[1]
  local _ = _local_8_[2]
  local _local_9_ = api.nvim_buf_get_lines(0, (row - 1), row, true)
  local line = _local_9_[1]
  return line
end
M["delete-buffers"] = function(name)
  _G.assert((nil ~= name), "Missing argument name on lua/udir/util.fnl:109")
  for _, buf in pairs(vim.fn.getbufinfo()) do
    if (buf.name == name) then
      api.nvim_buf_delete(buf.bufnr, {})
    else
    end
  end
  return nil
end
M["rename-buffers"] = function(old_name, new_name)
  _G.assert((nil ~= new_name), "Missing argument new-name on lua/udir/util.fnl:114")
  _G.assert((nil ~= old_name), "Missing argument old-name on lua/udir/util.fnl:114")
  for _, buf in pairs(vim.fn.getbufinfo()) do
    if (buf.name == old_name) then
      api.nvim_buf_set_name(buf.bufnr, new_name)
      local function _11_()
        return vim.cmd("silent! w!")
      end
      api.nvim_buf_call(buf.bufnr, _11_)
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
  _G.assert((nil ~= snd), "Missing argument snd on lua/udir/util.fnl:125")
  _G.assert((nil ~= fst), "Missing argument fst on lua/udir/util.fnl:125")
  return (fst .. M.sep .. snd)
end
M["set-cursor-pos"] = function(_3ffilename, _3for_top)
  local _3fline
  if _3for_top then
    _3fline = 1
  else
    _3fline = nil
  end
  if _3ffilename then
    local _3ffound
    local function _14_(_241)
      return (_241 == _3ffilename)
    end
    _3ffound = find_line(_14_)
    if (nil ~= _3ffound) then
      _3fline = _3ffound
    else
    end
  else
  end
  if (nil ~= _3fline) then
    return api.nvim_win_set_cursor(0, {_3fline, 0})
  else
    return nil
  end
end
M.err = function(msg)
  _G.assert((nil ~= msg), "Missing argument msg on lua/udir/util.fnl:137")
  return api.nvim_err_writeln(msg)
end
return M
