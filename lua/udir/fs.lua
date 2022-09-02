local uv = vim.loop
local u = require("udir.util")
local function dir_3f(path)
  local _3ffile_info = uv.fs_stat(path)
  if (nil ~= _3ffile_info) then
    return ("directory" == _3ffile_info.type)
  else
    return false
  end
end
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
  if not dir_3f(src) then
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
local function realpath(_3fpath)
  return assert(uv.fs_realpath(_3fpath))
end
local function executable_3f(path)
  local ret = uv.fs_access(path, "X")
  return ret
end
local function list(path)
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
local function exists_3f(path)
  return uv.fs_access(path, "")
end
local function get_parent_dir(dir)
  local parts = vim.split(dir, u.sep)
  table.remove(parts)
  local parent = table.concat(parts, u.sep)
  assert(exists_3f(parent))
  return parent
end
local function basename(path)
  local path0
  if vim.endswith(path, u.sep) then
    path0 = path:sub(1, -2)
  else
    path0 = path
  end
  local parts = vim.split(path0, u.sep)
  return parts[#parts]
end
local function delete(path)
  if (dir_3f(path) and not symlink_3f(path)) then
    return delete_dir(path)
  else
    return delete_file(path)
  end
end
local function create_dir(path)
  if exists_3f(path) then
    return u.err(("%q already exists"):format(path))
  else
    local mode = tonumber("755", 8)
    return assert(uv.fs_mkdir(path, mode))
  end
end
local function create_file(path)
  if exists_3f(path) then
    return u.err(("%q already exists"):format(path))
  else
    local mode = tonumber("644", 8)
    local fd = assert(uv.fs_open(path, "w", mode))
    return assert(uv.fs_close(fd))
  end
end
local function copy_or_move(move_3f, src, dest, cwd)
  assert(exists_3f(src))
  local dest0 = expand_tilde(dest)
  local dest1
  if abs_3f(dest0) then
    dest1 = dest0
  else
    dest1 = u["join-path"](cwd, dest0)
  end
  assert((src ~= dest1))
  if dir_3f(src) then
    local op
    if move_3f then
      op = move
    else
      op = copy_dir
    end
    assert(dir_3f(dest1))
    return op(src, u["join-path"](dest1, basename(src)))
  else
    local op
    if move_3f then
      op = move
    else
      op = copy_file
    end
    if dir_3f(dest1) then
      return op(src, u["join-path"](dest1, basename(src)))
    else
      return op(src, dest1)
    end
  end
end
return {realpath = realpath, ["dir?"] = dir_3f, ["executable?"] = executable_3f, list = list, ["exists?"] = exists_3f, ["get-parent-dir"] = get_parent_dir, basename = basename, delete = delete, ["create-dir"] = create_dir, ["create-file"] = create_file, ["copy-or-move"] = copy_or_move}