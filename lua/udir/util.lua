local api = vim.api
local function find_index(list, predicate_3f)
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
  local lines = api.nvim_buf_get_lines(0, 0, -1, false)
  return find_index(lines, predicate_3f)
end
local function create_buf_name(cwd)
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
  local success, ret = pcall(api.nvim_buf_get_var, buf, var_name)
  if success then
    return ret
  else
    return false
  end
end
local function delete_buffers(name)
  for _, buf in pairs(vim.fn.getbufinfo()) do
    if (buf.name == name) then
      pcall(api.nvim_buf_delete, buf.bufnr, {})
    else
    end
  end
  return nil
end
local function update_buf_name(cwd)
  local old_name = vim.fn.bufname()
  local new_name = create_buf_name(cwd)
  vim.cmd(("sil keepalt file " .. vim.fn.fnameescape(new_name)))
  return delete_buffers(old_name)
end
local function create_buf(cwd)
  local existing_buf = vim.fn.bufnr(("^" .. cwd .. "$"))
  local buf = nil
  if (-1 ~= existing_buf) then
    if buf_has_var(existing_buf, "is_udir") then
      buf = api.nvim_create_buf(false, true)
      api.nvim_buf_set_name(buf, create_buf_name(cwd))
    else
      buf = existing_buf
      if (vim.api.nvim_get_current_buf() == existing_buf) then
        vim.cmd(("sil file " .. vim.fn.fnameescape(cwd)))
      else
      end
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
local function set_current_buf(buf)
  if vim.fn.bufexists(buf) then
    return vim.cmd(("sil! keepj buffer " .. buf))
  else
    return nil
  end
end
local function set_lines(buf, start, _end, strict_indexing, replacement)
  vim.opt_local.modifiable = true
  api.nvim_buf_set_lines(buf, start, _end, strict_indexing, replacement)
  vim.opt_local.modifiable = false
  return nil
end
local function get_line()
  local _local_10_ = api.nvim_win_get_cursor(0)
  local row = _local_10_[1]
  local _ = _local_10_[2]
  local _local_11_ = api.nvim_buf_get_lines(0, (row - 1), row, true)
  local line = _local_11_[1]
  return line
end
local function rename_buffers(old_name, new_name)
  if vim.fn.bufexists(new_name) then
    delete_buffers(new_name)
  else
  end
  for _, buf in pairs(vim.fn.getbufinfo()) do
    if (buf.name == old_name) then
      api.nvim_buf_set_name(buf.bufnr, new_name)
      local function _13_()
        return vim.cmd("silent! w!")
      end
      api.nvim_buf_call(buf.bufnr, _13_)
    else
    end
  end
  return nil
end
local function clear_prompt()
  return vim.cmd("norm! :")
end
local sep = (package.config):sub(1, 1)
local function join_path(fst, snd)
  return (fst .. sep .. snd)
end
local function set_cursor_pos(_3ffilename, _3for_top)
  local _3fline
  if _3for_top then
    _3fline = 1
  else
    _3fline = nil
  end
  if _3ffilename then
    local _3ffound
    local function _16_(_241)
      return (_241 == _3ffilename)
    end
    _3ffound = find_line(_16_)
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
local function err(msg)
  return vim.notify(("[udir] " .. msg), vim.log.levels.ERROR)
end
local function warn(msg)
  return vim.notify(("[udir] " .. msg), vim.log.levels.WARN)
end
local function trim_start(str)
  local _20_ = str:gsub("^%s*", "")
  return _20_
end
return {["delete-buffers"] = delete_buffers, ["update-buf-name"] = update_buf_name, ["create-buf"] = create_buf, ["set-current-buf"] = set_current_buf, ["set-lines"] = set_lines, ["get-line"] = get_line, ["rename-buffers"] = rename_buffers, ["clear-prompt"] = clear_prompt, sep = sep, ["join-path"] = join_path, ["set-cursor-pos"] = set_cursor_pos, err = err, warn = warn, ["trim-start"] = trim_start}
