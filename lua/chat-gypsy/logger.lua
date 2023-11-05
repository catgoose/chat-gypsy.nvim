local plugin_opts = require("chat-gypsy").Config.get("plugin_opts")

-- Adapter class for plenary logger
---@class Logger
---@field log fun(msg: string, ...) | table
---@field trace fun(msg: string, ...)
---@field debug fun(msg: string, ...)
---@field info fun(msg: string, ...)
---@field warn fun(msg: string, ...)
---@field error fun(msg: string, ...)
---@field fatal fun(msg: string, ...)
---@return Logger
local Logger = {}
Logger.log = nil

--- Initializes the logger.
Logger.init = function()
	Logger.log = require("plenary.log").new({
		plugin_opts = plugin_opts.name,
		level = plugin_opts.log_level,
		fmt_msg = function(_, mode_name, src_path, src_line, msg)
			local nameupper = mode_name:upper()
			local lineinfo = vim.fn.fnamemodify(src_path, ":t") .. ":" .. src_line
			return string.format("[%-6s%s] %s: %s", nameupper, os.date("%H:%M:%S"), lineinfo, msg)
		end,
	})
	return Logger.log
end

return Logger
