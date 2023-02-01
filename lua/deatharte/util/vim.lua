--- # deatharte.util.vim
-- Vim related functionalities

-- # Use which-key
local config = require('deatharte').fetch_configuration()
local has_whichkey, wk = pcall(require, 'which-key')
if config and config.deps.which_key and not has_whichkey then
	error('deatharte.util.vim: optional dependency ‹which-key› is not available, but the setup requires so!')
end

--- Internal ---
----------------

local M = { }
----------------
---   API    ---

-- # Setup keybindings
-- TODO: Which-key integration
M.setup_keybindings = function(keylist, opts)
	for _, kbd in ipairs(keylist) do
		local lhs = (kbd[1] or kbd.lhs):format(opts.key_absolute_prefix or '', opts.key_prefix or '')
		local rhs = (kbd[2] or kbd.rhs)
		local modes = kbd.mode or { 'n' }

		local description = kbd.description

		for _, mode in ipairs(modes) do
			vim.keymap.set(mode, lhs, rhs, { remap = true, silent = true })
		end
	end
end

-- # Setup user command
M.setup_usercommands = function(commandlist, opts)
	for _, cmd in ipairs(commandlist) do
		local defname		= opts.name:sub(1, 1):upper() .. opts.name:sub(2)
		local name			= (cmd[1] or cmd.name):format(defname)
		local lambda		= (cmd[2] or cmd.lambda)
		local callopts	= cmd[3] or cmd.opts or cmd.callopts or { nargs = 0 }

		vim.api.nvim_create_user_command(name, lambda, callopts)
	end
end

---   API    ---
----------------
return M
