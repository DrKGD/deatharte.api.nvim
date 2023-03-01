--- # deatharte.util.path
-- Generic path functions
local M = {}

-- # Check if file exists
M.fileExists	= function(f)
	return vim.fn.empty(vim.fn.glob(f)) == 0 end

-- # Check if is dir and dir exists
M.dirExists		= function(d)
	return vim.fn.isdirectory(d) ~= 0 end

-- # Check if is dir
M.isDir				= function(p)
	return p:sub(-1) == '\\' or p:sub(-1) == '/' end

-- # Return parent directory of the file
M.dirParent		= function(fn)
	return vim.fn.fnamemodify(fn, ':p:h') end

return M
