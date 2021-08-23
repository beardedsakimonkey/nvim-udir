local uv = vim.loop
local M = {}
local function assert_readable(path)
  assert((nil ~= path), string.format("Missing argument %s on %s:%s", "path", "lua/qdir/fs.fnl", 5))
  assert(uv.fs_access(path, "R"))
  return nil
end
local function assert_doesnt_exist(path)
  assert((nil ~= path), string.format("Missing argument %s on %s:%s", "path", "lua/qdir/fs.fnl", 9))
  assert(not uv.fs_access(path, "R"), string.format("%q already exists", path))
  return nil
end
local function delete_dir(path)
  assert((nil ~= path), string.format("Missing argument %s on %s:%s", "path", "lua/qdir/fs.fnl", 14))
  return vim.fn.system(("rm -rf " .. vim.fn.fnameescape(path)))
end
M.canonicalize = function(path)
  assert((nil ~= path), string.format("Missing argument %s on %s:%s", "path", "lua/qdir/fs.fnl", 21))
  return assert(uv.fs_realpath(path))
end
M["is-dir?"] = function(path)
  assert((nil ~= path), string.format("Missing argument %s on %s:%s", "path", "lua/qdir/fs.fnl", 25))
  assert_readable(path)
  local file_info = uv.fs_stat(path)
  return (file_info.type == "directory")
end
M.list = function(path)
  assert((nil ~= path), string.format("Missing argument %s on %s:%s", "path", "lua/qdir/fs.fnl", 30))
  local fs = assert(uv.fs_scandir(path))
  local ret = {}
  local done_3f = false
  while not done_3f do
    local name, type, err_name = uv.fs_scandir_next(fs)
    if (name == nil) then
      done_3f = true
      assert(not type)
    else
      table.insert(ret, {name = name, type = type})
    end
  end
  return ret
end
M["get-parent-dir"] = function(dir)
  assert((nil ~= dir), string.format("Missing argument %s on %s:%s", "dir", "lua/qdir/fs.fnl", 47))
  local parent_dir = M.canonicalize((dir .. "/.."))
  assert_readable(parent_dir)
  return parent_dir
end
M.basename = function(path)
  assert((nil ~= path), string.format("Missing argument %s on %s:%s", "path", "lua/qdir/fs.fnl", 53))
  local path_without_trailing_slash
  if vim.endswith(path, "/") then
    path_without_trailing_slash = path:sub(1, -1)
  else
    path_without_trailing_slash = path
  end
  local split = vim.split(path_without_trailing_slash, "/")
  return split[#split]
end
M.delete = function(path)
  assert((nil ~= path), string.format("Missing argument %s on %s:%s", "path", "lua/qdir/fs.fnl", 59))
  if M["is-dir?"](path) then
    return delete_dir(path)
  elseif "else" then
    return assert(uv.fs_unlink(path))
  end
end
M["create-dir"] = function(path)
  assert((nil ~= path), string.format("Missing argument %s on %s:%s", "path", "lua/qdir/fs.fnl", 63))
  assert_doesnt_exist(path)
  local mode = tonumber("755", 8)
  return assert(uv.fs_mkdir(path, mode))
end
M["create-file"] = function(path)
  assert((nil ~= path), string.format("Missing argument %s on %s:%s", "path", "lua/qdir/fs.fnl", 69))
  assert_doesnt_exist(path)
  local mode = tonumber("644", 8)
  assert(uv.fs_open(path, "w", mode))
  return nil
end
return M
