local plugin_cfg = require("chat-gypsy").Config.plugin_cfg

local Logger = {}
Logger.log = {}

Logger.init = function()
	Logger.log = require("plenary.log").new({
		plugin_cfg = plugin_cfg.name,
		level = plugin_cfg.log_level,
		fmt_msg = function(_, mode_name, src_path, src_line, msg)
			local nameupper = mode_name:upper()
			local lineinfo = vim.fn.fnamemodify(src_path, ":t") .. ":" .. src_line
			return string.format("[%-6s%s] %s: %s", nameupper, os.date("%H:%M:%S"), lineinfo, msg)
		end,
	})
	return Logger.log
end

return Logger
