local Log = require("chat-gypsy").Log
local has_telescope, telescope = pcall(require, "telescope")
-- local pickers = require("chat-gypsy.telescope")

if not has_telescope then
	Log.error("unable to load telescope")
	return
end

return telescope.register_extension({
	exports = {
		history = function(opts)
			local ts = require("chat-gypsy.telescope.history"):new()
			ts:history(opts)
		end,
		models = function(opts)
			local ts = require("chat-gypsy.telescope.models"):new()
			ts:models(opts)
		end,
	},
})
