local TelescopeModels = {}

local picker = function(entries, opts)
	pickers
		.new(opts, {
			prompt_title = "History",
			finder = finders.new_table({
				results = entries,
				entry_maker = entry_maker,
			}),
			sorter = conf.generic_sorter(),
			attach_mappings = attach_mappings,
			previewer = previewers.new_buffer_previewer({
				title = "Chat history",
				define_preview = define_preview,
			}),
			wrap_results = true,
		})
		:find()
end

function TelescopeModels.models(opts)
	vim.print("pick a model")
	local entries = require("chat-gypsy").Config.get("models")
	picker(entries, opts)
end

return TelescopeModels
