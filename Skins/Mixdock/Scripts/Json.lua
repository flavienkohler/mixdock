-- Json.lua: minimal JSON decoder (objects, arrays, strings, numbers, booleans, null).
-- Enough for the helper's state file; it does not validate strictly.

local Json = {}

local escapes = { ['"'] = '"', ['\\'] = '\\', ['/'] = '/', b = '\b', f = '\f', n = '\n', r = '\r', t = '\t' }

local function skip(s, i)
  return s:find('[^ \t\r\n]', i) or #s + 1
end

-- Lua 5.1 has no utf8.char.
local function utf8char(cp)
  if cp < 0x80 then
    return string.char(cp)
  elseif cp < 0x800 then
    return string.char(0xC0 + math.floor(cp / 64), 0x80 + cp % 64)
  end
  return string.char(0xE0 + math.floor(cp / 4096), 0x80 + math.floor(cp / 64) % 64, 0x80 + cp % 64)
end

local function parseString(s, i)
  local buf, j = {}, i + 1
  while true do
    local c = s:sub(j, j)
    if c == '"' then
      return table.concat(buf), j + 1
    elseif c == '\\' then
      local e = s:sub(j + 1, j + 1)
      if e == 'u' then
        buf[#buf + 1] = utf8char(tonumber(s:sub(j + 2, j + 5), 16) or 63)
        j = j + 6
      else
        buf[#buf + 1] = escapes[e] or e
        j = j + 2
      end
    elseif c == '' then
      error('unterminated string')
    else
      buf[#buf + 1] = c
      j = j + 1
    end
  end
end

local parseValue

local function parseContainer(s, i, close, isObject)
  local result = {}
  i = skip(s, i + 1)
  if s:sub(i, i) == close then return result, i + 1 end
  while true do
    local key
    if isObject then
      key, i = parseString(s, skip(s, i))
      i = skip(s, i)
      if s:sub(i, i) ~= ':' then error('expected ":" at ' .. i) end
      i = i + 1
    end
    local value
    value, i = parseValue(s, i)
    if isObject then result[key] = value else result[#result + 1] = value end
    i = skip(s, i)
    local d = s:sub(i, i)
    i = i + 1
    if d == close then return result, i end
    if d ~= ',' then error('expected "," or "' .. close .. '" at ' .. (i - 1)) end
    i = skip(s, i)
  end
end

parseValue = function(s, i)
  i = skip(s, i)
  local c = s:sub(i, i)
  if c == '{' then
    return parseContainer(s, i, '}', true)
  elseif c == '[' then
    return parseContainer(s, i, ']', false)
  elseif c == '"' then
    return parseString(s, i)
  elseif s:sub(i, i + 3) == 'true' then
    return true, i + 4
  elseif s:sub(i, i + 4) == 'false' then
    return false, i + 5
  elseif s:sub(i, i + 3) == 'null' then
    return nil, i + 4
  end
  local number = s:match('^-?%d+%.?%d*[eE]?[+-]?%d*', i)
  if not number then error('unexpected character at ' .. i) end
  return tonumber(number), i + #number
end

function Json.decode(s)
  return (parseValue(s, 1))
end

return Json
