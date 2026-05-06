local util = require'udir.util'
local uv = vim.loop

local M = {}

-- Polyfill for vim.fs.dir
local function dir(path)
    return function(fs)
        return uv.fs_scandir_next(fs)
    end,
    uv.fs_scandir(path)
end

local function move(src, dest)
    assert(uv.fs_rename(src, dest))
    if not M.is_dir(src) then
        util.rename_buffers(src, dest)
    end
end

local function copy_file(src, dest)
    assert(uv.fs_copyfile(src, dest))
end

local function copy_dir(src, dest)
    local stat = assert(uv.fs_stat(src))
    assert(uv.fs_mkdir(dest, stat.mode))
    for name, type in dir(src) do
        local copy = type == 'directory' and copy_dir or copy_file
        copy(util.join_path(src, name), util.join_path(dest, name))
    end
end

local function exists(path)
    return (uv.fs_access(path, ''))
end

function M.exists(path)
    return exists(path)
end

function M.normalize_path(path, cwd)
    assert(path, 'Empty path')
    path = util.trim_start(path)
    assert(path ~= '', 'Empty path')
    path = path:gsub('^~', os.getenv'HOME')
    return path:sub(1, 1) == '/' and path or util.join_path(cwd, path)
end

function M.realpath(path)
    return assert(uv.fs_realpath(path))
end

-- NOTE: Symlink dirs are considered directories
function M.is_dir(path)
    local file_info = uv.fs_stat(path)
    return file_info and file_info.type == 'directory' or false
end

function M.list(path)
    local ret = {}
    for basename, type in dir(path) do
        table.insert(ret, {name=basename, type=type})
    end
    return ret
end

function M.get_parent_dir(dir)
    local parts = vim.split(dir, util.sep)
    table.remove(parts)
    local parent = table.concat(parts, util.sep)
    assert(exists(parent))
    return parent
end

function M.basename(path)
    if vim.endswith(path, util.sep) then  -- strip trailing slash
        path = path:sub(1, -2)
    end
    local parts = vim.split(path, util.sep)
    return parts[#parts]
end

function M.delete(path)
    local is_symlink = uv.fs_readlink(path) ~= nil
    local flags = (M.is_dir(path) and not is_symlink) and 'rf' or ''
    local ret = vim.fn.delete(path, flags)
    assert(ret == 0)
end

function M.create_dir(path)
    assert(not exists(path), ('%q already exists'):format(path))
    -- 755 = RWX for owner, RX for group/other
    assert(uv.fs_mkdir(path, tonumber('755', 8)))
end

function M.create_file(path)
    assert(not exists(path), ('%q already exists'):format(path))
    -- 644 = RW for owner, R for group/other
    local fd = assert(uv.fs_open(path, 'w', tonumber('644', 8)))
    assert(uv.fs_close(fd))
end

function M.validate_create(input, cwd)
    assert(input, 'Empty path')
    input = util.trim_start(input)
    assert(input ~= '', 'Empty path')
    assert(input:sub(1, 1) ~= util.sep, 'Create paths must be relative')
    local path = util.join_path(cwd, input)
    assert(not exists(path), ('%q already exists'):format(path))
    local path_for_parent = vim.endswith(path, util.sep) and path:sub(1, -2) or path
    local parent = M.get_parent_dir(path_for_parent)
    assert(M.is_dir(parent), ('%q is not a directory'):format(parent))
    return path
end

function M.resolve_copy_or_move_dest(is_move, src, dest, cwd)
    assert(exists(src), ("%s doesn't exist"):format(src))
    dest = M.normalize_path(dest, cwd)
    assert(src ~= dest, '`src` equals `dest`')
    if M.is_dir(dest) then
        dest = util.join_path(dest, M.basename(src))
    end
    return dest
end

-- Mimics the semantics of `mv` / `cp -R`
function M.copy_or_move(is_move, src, dest, cwd)
    dest = M.resolve_copy_or_move_dest(is_move, src, dest, cwd)
    local op = is_move and move or M.is_dir(src) and copy_dir or copy_file
    -- Note: Moving from a file to a file should overwrite the file
    op(src, dest)
end

return M
