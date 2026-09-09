local _, DP = ...
DP.Parser = {}

function DP.Parser.Countdown(format, text)
    if type(format) ~= "string" or type(text) ~= "string" then return nil end
    local prefix, suffix = format:match("^(.-)%%d(.-)$")
    if not prefix then prefix, suffix = format:match("^(.-)%%1%$d(.-)$") end
    if not prefix or prefix:find("%%") or suffix:find("%%") then return nil end
    local function escape(value)
        return (value:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1"))
    end
    local seconds = tonumber(text:match("^" .. escape(prefix) .. "(%d+)" .. escape(suffix) .. "$"))
    if seconds and seconds >= 1 and seconds <= 10 then return seconds end
end

-- Compile only supported string placeholders. Locale formats may reorder arguments.
function DP.Parser.Compile(format)
    if type(format) ~= "string" or format == "" then return nil end
    local pattern, order, i, nextArgument = {"^"}, {}, 1, 1
    while i <= #format do
        local c = format:sub(i, i)
        if c == "%" then
            local tail = format:sub(i)
            local position = tail:match("^%%(%d+)%$s")
            if position then
                order[#order + 1] = tonumber(position)
                pattern[#pattern + 1] = "(.+)"
                i = i + #position + 3
            elseif tail:sub(1, 2) == "%s" then
                order[#order + 1] = nextArgument
                nextArgument = nextArgument + 1
                pattern[#pattern + 1] = "(.+)"
                i = i + 2
            elseif tail:sub(1, 2) == "%%" then
                pattern[#pattern + 1] = "%%"
                i = i + 2
            else
                return nil
            end
        else
            pattern[#pattern + 1] = c:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
            i = i + 1
        end
    end
    if #order ~= 2 or order[1] == order[2] or
        not ((order[1] == 1 or order[1] == 2) and (order[2] == 1 or order[2] == 2)) then
        return nil
    end
    pattern[#pattern + 1] = "$"
    return {pattern = table.concat(pattern), order = order}
end

function DP.Parser.Match(compiled, text)
    if not compiled or type(text) ~= "string" then return nil end
    local a, b = text:match(compiled.pattern)
    if not a or not b then return nil end
    if a:find("[%s|]") or b:find("[%s|]") then return nil end
    local args = {}
    args[compiled.order[1]], args[compiled.order[2]] = a, b
    return args[1], args[2]
end

function DP.Parser.SameName(a, b)
    if type(a) ~= "string" or type(b) ~= "string" then return false end
    if a == b then return true end
    -- A missing realm is possible in system messages. This is name evidence only.
    if a:find("-", 1, true) and b:find("-", 1, true) then return false end
    return a:match("^[^-]+") == b:match("^[^-]+")
end
