local M = {}

function M.set_path(img, path)
    if img and img._xivui_path ~= path then
        img:path(path)
        img._xivui_path = path
    end
end

function M.set_path_fit(img, path)
    if img and img._xivui_path ~= path then
        img:path(path)
        img:fit(true)
        img._xivui_path = path
    end
end

return M
