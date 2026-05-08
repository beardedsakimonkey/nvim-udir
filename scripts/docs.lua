local readme_path = 'README.md'
local config_path = 'lua/udir.lua'
local start_marker = '<!-- udir-config:start -->'
local end_marker = '<!-- udir-config:end -->'

local function read_file(path)
    local fd = assert(io.open(path, 'r'))
    local contents = assert(fd:read('*a'))
    assert(fd:close())
    return contents
end

local function write_file(path, contents)
    local fd = assert(io.open(path, 'w'))
    assert(fd:write(contents))
    assert(fd:close())
end

local function split_lines(contents)
    local lines = {}
    for line in (contents .. '\n'):gmatch('(.-)\n') do
        lines[#lines+1] = line
    end
    return lines
end

local function brace_delta(line)
    local _, opens = line:gsub('{', '')
    local _, closes = line:gsub('}', '')
    return opens - closes
end

local function extract_config_block(contents)
    local lines = split_lines(contents)
    local block = {}
    local depth

    for _, line in ipairs(lines) do
        if not depth then
            if line:match('^M%.config%s*=%s*{') then
                block[#block+1] = line:gsub('^M%.config', 'config', 1)
                depth = brace_delta(line)
            end
        else
            block[#block+1] = line
            depth = depth + brace_delta(line)
            if depth == 0 then
                return table.concat(block, '\n')
            end
        end
    end

    error('could not find M.config block in ' .. config_path)
end

local function generate_config_section()
    return table.concat({
        '```lua',
        extract_config_block(read_file(config_path)),
        '```',
    }, '\n')
end

local function replace_config_section(readme, generated)
    local start_at, start_end = readme:find(start_marker, 1, true)
    assert(start_at, 'missing ' .. start_marker)
    local end_at, end_end = readme:find(end_marker, start_end + 1, true)
    assert(end_at, 'missing ' .. end_marker)
    return table.concat({
        readme:sub(1, start_end),
        '\n',
        generated,
        '\n',
        readme:sub(end_at, end_end),
        readme:sub(end_end + 1),
    })
end

local generated = generate_config_section()
local readme = read_file(readme_path)
local updated = replace_config_section(readme, generated)

if vim.env.UDIR_DOCS_CHECK == '1' then
    if updated ~= readme then
        error(readme_path .. ' config block is stale. Run: sh scripts/docs.sh')
    end
else
    write_file(readme_path, updated)
end
