---@class Utils
---@field public deep_copy fun(orig: any): any
---@field public generate_random_id fun(len: number): string
---@field public string_to_lines_tbl fun(str: string): string[]
---@field public split_string fun(str: string, sep: string, include_empty: boolean): string[]
---@field public check_roles fun(role: string, include_error: boolean): boolean

local Utils = {}

Utils.generate_random_id = function(len)
	local charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	local result = ""
	for _ = 1, len do
		local rand = math.random(#charset)
		result = result .. string.sub(charset, rand, rand)
	end
	return result
end

Utils.deep_copy = function(orig)
	local t = type(orig)
	local copy
	if t == "table" then
		copy = {}
		for k, v in pairs(orig) do
			copy[k] = Utils.deep_copy(v)
		end
	else
		copy = orig
	end
	return copy
end

Utils.string_to_lines_tbl = function(str)
	local t = {}
	local pattern = "([^\n]*)"
	for word in string.gmatch(str, pattern) do
		table.insert(t, word)
	end
	return t
end

Utils.split_string = function(str, sep, include_empty)
	local t = {}
	local pattern = string.format("([^%s]*)", sep)
	for word in string.gmatch(str, pattern) do
		if include_empty or word ~= "" then
			table.insert(t, word)
		end
	end
	return t
end

Utils.check_roles = function(role, include_error)
	if include_error then
		return vim.tbl_contains({ "system", "user", "assistant", "error" }, role)
	end
	return vim.tbl_contains({ "system", "user", "assistant" }, role)
end

Utils.get_visual = function()
	local vstart = vim.fn.getpos("v")[2]
	local current_line = vim.fn.line(".")
	local lines = vim.api.nvim_get_mode().mode == "V" and vim.fn.getline(vstart, current_line) or nil
	return lines
end

return Utils
