--- # deatharte.util.string

local M = { }
----------------
---   API    ---

-- # UTF8 string length
-- THANKS: http://lua-users.org/wiki/LuaUnicode
M.utf8len = function(str)
	local _, c = str:gsub("[^\128-\193]", "");
	return c
end

-- Count occurences of string
M.count = function(str, to_count)
	local _, count = str:gsub(to_count, '')
	return count
end

---   API    ---
----------------
return M
