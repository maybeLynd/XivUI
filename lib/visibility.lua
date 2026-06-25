local V = {}
V.__index = V

function V.new()
    return setmetatable({ _hidden = false, _preview = false }, V)
end

function V:show()    self._hidden = false end
function V:hide()    self._hidden = true end
function V:preview(on) self._preview = on and true or false end

function V:hidden()     return self._hidden end
function V:previewing() return self._preview end
function V:visible()    return (not self._hidden) or self._preview end
function V:skip()       return self._hidden and not self._preview end

return V
