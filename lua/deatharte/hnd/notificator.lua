--- # deatharte.hnd.notificator
----------------
---   Deps   ---

local hasnotify, nvimnotify = pcall(require, 'notify') -- # Requires rcarriga/nvim-notify
if not hasnotify then
	error('deatharte.hnd.notificator is missing the required dependency ‹nvim-notify›') end
local	utf8len			= require('deatharte.util.string').utf8len
local	count				= require('deatharte.util.string').count

local config = require('deatharte').fetch_configuration()
local notify_config = require('notify')._config()

---   Deps   ---
----------------

----------------
--- Internal ---
local I = { }

-- # Run callback list
I.run_callback = function(list)
	return function(obj, ntcontent, key)
		return function(win)
			local args = { win, obj, ntcontent, key or false }

			for _, ck in ipairs(list or { }) do
				local call = (type(ck) == 'function' and ck)
					or ck.callback or ck[1]

				local tpcond = type(ck) == 'table' and type(ck.condition) or nil
				if tpcond == nil
					or ( tpcond == 'boolean' and tpcond)
					or ( tpcond == 'function' and ck.condition(unpack(args))) then

					if type(call) == 'function' then
						call(unpack(args))
					end
				end
			end
		end
	end
end

local set_alive = function(win, obj, _, key)
	obj.alive[key]				= obj.alive[key] or { }
	obj.alive[key].win		= win
end

local resize_formula_lup = { }
	resize_formula_lup.minimal = function(ntcontent)
		local width		= 0

		local height	= count(ntcontent.message, '\n') + 1
		for line in ntcontent.message:gmatch("[^\r\n]+") do
			width = math.max(width, utf8len(line))
		end

		return width, height
	end

	resize_formula_lup.default	= function(ntcontent)
		local width, height = resize_formula_lup.minimal(ntcontent)

		-- HAX: Hardcoded values, yuck
		width = math.max(width, utf8len(ntcontent.title) + 10)
		height = height + 2

		return width, height
	end

local resize		= function(win, _, ntcontent, _)
	local formula =
		resize_formula_lup[ntcontent.raw.render] or resize_formula_lup.default
	local calcwidth, calcheight = formula(ntcontent.raw)

	vim.api.nvim_win_set_width(win,	 calcwidth)
	vim.api.nvim_win_set_height(win, calcheight)
end

local resize_entry = {
	condition = function(_, obj, ntcontent, _)
			if ntcontent.resize then return true end
			if obj.resize then return true end
			return false
		end, resize
}

local notify_onopen = {
	condition = function(_)
		return notify_config.on_open or false
	end, notify_config.on_open
}

local notify_onclose = {
	condition = function(_)
		return notify_config.on_close or false
	end, notify_config.on_close
}

I.required_onopen = {
	notify_onopen,
	set_alive,
	resize_entry
}

I.required_onupdate = {
	resize_entry
}

I.required_onclose = {
	notify_onclose
}

--- Internal ---
----------------
---   API    ---

local notificator				= { }	-- # Class and static object
local metanotificator		= { }	-- # Metatable for class
local staticnotificator = { } -- # Metatable for static object

-- # Handle notifications globally
local global_enabled  = true
notificator.genable		=	function() global_enabled = true end
notificator.gdisable	=	function() global_enabled = false end
notificator.gtoggle		=	function() global_enabled = not global_enabled end
notificator.gstate		= function() return global_enabled end

-- # New notificator
function notificator.new(opts)
	opts = opts or { }
		opts.name = opts.name or opts.plugin

	-- # Fetch global configuration
	opts = vim.tbl_deep_extend("keep", opts, config and config.hnd.notificator.default)

	-- # Set known fields
	-- The following fields can and will be overwritten within the ‹spawn› method
	local ix = setmetatable({ }, metanotificator)
		ix.name			= opts.name																-- # Prefix to notification
		ix.alive		= { }																			-- # Which notificator-notifications are 'alive'
		ix.default	= { }																			-- # Notification content if left unchanged

		ix.default.title			= opts.title										-- # Default title
		ix.default.plugin			= opts.plugin or opts.name			-- # Which plugin is providing the notifications
		ix.default.cat				= opts.cat or 'generic'
		ix.default.render			= opts.render										-- # Which render style to use for notification, if not given, will be then determined automatically
		ix.default.timeout		= opts.timeout or 1500					-- # Notification static timeout
		ix.default.group			= opts.group or opts.name				-- # Which "key" will be used in the replacing mechanism


		-- # Defaulting to true
		ix.default.hide				= not opts.nohide								-- # Should the notification be hidden from the telescope finder?
		ix.default.resize			= not opts.noresize							-- # Should the notification be resized to fit the content
		ix.default.doreplace	= not opts.noreplace						-- # New notification will always try to replace previously defined notifications, may be overwritten with `doreplace = false`

		-- # Configure on_open/on_close 
		local on_open		= vim.deepcopy(I.required_onopen)
		if opts.on_open then vim.list_extend(on_open, opts.on_open) end

		local on_close	= vim.deepcopy(I.required_onclose)
		if opts.on_close then vim.list_extend(on_close, opts.on_close) end

		local on_update = vim.deepcopy(I.required_onupdate)
		if opts.on_update then vim.list_extend(on_update, opts.on_update) end

		ix.on_open		= I.run_callback(on_open)
		ix.on_close		= I.run_callback(on_close)
		ix.on_update	= I.run_callback(on_update)

		-- Currently enabled
		ix.enabled		= not opts.silent

	return ix
