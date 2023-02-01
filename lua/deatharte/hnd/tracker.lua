--- # deatharte.hnd.tracker
----------------
---   Deps   ---

local config = require('deatharte').fetch_configuration()
local has_sqlite, sqlite = pcall(require, 'sqlite')
if config and config.deps.sqlite and not has_sqlite then
	error('deatharte.hnd.tracker: optional dependency ‹sqlite› is not available, but the setup requires so!')
end

---   Deps   ---
----------------
----------------
---    API   ---
local tracker = { }
tracker.__index = tracker

-- # Tracker
function tracker.new(name, quiet)
	name = name or 'unnamed-tracker'

	local ix = setmetatable({ }, tracker)
		ix.name			= name
		ix.list 		= { }
		ix.verbose	= not quiet
		ix.notify		= require('nvimlocale.util.generic').notify({
			plugin = 'nvimlocale.watchlist',
			title = ('%s watchlist'):format(name)
		})

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
	if self.verbose then
		self.notify(("New entry ‹%s›!"):format(tostring(entry)), 'info') end

	return self
end

-- # Remove an entry from the watchlist
function tracker:remove(entry)
	if not self.list[entry] then
		return self end

	_remove(self, entry)
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
