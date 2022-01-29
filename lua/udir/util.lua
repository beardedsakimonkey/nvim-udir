local api = vim.api
local M = {}
local buf_name_id = 1
local function get_buf_name_id()
  local id = buf_name_id
  buf_name_id = (buf_name_id + 1)
  return id
end
M["update-buf-name"] = function(buf, cwd)
  local active_bufs
  local function _1_(_241)
    return _241.name
  end
  local function _2_(_241)
    return ((1 == _241.loaded) and (0 == _241.hidden))
  end
  active_bufs = vim.tbl_map(_1_, vim.tbl_filter(_2_, vim.fn.getbufinfo()))
  print(vim.inspect(active_bufs))
  local new_name
  if vim.tbl_contains(active_bufs, cwd) then
    new_name = (cwd .. " " .. get_buf_name_id())
  else
    new_name = cwd
  end
  return api.nvim_buf_set_name(buf, new_name)
end
M["update-statusline"] = function(cwd)
  assert((nil ~= cwd), string.format("Missing argument %s on %s:%s", "cwd", "lua/udir/util.fnl", 42))
  vim.opt_local.statusline = (" " .. cwd)
  return nil
end
M["find-or-create-buf"] = function(cwd, win)
  assert((nil ~= win), string.format("Missing argument %s on %s:%s", "win", "lua/udir/util.fnl", 45))
  assert((nil ~= cwd), string.format("Missing argument %s on %s:%s", "cwd", "lua/udir/util.fnl", 45))
  local existing_buf = vim.fn.bufnr(("^" .. cwd .. "$"))
  local buf = nil
  if (existing_buf == -1) then
    buf = api.nvim_create_buf(false, true)
    assert(not (buf == -1))
    M["update-buf-name"](buf, cwd)
  elseif "else" then
    buf = existing_buf
  end
  api.nvim_buf_set_var(buf, "is_udir", true)
  api.nvim_set_current_buf(buf)
  api.nvim_buf_set_option(buf, "filetype", "udir")
  return buf
end
M["set-current-buf"] = function(buf)
  assert((nil ~= buf), string.format("Missing argument %s on %s:%s", "buf", "lua/udir/util.fnl", 63))
  if (buf and vim.fn.bufexists(buf)) then
    pcall(api.nvim_set_current_buf, buf)
    return nil
  end
end
M["set-lines"] = function(buf, start, _end, strict_indexing, replacement)
  assert((nil ~= replacement), string.format("Missing argument %s on %s:%s", "replacement", "lua/udir/util.fnl", 69))
  assert((nil ~= strict_indexing), string.format("Missing argument %s on %s:%s", "strict-indexing", "lua/udir/util.fnl", 69))
  assert((nil ~= _end), string.format("Missing argument %s on %s:%s", "end", "lua/udir/util.fnl", 69))
  assert((nil ~= start), string.format("Missing argument %s on %s:%s", "start", "lua/udir/util.fnl", 69))
  assert((nil ~= buf), string.format("Missing argument %s on %s:%s", "buf", "lua/udir/util.fnl", 69))
  vim.opt_local.modifiable = true
  api.nvim_buf_set_lines(buf, start, _end, strict_indexing, replacement)
  vim.opt_local.modifiable = false
  return nil
end
M["get-line"] = function()
  local _let_6_ = api.nvim_win_get_cursor(0)
  local row = _let_6_[1]
  local _col = _let_6_[2]
  local _let_7_ = api.nvim_buf_get_lines(0, (row - 1), row, true)
  local line = _let_7_[1]
  return line
end
local function find_index(list, predicate)
  assert((nil ~= predicate), string.format("Missing argument %s on %s:%s", "predicate", "lua/udir/util.fnl", 80))
  assert((nil ~= list), string.format("Missing argument %s on %s:%s", "list", "lua/udir/util.fnl", 80))
  for i, item in ipairs(list) do
    if predicate(item) then
      return i
    end
  end
  return nil
end
M["find-line"] = function(predicate)
  assert((nil ~= predicate), string.format("Missing argument %s on %s:%s", "predicate", "lua/udir/util.fnl", 86))
  local lines = api.nvim_buf_get_lines(0, 0, -1, false)
  return find_index(lines, predicate)
end
M["delete-buffer"] = function(name)
  assert((nil ~= name), string.format("Missing argument %s on %s:%s", "name", "lua/udir/util.fnl", 91))
  local bufs = vim.fn.getbufinfo({buflisted = 1, bufloaded = 1})
  for _, buf in pairs(bufs) do
    if (buf.name == name) then
      api.nvim_buf_delete(buf.bufnr, {})
    end
  end
  return nil
end
M["clear-prompt"] = function()
  return vim.cmd("norm! :")
end
M["sep"] = (package.config):sub(1, 1)
M["join-path"] = function(fst, snd)
  assert((nil ~= snd), string.format("Missing argument %s on %s:%s", "snd", "lua/udir/util.fnl", 102))
  assert((nil ~= fst), string.format("Missing argument %s on %s:%s", "fst", "lua/udir/util.fnl", 102))
  return (fst .. M.sep .. snd)
end
M["set-cursor-pos"] = function(filename, or_top)
  local line
  if or_top then
    line = 1
  else
    line = nil
  end
  if filename then
    local found
    local function _11_(_241)
      return (_241 == filename)
    end
    found = M["find-line"](_11_)
    if (found ~= nil) then
      line = found
    end
  end
  if (nil ~= line) then
    return api.nvim_win_set_cursor(0, {line, 0})
  end
end
M.err = function(msg)
  return api.nvim_err_writeln(msg)
end
return M
