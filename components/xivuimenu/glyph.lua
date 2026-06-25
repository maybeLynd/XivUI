local GLYPH_W = setmetatable({
    [' '] = 4, ['.'] = 3, [','] = 3, ['<'] = 4, ['>'] = 4, ['/'] = 5, ['-'] = 5, ['_'] = 6, ['('] = 4, [')'] = 4,
    i = 3, l = 3, j = 4, t = 4, f = 4, r = 5, m = 10, w = 9,
    a = 6, b = 7, c = 6, d = 7, e = 6, g = 7, h = 7, k = 6, n = 7, o = 7, p = 7, q = 7, s = 6, u = 7, v = 6, x = 6, y = 6, z = 6,
    A = 8, B = 8, C = 8, D = 8, E = 7, F = 7, G = 8, H = 8, I = 4, J = 6, K = 8, L = 6, M = 11, N = 8, O = 8,
    P = 7, Q = 8, R = 8, S = 8, T = 7, U = 8, V = 8, W = 12, X = 8, Y = 8, Z = 7,
    ['0'] = 7, ['1'] = 5, ['2'] = 7, ['3'] = 7, ['4'] = 7, ['5'] = 7, ['6'] = 7, ['7'] = 6, ['8'] = 7, ['9'] = 7,
}, { __index = function() return 7 end })

local GLYPH_SCALE = 1.35

return function(s)
    local total = 0
    for i = 1, #tostring(s) do total = total + GLYPH_W[s:sub(i, i)] end
    return math.ceil(total * GLYPH_SCALE)
end
