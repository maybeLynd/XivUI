
local classes = {}

classes.Object = {}
classes.Object.class = classes.Object

function classes.Object:init(...)
end

function classes.Object.alloc(mastertable)
    return setmetatable({}, {__index = classes.Object, __newindex = mastertable})
end

function classes.Object.new(...)
    return classes.Object.alloc({}):init(...)
end

function classes.Object:instanceOf(class)

    if self.class == class then
        return true
    end
    if self.super then
        return self.super.__base:instanceOf(class)
    end
    return false
end

function classes.class(baseclass)

    local classdef = {}

    baseclass = baseclass or classes.Object

    setmetatable(classdef, {__index = baseclass})

    classdef.class = classdef

    local function lookup(t, k, rootInstance, fromSuper)

        local val = rawget(rootInstance, k)
        if val ~= nil then return val end

        local current
        if fromSuper then
            current = rawget(t, '__base')
        else
            current = rootInstance
        end
        repeat
            val = rawget(current.class, k)
            if val ~= nil then
                if type(val) == 'function' and val ~= classes.Object.instanceOf then

                    return function(tt, ...)
                        return val(current, ...)
                    end
                else
                    return val
                end
            end

            if current.super then
                current = rawget(current.super, '__base')
            else
                current = nil
            end
        until val ~= nil or current == nil
    end

    function classdef.alloc(rootInstance)
        local instance = {
            class = classdef,
            super = { __base = baseclass.alloc(rootInstance) }
        }

        setmetatable(instance.super, {__index = function(t, k) return lookup(t, k, rootInstance, true) end, __newindex = rootInstance})
        setmetatable(instance, {__index = function(t, k) return lookup(t, k, rootInstance, false) end, __newindex = rootInstance})

        return instance
    end

    function classdef.new(...)

        local instance = {}
        instance.class = classdef

        instance.super = { __base = baseclass.alloc(instance) }

        setmetatable(instance.super, { __index = function(t, k) return lookup(t, k, instance, true) end })
        setmetatable(instance, {__index = function(t, k) return lookup(t, k, instance, false) end})

        instance:init(...)

        return instance
    end

    return classdef
end

return classes
