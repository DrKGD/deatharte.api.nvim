--- # deatharte.util.pkgs

local M = { }
----------------
---   API    ---

-- # Returns which dependencies are missing
-- e.g. 'plenary.job'
--
-- Accepts the following formats
-- { { package = 'name' }, ... }
-- { { 'name' }, ... }
-- { 'name' }
-- Returns a list of unsatisfiedd dependencies
M.missingdeps = function(dependencies)
	if not dependencies then
		return true end

	local _unsatisfied = { }

	for _, dep in ipairs(dependencies) do
		local name = (type(dep) == 'string' and dep)
			or dep.package or dep[1]
		local ok, _ = pcall(require, name)

		if not ok then
			_unsatisfied[#_unsatisfied + 1] = dep end
	end

	return (#_unsatisfied > 0 and _unsatisfied) or nil
end

---   API    ---
----------------
return M
