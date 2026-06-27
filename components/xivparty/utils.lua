require('strings')

local utils = {}

utils.level = 5

function utils:colorFromHex(hexString)
    local length = string.length(hexString)
    if length == 0 then return nil end

    if not string.startswith(hexString, '#') or length < 7 or length > 9 then
        utils:log('Invalid hexadecimal color code. Expected format #RRGGBB or #RRGGBBAA', 4)
        return nil
    end

    local color = {}
    color.r = tonumber(string.slice(hexString, 2, 3), 16)
    color.g = tonumber(string.slice(hexString, 4, 5), 16)
    color.b = tonumber(string.slice(hexString, 6, 7), 16)
    if length > 7 then
        color.a = tonumber(string.slice(hexString, 8, 9), 16)
    else
        color.a = 255
    end

    return color
end

function utils:coord(coordList)
    local coord = {}

    if coordList then
        coord.x = tonumber(coordList[1])
        coord.y = tonumber(coordList[2])
    end

    if not coord.x then coord.x = 0 end
    if not coord.y then coord.y = 0 end

    return coord
end

function utils:round(num, numDecimalPlaces)
    if numDecimalPlaces and numDecimalPlaces > 0 then
        local mult = 10^numDecimalPlaces
        return math.floor(num * mult + 0.5) / mult
    end

    return math.floor(num + 0.5)
end

function utils:all(list, func)
    if not func then func = function(x) return x end end

    local result = false
    local first = true
    for k, v in pairs(list) do
        if first then
            first = false
            result = func(v)
        else
            result = result and func(v)
        end
    end
    return result
end

function utils:any(list, func)
    if not func then func = function(x) return x end end

    local result = false
    for k, v in pairs(list) do
        result = result or func(v)
        if result then return result end
    end
    return result
end

function utils:insertionSort(array, func)
    local len = #array
    for j = 2, len do
        local key = array[j]
        local i = j - 1
        while i > 0 and func(array[i], key) do
            array[i + 1] = array[i]
            i = i - 1
        end
        array[i + 1] = key
    end
    return array
end

function utils:log(text, level)
    if level == nil then
        level = 2
    end

    if self.level <= level and text then
        windower.add_to_chat(8, text)
    end
end

function utils:toString(obj)
    if obj then
        return tostring(obj)
    end
    return '???'
end

function utils:logTable(t, depth)
    if not depth then
        depth = 0
    end

    local indent = ''
    for i = 0, depth, 1 do
        indent = indent .. ' '
    end

    if type(t) == 'table' then
        for key,value in pairs(t) do
            if type(value) == 'table' then
                windower.add_to_chat(8, indent .. key)
            elseif key ~= '_raw' and key ~= '_data' then
                windower.add_to_chat(8, indent .. key .. ' = ' .. tostring(value) .. '(' .. type(value) .. ')')
            end
            utils:logTable(value, depth + 3)
        end
    end
end

function utils:bitAnd(a,b)
    local p,c=1,0
    while a>0 and b>0 do
        local ra,rb=a%2,b%2
        if ra+rb>1 then c=c+p end
        a,b,p=(a-ra)/2,(b-rb)/2,p*2
    end
    return c
end

function utils:bitOr(a,b)
    local p,c=1,0
    while a+b>0 do
        local ra,rb=a%2,b%2
        if ra+rb>0 then c=c+p end
        a,b,p=(a-ra)/2,(b-rb)/2,p*2
    end
    return c
end

function utils:bitNot(n)
    local p,c=1,0
    while n>0 do
        local r=n%2
        if r<1 then c=c+p end
        n,p=(n-r)/2,p*2
    end
    return c
end

return utils
