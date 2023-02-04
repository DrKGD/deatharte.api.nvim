--- # deatharte.util.pkgs

local M = { }
----------------
---   API    ---

local checklup = {
	['binary'] = function(name)
		return ( vim.fn.executable(name) == 1 )
	end,

	['package']	= function(name)
		local ok, _ = pcall(require, name)
		return ok
	end,
}

-- # Returns which dependencies are missing, either plugins or binaries
-- e.g. 'plenary.job'
-- e.g. 'lualatex'
--
-- Accepts the following formats
-- { { 'name', ... } ... }, which is treated as a package
-- { { 'name', type = 'package' ... }, ... }
-- { { name = 'name', type = 'binary' ... }, ... }
-- { { binary = 'name', ... }, ... }
-- { { package = 'name', ... }, ... }
--
-- All the other fields are kept for advanced uses
M.missingdeps = function(dependencies)
	if not dependencies then
		return true end

	local _unsatisfied = { }

	for _, dep in ipairs(dependencies) do
		local name		= dep[1] or dep.package or dep.binary or dep.name
		local dtype = dep.type
			or (dep.binary and 'binary')
			or (dep.package and 'package')
			or 'package'

		local method	= checklup[dtype]
		if name and not method(name) then
			local entry = vim.deepcopy(dep)
				entry.name = name
				entry.type = dtype

			_unsatisfied[#_unsatisfied + 1] = entry
		end
	end

	return (#_unsatisfied > 0 and _unsatisfied) or nil
end

---   API    ---
----------------
return M
