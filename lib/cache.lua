local M = {}

local ROOT = windower.addon_path .. 'cache'

local ensured = {}
local function ensure(component)
    if ensured[component] then return end
    pcall(windower.create_dir, ROOT)
    if component and component ~= '' then
        pcall(windower.create_dir, ROOT .. '/' .. component)
    end
    ensured[component] = true
end

function M.path(component, filename)
    component = component or ''
    ensure(component)
    local dir = (component ~= '') and (ROOT .. '/' .. component) or ROOT
    return dir .. '/' .. filename
end

return M
