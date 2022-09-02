local uv = vim.loop
local u = require("udir.util")
local M = {}
local function delete_file(path)
  assert(uv.fs_unlink(path))
  return u["delete-buffers"](path)
end
local function delete_dir(path)
  do
    local fs_2_auto = assert(uv.fs_scandir(path))
    local done_3f_3_auto = false
    while not done_3f_3_auto do
      local name, type = uv.fs_scandir_next(fs_2_auto)
      if not name then
        done_3f_3_auto = true
        assert(not type)
      else
        if (type == "directory") then
          delete_dir(u["join-path"](path, name))
        else
          delete_file(u["join-path"](path, name))
        end
      end
    end
  end
  return assert(uv.fs_rmdir(path))
end
local function move(src, dest)
  assert(uv.fs_rename(src, dest))
  if not M["dir?"](src) then
    return u["rename-buffers"](src, dest)
  else
    return nil
  end
end
local function copy_file(src, dest)
  return assert(uv.fs_copyfile(src, dest))
end
local function copy_dir(src, dest)
  local stat = assert(uv.fs_stat(src))
  assert(uv.fs_mkdir(dest, stat.mode))
  local fs_2_auto = assert(uv.fs_scandir(src))
  local done_3f_3_auto = false
  while not done_3f_3_auto do
    local name, type = uv.fs_scandir_next(fs_2_auto)
    if not name then
      done_3f_3_auto = true
      assert(not type)
    else
      local src2 = u["join-path"](src, name)
      local dest2 = u["join-path"](dest, name)
      if (type == "directory") then
        copy_dir(src2, dest2)
      else
        copy_file(src2, dest2)
      end
    end
  end
  return nil
end
local function symlink_3f(path)
  local link = uv.fs_readlink(path)
  return (nil ~= link)
end
local function abs_3f(path)
  local c = path:sub(1, 1)
  return ("/" == c)
end
local function expand_tilde(path)
  local res = path:gsub("^~", os.getenv("HOME"))
  return res
end
M.realpath = function(_3fpath)
  return assert(uv.fs_realpath(_3fpath))
end
M["dir?"] = function(path)
  local _3ffile_info = uv.fs_stat(path)
  if (nil ~= _3ffile_info) then
    return ("directory" == _3ffile_info.type)
  else
    return false
  end
end
M["executable?"] = function(path)
  local ret = uv.fs_access(path, "X")
  return ret
end
M.list = function(path)
  local ret = {}
  do
    local fs_2_auto = assert(uv.fs_scandir(path))
    local done_3f_3_auto = false
    while not done_3f_3_auto do
      local name, type = uv.fs_scandir_next(fs_2_auto)
      if not name then
        done_3f_3_auto = true
        assert(not type)
      else
        table.insert(ret, {name = name, type = type})
      end
    end
  end
  return ret
end
M["exists?"] = function(path)
  return uv.fs_access(path, "")
end
M["get-parent-dir"] = function(dir)
  local parts = vim.split(dir, u.sep)
  table.remove(parts)
  local parent = table.concat(parts, u.sep)
  assert(M["exists?"](parent))
  return parent
end
M.basename = function(path)
  local path0
  if vim.endswith(path, u.sep) then
    path0 = path:sub(1, -2)
  else
    path0 = path
  end
  local parts = vim.split(path0, u.sep)
  return parts[#parts]
end
M.delete = function(path)
  if (M["dir?"](path) and not symlink_3f(path)) then
    return delete_dir(path)
  else
    return delete_file(path)
  end
end
M["create-dir"] = function(path)
  if M["exists?"](path) then
    return u.err(("%q already exists"):format(path))
  else
    local mode = tonumber("755", 8)
    return assert(uv.fs_mkdir(path, mode))
  end
end
M["create-file"] = function(path)
  if M["exists?"](path) then
    return u.err(("%q already exists"):format(path))
  else
    local mode = tonumber("644", 8)
    local fd = assert(uv.fs_open(path, "w", mode))
    return assert(uv.fs_close(fd))
  end
end
M["copy-or-move"] = function(move_3f, src, dest)
  assert(M["exists?"](src))
  local dest0 = M.realpath(expand_tilde(dest))
  local dest1
  if abs_3f(dest0) then
    dest1 = dest0
  else
    dest1 = u["join-path"](state.cwd, name)
  end
  assert((src ~= dest1))
  if M["dir?"](src) then
    local op
    if move_3f then
      op = move
    else
      op = copy_dir
    end
    assert(M["dir?"](dest1))
    return op(src, u["join-path"](dest1, M.basename(src)))
  else
    local op
    if move_3f then
      op = move
    else
      op = copy_file
    end
    if M["dir?"](dest1) then
      return op(src, u["join-path"](dest1, M.basename(src)))
    else
      return op(src, dest1)
    end
  end
end
return M