-- Minimal JSON decoder (objects, arrays, strings, numbers, booleans, null), used for settings.json.
local skip, value

skip = function(s, i) return s:find("%S", i) or #s + 1 end

local escapes = { b = "\b", f = "\f", n = "\n", r = "\r", t = "\t" }
local function str(s, i)
    assert(s:sub(i, i) == '"', "expected string at " .. i)
    local out, j = {}, i + 1
    while true do
        local c = s:sub(j, j)
        if c == "" then error("unterminated string") end
        if c == '"' then return table.concat(out), j + 1 end
        if c == "\\" then
            local e = s:sub(j + 1, j + 1)
            if e == "u" then out[#out + 1] = utf8.char(tonumber(s:sub(j + 2, j + 5), 16)); j = j + 6
            else out[#out + 1] = escapes[e] or e; j = j + 2 end
        else
            out[#out + 1] = c; j = j + 1
        end
    end
end

value = function(s, i)
    i = skip(s, i)
    local c = s:sub(i, i)
    if c == "{" or c == "[" then
        local obj, close, t = c == "{", c == "{" and "}" or "]", {}
        i = skip(s, i + 1)
        if s:sub(i, i) == close then return t, i + 1 end
        while true do
            if obj then
                local k
                k, i = str(s, skip(s, i))
                i = skip(s, i)
                assert(s:sub(i, i) == ":", "expected : at " .. i)
                t[k], i = value(s, i + 1)
            else
                t[#t + 1], i = value(s, i)
            end
            i = skip(s, i)
            c = s:sub(i, i)
            if c == close then return t, i + 1 end
            assert(c == ",", "expected , at " .. i)
            i = i + 1
        end
    elseif c == '"' then return str(s, i)
    elseif s:sub(i, i + 3) == "true" then return true, i + 4
    elseif s:sub(i, i + 4) == "false" then return false, i + 5
    elseif s:sub(i, i + 3) == "null" then return nil, i + 4
    end
    local num = s:match("^-?[%d%.eE+-]+", i)
    assert(num, "unexpected character at " .. i)
    return tonumber(num), i + #num
end

return { decode = function(s) return (value(s, 1)) end }
