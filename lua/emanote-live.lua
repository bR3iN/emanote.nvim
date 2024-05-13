local string = require('string')
local uv = vim.loop

local augroup_name = '__emanote-live'

local config = nil
local handle = nil
local augroup = nil

local function startswith(str, prefix)
    return string.sub(str, 1, #prefix) == prefix
end

local function removeprefix(str, prefix)
    return string.sub(str, 1 + #prefix)
end

local function removesuffix(str, prefix)
    return string.sub(str, 1, #str - #prefix)
end

local function mk_check_exit(what)
    return function(status)
        if status ~= 0 then
            error("while " .. what .. ": bad exit code " .. status)
        end
    end
end

local function shutdown_server()
    uv.spawn('curl', {
        args = {
            '-X', 'POST',
            'http://localhost:' .. config.port .. '/shutdown',
        }
    }, mk_check_exit('shutting down server'))
end

local function set_url(url)
    uv.spawn('curl', {
        args = {
            '-X', 'POST',
            'http://localhost:' .. config.port .. '/set-url',
            '--data', url
        }
    }, mk_check_exit('setting url'))
end

local function find_plugin_directory()
    local uuid_file = '.8a6f12a7-af17-422e-b8b9-32d0a9cb2f39'
    local uuid_loc = vim.api.nvim_get_runtime_file(uuid_file, false)[1]
    return vim.fs.dirname(uuid_loc)
end

local function start_server()
    print('Starting server on port ' .. config.port)
    local dir = find_plugin_directory()
    handle = uv.spawn("./start-server.sh", {
        args = {config.port, config.emanote_url},
        cwd = find_plugin_directory()
    }, function(status)
        handle = nil
        mk_check_exit('starting server')(status)
    end)
end

local function stop(wait_for_shutdown)
    if handle ~= nil then
        print('Shutting down server on port ' .. config.port)
        shutdown_server()
        handle = nil
        if wait_for_shutdown ~= nil then
            uv.sleep(wait_for_shutdown)
        end
    end
    if augroup ~= nil then
        vim.api.nvim_del_augroup_by_id(augroup)
        augroup = nil
    end
end

local function setup_autocmd()
    local cwd = vim.fn.getcwd() .. '/'
    augroup = vim.api.nvim_create_augroup(augroup_name, {})
    vim.api.nvim_create_autocmd({'BufEnter'}, {
        pattern = {cwd .. "*.md"},
        group = augroup,
        callback = function()
            local path = vim.fn.expand('%:p')
            if startswith(path, cwd) and handle ~= nil then
                local truncated = removeprefix(path, cwd)
                local base = removesuffix(truncated, '.md')
                local url = config.emanote_url .. '/' .. base .. '.html'
                set_url(url)
            end
        end,
    })
    vim.api.nvim_create_autocmd({'ExitPre'}, {
        callback = stop
    })
end

local function start(tbl)
    -- Shutdown possible previous session
    stop(500)

    config = tbl
    start_server()
    setup_autocmd()
end

return {
    start = start,
    stop = stop
}
-- vim: sw=4
