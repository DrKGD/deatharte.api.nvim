--- # deatharte.hnd.tracker
----------------
---   Deps   ---

local config = require('deatharte').fetch_configuration()
local has_sqlite, db = pcall(require, 'sqlite')
if config and config.hnd.tracker.store == 'sqlite' and not has_sqlite then
	error('deatharte.hnd.tracker: optional dependency ‹sqlite› is not available, but the setup requires so!')
end

---   Deps   ---
----------------
--- Internal ---
local I = { }

-- # Store method: sqlite file
I.sqlite = { }
I.sqlite.__index = I.sqlite

-- # Initialize database object
I.sqlite.init = function(name)
	-- # Database path
	local uri = config and config.hnd.tracker.uri
	vim.fn.mkdir(vim.fn.fnamemodify(uri, ':h'), 'p')

	local ix = setmetatable({ }, I.sqlite)
		ix.name		= name
		ix.handle = db {
			uri = uri,

			tracklist = {
				-- # Which id has the list
				id = true,

				-- # Tracklist name
				name = { "string", required = true },

				-- # First added on (date)
				added = { "date", default = db.lib.strftime("%s", "now") },

				-- # Expected type
				type = { "string", required = true },
			},

			track = {
				-- # A field has to be used as unique
				key = { "string", primary = true },

				-- # Track belongs in a tracklist
				list = { type = "integer", reference = "tracklist.id", on_delete = "cascade" },

				-- # Entry
				entry = { "luatable" }
			}
		}

	return ix
end

local function _has_tracklist(tracker, name)
	if not name then
		return error('Missing a name!') end

	local tracklist = tracker:where { name = name }
	return tracklist and tracklist.id
end

local function _ensure_tracklist(tracker, name, type)
	if not name then
		return error('Missing a name!') end

	local tracklist = tracker:where { name = name }
	if not tracklist then
		return tracker:insert { name = name, type = type } end
	return tracklist.id
end

local key_from_entry = {
	['table'] = function(entry)
		return entry.key or entry[1]
	end,

	['nil']	= function(_)
		return error('Entry type boolean is not allowed!')
	end,

	['boolean']	= function(_)
		return error('Entry type boolean is not allowed!')
	end,

	['default'] = function(entry)
		return tostring(entry)
	end
}

-- # Convert entries to a table of entries
local function _prepare_entries(entries)
	if type(entries) ~= 'table' then
		entries = { entries } end
	return next(entries) and entries or false
end

-- # Update tracklist methods
local function _update_methods(object, expect)
	object.expect			= object.expect or expect
	object.keymethod	= object.keymethod or key_from_entry[object.expect] or key_from_entry.default
	object.listid			= object.listid or _ensure_tracklist(object.handle.tracklist, object.name, object.expect)
end

-- # Parse given entries
local function _parse_list(object, entries)
	local parsed = { }
	for _, entry in ipairs(entries) do
		if type(entry) ~= object.expect then
			error (('Wrong type for entry: expected ‹%s›, got ‹%s›; aborting...')
				:format(type(entry), object.expect))
		end

		local key = object.keymethod(entry)
		parsed[key] =
			{ entry = entry, list = object.listid, key = key }
	end

	return parsed
end

-- # Prepare insertion list
local function _ins_list(object, entries)
	local parsed = _parse_list(object, entries)

	-- # Prepare insertion list
	local insquery = { }
	for _, entry in pairs(parsed) do
		if not object.handle.track:where { key = entry.key } then
			if insquery[entry.key] and insquery[entry.key] ~= entry.entry then
				error(('Duplicate in insert for key ‹%s›'):format(parsed.key)) end

			insquery[entry.key] =
				{ entry = entry.entry, list = object.listid, key = entry.key }
		end
	end

	return vim.tbl_values(ins)
end

-- # Add entries
function I.sqlite:add(entries)
	entries = _prepare_entries(entries)
	if not entries then return false end
	if not self.expect then _update_methods(self, type(entries[1])) end

	-- # Perform the insertion
	local ins = _ins_list(self, entries)
	if #ins > 0 then
		return self.handle.track:insert(ins) end
	return false
