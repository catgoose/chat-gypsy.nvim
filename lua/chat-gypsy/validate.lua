local Log = require("chat-gypsy").Log

local Validate = {}

local logError = function(err_msg, throw)
	Log.error(err_msg)
	if throw then
		error(err_msg)
	end
end

Validate.openai_key = function(openai_key, throw)
	throw = throw or false
	if not openai_key or not (#openai_key > 0) then
		local err_msg =
			string.format("Missing OPENAI_API_KEY environment variable.  opts.openai: %s", vim.inspect(openai_key))
		logError(err_msg, throw)
		return false
	end
	return true
end

return Validate
