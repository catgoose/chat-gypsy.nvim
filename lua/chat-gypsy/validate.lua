local opts = require("chat-gypsy").Config.get("opts")
local Log = require("chat-gypsy").Log

local Validate = {}

local logError = function(err_msg, throw)
	Log.error(err_msg)
	if throw then
		error(err_msg)
	end
end

Validate.openai_key = function(throw)
	throw = throw or false
	if not opts.openai.openai_key or not (#opts.openai.openai_key > 0) then
		local err_msg =
			string.format("Missing OPENAI_API_KEY environment variable.  opts.openai: %s", vim.inspect(opts.openai))
		logError(err_msg, throw)
		return false
	end
	return true
end

return Validate
