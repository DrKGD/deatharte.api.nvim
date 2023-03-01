--- # init
----------------
--- Internal ---
local I = { }

I.defaults	= {
	hnd	= {
		notificator = {
			-- # Configure global notificator
			static = {
				name		= 'deatharte.hnd.notificator',
				render	= 'minimal'
			},

			-- # Default keys for new notificators
			default = {
				name		= 'generic-notificator',
				timeout	= 1500
			}
		},

		tracker	= {
			-- # Which store method should be used
			store			= pcall(require, 'sqlite') and 'sqlite',

			-- # Where to store data path
			uri				= ('%s/deatharte-api/tracker.sqlite'):format(vim.fn.stdpath('data')),
		}
	},

	util = {
		which_key = pcall(require, 'which-key'),	-- # Optional dependency which-key
	},
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