end

local function _totable(content)
	if type(content) == 'table' then
		return content
	elseif type(content) == 'string' then
		return { message = content }
	else return false end
end

local function _message(message)
	if type(message) == 'table' then
		message = table.concat(message, '\n') end

	return message:gsub('\t', string.rep(' ', 4))
end

-- # Override fields for this notification
local function _prepare(obj, content)
	local ntcontent = vim.deepcopy(obj.default)
		-- # These have to come from the content
		ntcontent.type			= content.type or 'info'
		ntcontent.cat				= content.cat or ntcontent.cat
		ntcontent.message		= content.message and _message(content.message)
			or 'no-message'

		-- # Title and render style handling
		-- Render kept his priority over title
		ntcontent.title			= content.title
		ntcontent.render		= content.render or ntcontent.render or
			(not ntcontent.title and 'minimal') or 'default'

		-- # No title was given and style is non-minimal
		if ntcontent.render ~= 'minimal' and not ntcontent.title then
			ntcontent.title = ('%s: %s'):format(obj.name, ntcontent.cat) end

		-- # Timeout and replace
		ntcontent.group			= content.group or ntcontent.group
		ntcontent.timeout	= content.timeout or ntcontent.timeout

		-- # HAX: Timeout updated to false does not work
		-- This is probably subjected to underflow
		if ( content.nodismiss ~= nil ) then ntcontent.timeout = -1 end
		if ( content.doreplace ~= nil ) then ntcontent.doreplace = content.doreplace end
		if ( content.hide ~= nil )			then ntcontent.hide_from_history = content.hide end
		if ( content.resize ~= nil )		then ntcontent.resize = content.resize end

	return ntcontent
end

-- # Return key from given content
local function _key(ntcontent)
	if not ntcontent.doreplace	then return false end
	if not ntcontent.group			then return false end

	return ('%s@%s'):format(ntcontent.group, ntcontent.cat)
end

-- # Returns whether or not the notification has to replace
local function _lookup(obj, key)
	return obj.alive[key] or false
end

-- # Spawn a notification
local function _spawn(obj, ntcontent, key)
	local notify = nvimnotify(ntcontent.message, ntcontent.type, ntcontent)

	-- # If a notification was replaced
	if ntcontent.replace then
		ntcontent.on_update(obj.alive[key].win) end

	-- # Store id, keep the rest as it is
	if key then
		obj.alive[key]				= obj.alive[key] or { }
		obj.alive[key].id			= notify and notify.id
	end
end

-- # Replace a notification, free of charge!
local function _replace(obj, ntcontent, key)
	local winid	= obj.alive[key] and obj.alive[key].win

	if winid and vim.api.nvim_win_is_valid(winid) then
		ntcontent.replace = obj.alive[key].id
		ntcontent.raw.title	= ntcontent.raw.title or obj.alive[key].title
	end

	_spawn(obj, ntcontent, key)
end

-- # Spawn new notification
function notificator:spawn(content)
	-- HAX: This hurts my eyes but I don't know any better tbh
	local o = getmetatable(self)
	if o ~= metanotificator and o ~= staticnotificator then
		return notificator.spawn(staticnotificator.__fallback, self) end
	if self == notificator then
		return notificator.spawn(staticnotificator.__fallback, content) end

	-- # Is notification-system enabled?
	if not global_enabled or not self.enabled then
		return end

	-- # Prepare content
	local ntcontent = _prepare(self, _totable(content))
	ntcontent.raw = vim.deepcopy(ntcontent)

	-- # Do-notify
	vim.schedule(function()
		-- # Prepare key and lookup
		local	key							= _key(ntcontent)
		local may_replace			= key and _lookup(self, key) or false

		ntcontent.on_open  = self.on_open(self, ntcontent, key)
		ntcontent.on_close = self.on_close(self, ntcontent, key)
		ntcontent.on_update = self.on_update(self, ntcontent, key)

		if not may_replace then
			_spawn(self, ntcontent, key)
		else _replace(self, ntcontent, key) end
	end)
end

function notificator:info(content)
	content = _totable(content)
		content.cat				= content and content.cat or 'info'
		content.type			= 'info'
		content.timeout		= content and content.timeout or 1500
		content.hide			= true
	self:spawn(content)
end

function notificator:warn(content)
	content = _totable(content)
		content.cat				= content and content.cat or 'warn'
		content.type			= 'warn'
		content.timeout		= content and content.timeout or 3000
	self:spawn(content)
end

function notificator:error(content)
	content = _totable(content)
		content.cat				= content and content.cat or 'error'
		content.type			= 'error'
		content.noreplace	= true
		content.nodismiss	= true
	self:spawn(content)
end

function notificator:debug(content)
	content = _totable(content)
		content.cat				= content and content.cat or 'debug'
		content.type			= 'info'
		content.render		= 'minimal'
		content.hide			= true
		content.nodismiss = true
	self:spawn(content)
end

function notificator:enable() self.enabled = true end
function notificator:disable() self.enabled = false end
function notificator:toggle() self.enabled = not self.enabled end
function notificator:state() return self.enabled end

---   API    ---
----------------

metanotificator.__index			= notificator
metanotificator.__call			= notificator.spawn

staticnotificator.__fallback	= notificator.new(config and config.hnd.notificator.static)
staticnotificator.__index			= staticnotificator.__fallback
staticnotificator.__call			= function(_, ...)
	notificator.spawn(staticnotificator.__fallback, ...)
end

setmetatable(notificator, staticnotificator)


return notificator
