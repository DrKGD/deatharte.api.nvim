--- # inotifywait
----------------
---   Deps   ---

if not vim.fn.executable('inotifywait') == 0 then
	error('jobs.builtin.inotifywait: binary ‹inotifywait› was not found!')
end

local prochandler = require('deatharte.jobs.prochandler')

---   Deps   ---
----------------
--- Internal ---
local I = { }

local process_output = function(raw)
	local evs , file = raw:match('{(.+)}{(.+)}')
	local evlist = { }
	for e in string.gmatch(evs, '[^;]+')  do
		evlist[e] = true
	end

	return { evlist = evlist, evsraw = evs, file = file }
end

local store_output = function(_, output, _, _, store)
	store.output = process_output(output)
end

local debug_output = function(_, _, _, obj, store)
	obj.notify(('‹%s› event%s for file ‹%s›')
		:format(store.output.evsraw, #store.output.evlist > 1 and 's' or '', store.output.file), 'info')
end

I.required_onstdout = {
	{ condition = function(error) return not error end, callback = store_output }
}

I.default_onstdout = {
	{ condition = function(error) return not error end, callback = debug_output }
}

I.permanent = {
	command = 'inotifywait',
	name		= 'inotifywait@%s',
	args		= {
		'--monitor',
		'--quiet',
		'--recursive',
		'--format', '{%;e}{%w%f}',
	},

	on_stdout	= I.required_onstdout,

	-- I don't think it is possible to store
	--  and restore a plenary.job object
	persist_onexit = false,
}


-- # TODO: Replace with a string builder
local replace_special = function(tbl)
	if not tbl or #tbl == 0
		then return end

	for ix, entry in ipairs(tbl or { }) do
		tbl[ix] = entry:gsub('%.', [[\.]])
	end

	return true
end

local posixrgx_ft = function(_in)
	return replace_special(_in)
		and ([[.*\.(%s)]]):format(table.concat(_in, '|'))
end

local posixrgx_dir = function(_in)
	return replace_special(_in)
		and ([[.*(%s)\/.*]]):format(table.concat(_in, '|'))
end

local posixrgx_filename = function(_in)
	return replace_special(_in)
		and ([[.*(%s)]]):format(table.concat(_in, '|'))
end

I.regexes = function(filter)
	local rgx = { }
		rgx[#rgx+1] = posixrgx_ft(filter.extension)
		rgx[#rgx+1] = posixrgx_dir(filter.dirname)
		rgx[#rgx+1] = posixrgx_filename(filter.filename)

	return rgx
end

I.types = {
	blacklist = '--exclude',
	whitelist = '--include'
}

-- # Exclude problematic patterns from detection
-- Such as node_modules or temporary files
--  to prevent update storm
-- May be configured as a blacklist or as a whitelist
I.filter_events = function(args, filter)
	if not filter
		then return end

	-- # Could not retrieve any valid regex
	local regexes = I.regexes(filter)
	if #regexes == 0 then return end

	-- # Retrieve filter type
	local type =
		I.types[filter.type and filter.type:lower()] or I.types.blacklist

	-- # Regex
	for ix, rgx in ipairs(regexes) do
		regexes[ix] = ('(%s)'):format(rgx) end

	args[#args+1] = type
	args[#args+1] = table.concat(regexes, '|')
end

-- # Available events
I.EVENTS = {
 ACCESS					= "access",
 MODIFY 				= "modify",
 ATTRIB 				= "attrib",
 CLOSE_WRITE		= "close_write",
 CLOSE_NOWRITE	= "close_nowrite",
 CLOSE					= "close",
 OPEN						= "open",
 MOVED_TO				= "moved_to",
 MOVED_FROM			= "moved_from",
 MOVE						= "move",
 MOVE_SELF			= "move_self",
 CREATE					= "create",
 DELETE 				= "delete",
 DELETE_SELF		= "delete_self",
 UNMOUNT				= "unmount"
}

I.events		= function(args, evs)
	if not evs then return end
	if type(evs) == 'string' then evs = { evs } end
	if type(evs) ~= 'table'	then error("inotifywait:events, unrecognised type for evlist!") end

	local evlist = { }
	for ix, entry in ipairs(evs) do
		evlist[ix] = I.EVENTS[entry:upper()] or
			error(('inotifywait:events, %s not a valid event!'):format(entry))
	end

	args[#args+1] = '--event'
	args[#args+1] = table.concat(evlist, ',')
end

--- Internal ---
----------------

local inotifywait = { }
inotifywait.__index = inotifywait
setmetatable(inotifywait, prochandler)

----------------
---   API    ---

function inotifywait.new(override)
	local opts = vim.tbl_deep_extend("keep", I.permanent, override or { })
		opts.cwd	= opts.cwd or vim.fn.getcwd()
		opts.name = opts.name:format(vim.fn.fnamemodify(opts.cwd, ':t'))

	-- # Include or Exclude
	I.filter_events(opts.args, opts.filter or false)

	-- # Append events
	I.events(opts.args, opts.events or false)

	opts.args[#opts.args+1] = './'
	vim.list_extend(opts.on_stdout, override.on_stdout or I.default_onstdout)

	local ix = prochandler.new(opts)
	return ix
end

---   API    ---
----------------

return inotifywait
