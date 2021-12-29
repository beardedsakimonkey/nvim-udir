local api = vim.api
local M = {}
local buf_name_id = 1
local function get_buf_name_id()
  local id = buf_name_id
  buf_name_id = (buf_name_id + 1)
  return id
end
M["update-statusline"] = function(cwd)
  assert((nil ~= cwd), string.format("Missing argument %s on %s:%s", "cwd", "lua/qdir/util.fnl", 17))
  vim.opt_local.statusline = (" " .. cwd)
  return nil
end
M["find-or-create-buf"] = function(cwd, win)
  assert((nil ~= win), string.format("Missing argument %s on %s:%s", "win", "lua/qdir/util.fnl", 20))
  assert((nil ~= cwd), string.format("Missing argument %s on %s:%s", "cwd", "lua/qdir/util.fnl", 20))
  local existing_buf = vim.fn.bufnr(("^" .. cwd .. "$"))
  local buf = nil
  if (existing_buf == -1) then
    buf = api.nvim_create_buf(false, true)
    assert(not (buf == -1))
    api.nvim_buf_set_name(buf, ("Qdir [" .. get_buf_name_id() .. "]"))
  elseif "else" then
    buf = existing_buf
  end
  api.nvim_buf_set_var(buf, "is_qdir", true)
  api.nvim_set_current_buf(buf)
  api.nvim_buf_set_option(buf, "filetype", "qdir")
  M["update-statusline"](cwd)
  return buf
end
M["set-current-buf"] = function(buf)
  assert((nil ~= buf), string.format("Missing argument %s on %s:%s", "buf", "lua/qdir/util.fnl", 44))
  if (buf and vim.fn.bufexists(buf)) then
    pcall(api.nvim_set_current_buf, buf)
    return nil
  end
end
M["set-lines"] = function(buf, start, _end, strict_indexing, replacement)
  assert((nil ~= replacement), string.format("Missing argument %s on %s:%s", "replacement", "lua/qdir/util.fnl", 50))
  assert((nil ~= strict_indexing), string.format("Missing argument %s on %s:%s", "strict-indexing", "lua/qdir/util.fnl", 50))
  assert((nil ~= _end), string.format("Missing argument %s on %s:%s", "end", "lua/qdir/util.fnl", 50))
  assert((nil ~= start), string.format("Missing argument %s on %s:%s", "start", "lua/qdir/util.fnl", 50))
  assert((nil ~= buf), string.format("Missing argument %s on %s:%s", "buf", "lua/qdir/util.fnl", 50))
  vim.opt_local.modifiable = true
  api.nvim_buf_set_lines(buf, start, _end, strict_indexing, replacement)
  vim.opt_local.modifiable = false
  return nil
end
M["get-line"] = function()
  local _let_3_ = api.nvim_win_get_cursor(0)
  local row = _let_3_[1]
  local _col = _let_3_[2]
  local _let_4_ = api.nvim_buf_get_lines(0, (row - 1), row, true)
  local line = _let_4_[1]
  return line
end
local function find_index(list, predicate)
  assert((nil ~= predicate), string.format("Missing argument %s on %s:%s", "predicate", "lua/qdir/util.fnl", 61))
  assert((nil ~= list), string.format("Missing argument %s on %s:%s", "list", "lua/qdir/util.fnl", 61))
  for i, item in ipairs(list) do
    if predicate(item) then
      return i
    end
  end
  return nil
end
M["find-line"] = function(predicate)
  assert((nil ~= predicate), string.format("Missing argument %s on %s:%s", "predicate", "lua/qdir/util.fnl", 67))
  local lines = api.nvim_buf_get_lines(0, 0, -1, false)
  return find_index(lines, predicate)
end
M["delete-buffer"] = function(name)
  assert((nil ~= name), string.format("Missing argument %s on %s:%s", "name", "lua/qdir/util.fnl", 72))
  local bufs = vim.fn.getbufinfo({buflisted = 1, bufloaded = 1})
  for _, buf in pairs(bufs) do
    if (buf.name == name) then
      api.nvim_buf_delete(buf.bufnr, {})
    end
  end
  return nil
end
M["clear-prompt"] = function()
  return vim.cmd("norm! :<esc>")
end
M["sep"] = (package.config):sub(1, 1)
M["join-path"] = function(fst, snd)
  assert((nil ~= snd), string.format("Missing argument %s on %s:%s", "snd", "lua/qdir/util.fnl", 83))
  assert((nil ~= fst), string.format("Missing argument %s on %s:%s", "fst", "lua/qdir/util.fnl", 83))
  return (fst .. M.sep .. snd)
end
M["set-cursor-pos"] = function(filename)
  if filename then
    local line
    local function _7_(_241)
      return (_241 == filename)
    end
    line = M["find-line"](_7_)
    if line then
      return api.nvim_win_set_cursor(0, {line, 0})
    end
  end
end
M.err = function(msg)
  return api.nvim_err_writeln(msg)
end
return M
