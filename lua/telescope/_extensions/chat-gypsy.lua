local Log = require("chat-gypsy").Log
local has_telescope, telescope = pcall(require, "telescope")
local pickers = require("chat-gypsy.telescope")

if not has_telescope then
	Log.error("unable to load telescope")
	return
end

return telescope.register_extension({
	exports = {
		history = function(opts)
			pickers.history(opts)
		end,
		models = function(opts)
			pickers.models(opts)
		end,
	},
})
