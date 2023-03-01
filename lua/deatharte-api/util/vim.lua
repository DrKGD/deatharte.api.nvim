--- # deatharte.util.vim
-- Vim related functionalities

--- Internal ---
----------------

local M = { }
----------------
---   API    ---

local kb_lhs = function(kbd, opts)
	return ('%s%s%s'):format(opts.key_leader_prefix or '', opts.key_prefix or '', kbd[1] or kbd.lhs)
end

-- # Setup keybindings
M.setup_keybindings = function(keylist, opts)
	for _, kbd in ipairs(keylist) do
		local lhs = kb_lhs(kbd, opts)
		local rhs = (kbd[2] or kbd.rhs)
		local modes = kbd.mode or { 'n' }

		for _, mode in ipairs(modes) do
			vim.keymap.set(mode, lhs, rhs, { remap = true, silent = true, desc = kbd.description })
		end
	end
end

-- # Return command name with first letter capitlized
local uc_name = function(cmd, opts)
	local defname = ('%s%s'):format(opts.cmd_leader_prefix or '', cmd.name or cmd[1])
	return defname:sub(1, 1):upper() .. defname:sub(2)
end

-- # Setup user command
M.setup_usercommands = function(commandlist, opts)
	for _, cmd in ipairs(commandlist) do
		local name			= uc_name(cmd, opts)
		local lambda		= (cmd.lambda or cmd[2])
		local callopts	= cmd.opts or cmd.callopts or cmd[3] or { nargs = 0 }

		-- # Set command
		vim.api.nvim_create_user_command(name, lambda, callopts)
	end
end

M.delete_keybindings = function(keylist, opts)
	for _, kbd in ipairs(keylist) do
		local lhs = kb_lhs(kbd, opts)
		local modes = kbd.mode or { 'n' }

		vim.keymap.del(modes, lhs, { })
	end
end

-- # Delete user commands
M.delete_usercommands = function(commandlist, opts)
	for _, cmd in ipairs(commandlist) do
		local name			= uc_name(cmd, opts)
		vim.api.nvim_del_user_command(name)
	end
end

---   API    ---
----------------
return M
