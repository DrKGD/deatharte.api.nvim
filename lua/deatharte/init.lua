--- # init
----------------
--- Internal ---
local I = { }

I.defaults	= {
	deps = {
		which_key = pcall(require, 'which-key'),	-- # Optional dependency which-key
		sqlite		= pcall(require, 'sqlite')			-- # Optional dependency sqlite
	}
}

I.config		= false

--- Internal ---
----------------

local M = { }
----------------
---   API    ---

M.fetch_configuration = function()
	if not I.config then
		return I.defaults
	else return I.config end
end

M.setup = function(opts)
	I.config = vim.tbl_deep_extend("force", I.defaults, opts or { })
end

---   API    ---
----------------
return M
