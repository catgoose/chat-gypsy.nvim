local opts = require("chat-gypsy").Config.get("opts")
local Log = require("chat-gypsy").Log

local Validate = {}

local logError = function(err_msg, throw)
	throw = throw or false
	Log.error(err_msg)
	if throw then
		error(err_msg)
	end
end

Validate.openai_key = function()
	if not opts.openai.openai_key or not (#opts.openai.openai_key > 0) then
		local err_msg =
			string.format("Missing OPENAI_API_KEY environment variable.  opts.openai: %s", vim.inspect(opts.openai))
		logError(err_msg, true)
		return false
	end
	return true
end

return Validate
