local Telescope = {}

function Telescope.history(opts)
	require("chat-gypsy.telescope.history").history(opts)
end

function Telescope.models(opts)
	opts = opts or {}
	require("chat-gypsy.telescope.models").models(opts)
end

return Telescope
