local Telescope = {}

function Telescope.history(opts)
	require("chat-gypsy.telescope.history").history(opts)
end

function Telescope.models(opts)
	opts = opts or {}
	vim.print("pick a model")
	-- local entries = sql:get_models()
	-- picker(entries, opts)
end

return Telescope
