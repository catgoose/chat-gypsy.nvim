local plugin_opts = require("chat-gypsy").Config.get("plugin_opts")

local Logger = {}
Logger.log = {}

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