end

-- # Remove entries
function I.sqlite:remove(entries)
	entries = _prepare_entries(entries)
	if not entries then return false end
	if not self.expect then _update_methods(self, type(entries[1])) end
	local parsed = _parse_list(self, entries)

	local keylist = { }
	for _, entry in pairs(parsed) do
		keylist[#keylist + 1] = entry.key end

	if #keylist > 0 then
		return self.handle.track:remove { key = keylist } end
	return false
end

-- # Return entries if any was found
function I.sqlite:get()
	self.listid =  self.listid or _has_tracklist(self.handle.tracklist, self.name)
	if not self.listid then return { } end

	local setlist = { }
	local rawlist = self.handle.track:get { where = { list = self.listid } }
	for _, entry in ipairs(rawlist) do
		setlist[entry.entry] = true
	end

	return setlist
end

-- # Clear table content
function I.sqlite:clear()
	self.listid =  self.listid or _has_tracklist(self.handle.tracklist, self.name)
	if not self.listid then return false end
	return self.handle.track:remove { list = self.listid }
end

--- Internal ---
----------------
---    API   ---
local tracker = { }
tracker.__index = tracker

-- # Tracker
function tracker.new(name, opts)
	name = name or 'unnamed-tracker'
	opts = opts or { }

	local ix = setmetatable({ }, tracker)
		ix.name			= name
		ix.verbose	= not opts.quiet
		ix.notify		= require('deatharte.hnd.notificator').new({
			plugin = 'nvimlocale.watchlist',
			title = ('%s watchlist'):format(name)
		})

		-- # Either 'sqlite' or false for now
		ix.store	= opts.store or config and config.hnd.tracker.store
		if ix.store and not I[ix.store] then
			error(("Store method ‹%s› is not available!"):format(ix.store)) end
		ix.method = ix.store and ( I[ix.store] and I[ix.store].init(ix.name) ) or false

		-- # Restore list or set a new one
		ix.list 		= ix.method and ix.method:get() or { }

	return ix
end

local function _add(obj, entry)
	obj.list[entry] = true
end

local function _remove(obj, entry)
	obj.list[entry] = nil
end

-- # Add an entry to the watchlist
function tracker:add(entry)
	if self.list[entry] then
		return self end

	_add(self, entry)
	if self.method then
		self.method:add(entry) end
	if self.verbose then
		self.notify(("New entry ‹%s›!"):format(tostring(entry)), 'info') end

	return self
end

-- # Remove an entry from the watchlist
function tracker:remove(entry)
	if not self.list[entry] then
		return self end

	_remove(self, entry)
	if self.method then
		self.method:remove(entry) end
	if self.verbose then
		self.notify(("Entry ‹%s› was removed!"):format(tostring(entry)), 'info') end

	return self
end

-- # Toggle an entry
function tracker:toggle(entry)
	if self.list[entry] then
		return self:remove(entry)
	else return self:add(entry) end
end

-- # Check if entry is in the watchlist
-- May serve as a statusline/winbar component
function tracker:has(entry)
	return self.list[entry] or false
end

-- # Run specified lambda if entry exists
-- Attach to your own lambda event! 
function tracker:callback(entry, lambda)
	if self.list[entry] then
		lambda(entry)
	end

	return self
end

-- # Drop all the entries
function tracker:clear()
	self.list = { }
	if self.method then
		self.method:clear() end
end

-- # Returns the tracklist in a readable format
function tracker:__tostring()
	-- # Retrieve common
	local tbl = { }
		tbl[#tbl + 1] = ('watch_list: ‹%s›'):format(self.name)
		tbl[#tbl + 1] = (' - is_verbose: ‹%s›'):format(tostring(self.verbose))

	-- # Obtain names
	local entries = { }
	for name, _ in pairs(self.list) do
		entries[#entries+1] = name
	end

	local list = (#entries > 0) and (' - entries: ‹%s›'):format(table.concat(entries, ';'))
		or ' - no entries'
	tbl[#tbl + 1] = list

	return table.concat(tbl, '\n')
end

---    API   ---
----------------

return tracker
