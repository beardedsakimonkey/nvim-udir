local util = require'udir.util'
local uv = vim.loop

local M = {}

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
    for name, type in vim.fs.dir(src) do
        local copy = type == 'directory' and copy_dir or copy_file
        copy(util.join_path(src, name), util.join_path(dest, name))
    end
end

local function exists(path)
    return (uv.fs_access(path, ''))
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
    for basename, type in vim.fs.dir(path) do
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

-- Uses the semantics of `mv` / `cp -R`
function M.copy_or_move(is_move, src, dest, cwd)
    assert(exists(src), ("%s doesn't exist"):format(src))
    assert(dest, 'Empty destination')
    -- Trim `dest` because we'll check its first character
    dest = util.trim_start(dest)
    -- Expand tilde
    dest = dest:gsub('^~', os.getenv'HOME')
    -- Make absolute
    dest = dest:sub(1, 1) == '/' and dest or util.join_path(cwd, dest)
    assert(src ~= dest, '`src` equals `dest`')
    local op = is_move and move or M.is_dir(src) and copy_dir or copy_file
    -- Moving to an existing dir should move to a subdirectory
    if M.is_dir(dest) then
        dest = util.join_path(dest, M.basename(src))
    end
    -- Note: Moving from a file to a file should overwrite the file
    op(src, dest)
end

return M
