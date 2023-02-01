--- # prochandler
----------------
---   Deps   ---

local hasplenary, job = pcall(require, 'plenary.job') -- # Requires nvim-lua/plenary
if not hasplenary then
	error('deatharte.jobs.prochandler is missing the required dependency ‹plenary.nvim›') end

---   Deps   ---
----------------
--- Internal ---
local I = { }

-- # Kill given pid, return if it was successful
-- https://github.com/nvim-lua/plenary.nvim/pull/406
-- OPTIMIZE: As the plenary shutdown hangs for 1000ms and does
--  not really terminate the process?
I.pkill = function(pid)
	local ji = job:new {
		command = 'kill',
		args = {
			"-15",
			tostring(pid)
		},
	}

	ji:sync()
	return ji.code == 0
end

-- # Check if given pid is currently alive
I.palive = function(pid)
	local ji = job:new {
		command = 'kill',
		args = {
			"-0",
			tostring(pid)
		},
	}

	ji:sync()
	return ji.code == 0
end

-- # Available fields 
-- (https://github.com/nvim-lua/plenary.nvim/blob/revert-426-async-testing/lua/plenary/job.lua)

-- # Specify callbacks as a list
-- { callback = function(args), condition = true / function }
-- WARNING: Do not use obj._job as it may be inconsistent for its async nature!
I.run_callbacks = function(obj, list, bypass)
	return function(...)
		local store = { }
		local args = { ... }
			args[#args+1] = obj
			args[#args+1] = store

		for _, ck in ipairs(list or { }) do
			if bypass or obj.callbacks or (type(ck) == 'table' and ck.bypass) then
				local tpcall = (type(ck) == 'function' and ck)
					or ck.callback or ck[1]

				local tpcond = (type(ck) == 'table' and ck.condition and type(ck.condition)) or nil
				if tpcond == nil
					or ( tpcond == 'boolean' and tpcond)
					or ( tpcond == 'function' and ck.condition(unpack(args))) then

					if type(tpcall) == 'function' then
						tpcall(unpack(args))
					end
				end
			end
		end
	end
end

-- jobinfo, exit_code, signal [[ obj ]]
local default_badexit = function(jobinfo, exit_code, _, obj)
	local output_tbl =
		(#jobinfo._stderr_results > 0 ) and jobinfo._stderr_results
		or (#jobinfo._stdout_results > 0 ) and jobinfo._stdout_results
		or { ("Job did not exit gracefully (exit code %s)"):format(exit_code and tostring(exit_code) or "?") }

	local message = table.concat(output_tbl, '\n')
	obj.notify:warn(message)
end

local default_zeroexit = function(_, _, _, obj)
	obj.notify:info(('‹%s› exited!'):format(obj.name))
end


I.default_onexit = {
	{ condition = function(_, exit_code) return exit_code ~= 0 end, callback = default_badexit },
	{ condition = function(_, exit_code) return exit_code == 0 end, callback = default_zeroexit }
}

-- jobinfo, [[ obj ]]
local default_onstart = function(_, obj)
	obj.notify:info(('‹%s› started!'):format(obj.name))
end

I.default_onstart = {
	{ condition = true, callback = default_onstart }
}

-- error, data, jobinfo, [[ obj ]]
local default_onstdout = function(_, _, _, obj)
	obj.notify:info(('new output from ‹%s›'):format(obj.name))
end

I.default_onstdout = {
	{ condition = true, callback = default_onstdout }
}

-- error, data, jobinfo, [[ obj ]]
local default_onstderr = function(_, _, _, obj)
	obj.notify:warn(('error in ‹%s›'):format(obj.name))
end

I.default_onstderr = {
	{ condition = true, callback = default_onstderr }
}

function I.jobinfo(ph)
	local args = { }
		args.command					= ph.command
		args.cwd							= ph.cwd
		args.args							= ph.args
		args.env							= ph.env

		-- # Map events
		args.detached					= ph.detached

		-- # Setup callbacks
		args.on_exit					= I.run_callbacks(ph, ph.on_exit or I.default_onexit)
		args.on_start					= I.run_callbacks(ph, ph.on_start or I.default_onstart)
		args.on_stdout				= I.run_callbacks(ph, ph.on_stdout or I.default_onstdout)
		args.on_stderr				= I.run_callbacks(ph, ph.on_stderr or I.default_onstderr)

	return args
end


-- # Setup an event to kill the process on exit
local prochandler_augroup = vim.api.nvim_create_augroup('setup.prochandler', { clear = true })

I.kill_onexit = function(obj)
	vim.api.nvim_create_autocmd({ "VimLeavePre" }, {
		group = prochandler_augroup,
		callback = function()
			obj:kill(true)
		end
	})
end

--- Internal ---
----------------

local prochandler = { }
prochandler.__index = prochandler


----------------
---   API    ---

-- # Describe a new process
function prochandler.new(opts)
	if type(opts) ~= 'table'
		then error('prochandler.new: expecting a table as function input') end

	if not opts.command
		then error('prochandler.new: missing required command') end

	if vim.fn.executable(opts.command) == 0
		then error(('prochandler.new: command ‹%s› not available, ensure it is installed and it is spelt correctly!'):format(opts.command)) end

	local ix = setmetatable({ }, prochandler)
		ix._init		= vim.deepcopy(opts or {})
		ix.command	= opts.command
		ix.cwd			= opts.cwd
		ix.args			= opts.args

		-- # For debugging
		ix.name			= opts.name or 'unnamed-proc'
		ix.notify		= require('deatharte.hnd.notificator').new({
			plugin = ('deatharte.jobs.%s'):format(ix.name),
			title = ('Job %s'):format(ix.name)
		})

		-- # Should use callbacks at startup
		ix.callbacks					= not opts.no_callbacks

		-- # More custom callbacks, always bypass callbacks respawn
		ix.on_respawn					= opts.on_respawn and I.run_callbacks(ix, opts.on_respawn, true)
		ix.on_kill						= opts.on_kill and I.run_callbacks(ix, opts.on_kill, true)
		ix.on_status_update		= opts.on_status_update and I.run_callbacks(ix, opts.on_status_update, true)

		-- # Default, plenary-handled, events
		ix.on_exit						= ( type(opts.on_exit) == 'boolean' and not opts.on_exit and { } ) or opts.on_exit
		ix.on_stderr					= ( type(opts.on_stderr) == 'boolean' and not opts.on_stderr and { } ) or opts.on_stderr
		ix.on_stdout					= ( type(opts.on_stdout) == 'boolean' and not opts.on_stdout and { } ) or opts.on_stdout
		ix.on_start						= ( type(opts.on_start) == 'boolean' and not opts.on_start and { } ) or opts.on_start

		-- # Detach from nvim process
		ix.detached						= opts.detached or false

		-- # Kill on exit
		ix.persist_onexit			= opts.persist_onexit or false
		if not ix.persist_onexit then
			I.kill_onexit(ix) end

	return ix
end


-- # Kill by pid
local function _isalive(pid)
	return pid and I.palive(pid)
end

-- # Check if process is alive
-- FIX: Cannot entirely trust a variable, as anything 
--  can happen during the process startup
function prochandler:alive() return _isalive(self._job and self._job.pid)
end

-- # Starts the process 
function prochandler:start(skip)
	if not skip and self:alive() then
		return end

	self._job = job:new(I.jobinfo(self))
	self._job:start()

	return true
end

-- # Kill by pid
local function _kill(pid)
	return pid and I.pkill(pid)
end

-- # Kills the process
function prochandler:kill(noevent)
	-- Check if alive
	if not self:alive() then
		return false end

	-- Kill the pid
	if not _kill(self._job and self._job.pid) then
		self.notify:warn(("Could not kill the prochandler for ‹%s›!"):format(self.name))
		return false
	end

	-- # Call kill_callbacks if so defined
	if self.on_kill and not noevent
		then self.on_kill() end

	return true
end

-- # Spawn or Kill the process
-- ... I could not come up with a better function name
-- but basically
-- - If process is alive, kills it
-- - If process is dead, spawns it
function prochandler:spawn_or_kill()
	if not self:alive() then
		self:start(true)
	else self:kill() end
end

-- # Respawn the process
function prochandler:respawn()
	local status = self.callbacks

	-- Stop callbacks to prevent futile notification spam
	self:block_callbacks()
	local was_killed = self:kill(true)

	-- # If it was not killed then resume callbacks
	if not was_killed
		then self.callbacks = status

	-- # Restart callbacks if specified so
	elseif self.on_respawn
		then self.on_respawn() end

	self:start(true)

	-- Ensure callbacks were resumed
	self.callbacks = status
end

-- # Set handlers 
function prochandler:set_callbacks(new_state)
	local updated = (self.callbacks ~= new_state)
	self.callbacks = new_state

	if updated and self.on_status_update
		then self.on_status_update(self.callbacks) end
end

-- # Disable handlers
function prochandler:block_callbacks()
	self:set_callbacks(false)
end

-- # Enable handlers
function prochandler:resume_callbacks()
	self:set_callbacks(true)
end

-- # Toggle handlers 
function prochandler:toggle_callbacks()
	self:set_callbacks(not self.callbacks)
end

-- # Callbacks are being fired
function prochandler:status()
	return self.callbacks
end

---   API    ---
----------------
return prochandler
