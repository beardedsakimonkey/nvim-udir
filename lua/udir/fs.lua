local uv = vim.loop
local u = require("udir.util")
local M = {}
local function assert_doesnt_exist(path)
  assert((nil ~= path), string.format("Missing argument %s on %s:%s", "path", "lua/udir/fs.fnl", 10))
  assert(not uv.fs_access(path, "R"), string.format("%q already exists", path))
  return nil
end
local function delete_file(path)
  assert((nil ~= path), string.format("Missing argument %s on %s:%s", "path", "lua/udir/fs.fnl", 32))
  assert(uv.fs_unlink(path))
  return u["delete-buffer"](path)
end
local function delete_dir(path)
  assert((nil ~= path), string.format("Missing argument %s on %s:%s", "path", "lua/udir/fs.fnl", 36))
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
  assert((nil ~= dest), string.format("Missing argument %s on %s:%s", "dest", "lua/udir/fs.fnl", 43))
  assert((nil ~= src), string.format("Missing argument %s on %s:%s", "src", "lua/udir/fs.fnl", 43))
  return assert(uv.fs_rename(src, dest))
end
local function copy_file(src, dest)
  assert((nil ~= dest), string.format("Missing argument %s on %s:%s", "dest", "lua/udir/fs.fnl", 46))
  assert((nil ~= src), string.format("Missing argument %s on %s:%s", "src", "lua/udir/fs.fnl", 46))
  return assert(uv.fs_copyfile(src, dest))
end
local function copy_dir(src, dest)
  assert((nil ~= dest), string.format("Missing argument %s on %s:%s", "dest", "lua/udir/fs.fnl", 49))
  assert((nil ~= src), string.format("Missing argument %s on %s:%s", "src", "lua/udir/fs.fnl", 49))
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
  assert((nil ~= path), string.format("Missing argument %s on %s:%s", "path", "lua/udir/fs.fnl", 59))
  local link = uv.fs_readlink(path)
  return (nil ~= link)
end
M.canonicalize = function(_3fpath)
  return assert(uv.fs_realpath(_3fpath))
end
M["dir?"] = function(path)
  assert((nil ~= path), string.format("Missing argument %s on %s:%s", "path", "lua/udir/fs.fnl", 72))
  local file_info = uv.fs_stat(path)
  if (nil ~= file_info) then
    return ("directory" == file_info.type)
  else
    return false
  end
end
M.list = function(path)
  assert((nil ~= path), string.format("Missing argument %s on %s:%s", "path", "lua/udir/fs.fnl", 76))
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
M["assert-readable"] = function(path)
  assert((nil ~= path), string.format("Missing argument %s on %s:%s", "path", "lua/udir/fs.fnl", 84))
  assert(uv.fs_access(path, "R"))
  return nil
end
M["get-parent-dir"] = function(dir)
  assert((nil ~= dir), string.format("Missing argument %s on %s:%s", "dir", "lua/udir/fs.fnl", 88))
  local parent_dir = M.canonicalize((dir .. u.sep .. ".."))
  M["assert-readable"](parent_dir)
  return parent_dir
end
M.basename = function(_3fpath)
  local _3fpath0
  if vim.endswith(_3fpath, u.sep) then
    _3fpath0 = _3fpath:sub(1, -2)
  else
    _3fpath0 = _3fpath
  end
  local split = vim.split(_3fpath0, u.sep)
  return split[#split]
end
M.delete = function(path)
  assert((nil ~= path), string.format("Missing argument %s on %s:%s", "path", "lua/udir/fs.fnl", 100))
  M["assert-readable"](path)
  if (M["dir?"](path) and not symlink_3f(path)) then
    delete_dir(path)
  else
    delete_file(path)
  end
  return nil
end
M["create-dir"] = function(path)
  assert((nil ~= path), string.format("Missing argument %s on %s:%s", "path", "lua/udir/fs.fnl", 107))
  assert_doesnt_exist(path)
  local mode = tonumber("755", 8)
  assert(uv.fs_mkdir(path, mode))
  return nil
end
M["create-file"] = function(path)
  assert((nil ~= path), string.format("Missing argument %s on %s:%s", "path", "lua/udir/fs.fnl", 114))
  assert_doesnt_exist(path)
  local mode = tonumber("644", 8)
  local fd = assert(uv.fs_open(path, "w", mode))
  assert(uv.fs_close(fd))
  return nil
end
M["copy-or-move"] = function(should_move, src, dest)
  assert((nil ~= dest), string.format("Missing argument %s on %s:%s", "dest", "lua/udir/fs.fnl", 122))
  assert((nil ~= src), string.format("Missing argument %s on %s:%s", "src", "lua/udir/fs.fnl", 122))
  assert((nil ~= should_move), string.format("Missing argument %s on %s:%s", "should-move", "lua/udir/fs.fnl", 122))
  assert((src ~= dest))
  M["assert-readable"](src)
  if M["dir?"](src) then
    local op
    if should_move then
      op = move
    else
      op = copy_dir
    end
    assert(M["dir?"](dest))
    return op(src, u["join-path"](dest, M.basename(src)))
  else
    local op
    if should_move then
      op = move
    else
      op = copy_file
    end
    if M["dir?"](dest) then
      return op(src, u["join-path"](dest, M.basename(src)))
    else
      return op(src, dest)
    end
  end
end
return M
