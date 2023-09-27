local History = require("chat-gypsy").History
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local pickers = require("telescope.pickers")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local previewers = require("telescope.previewers")

local Telescope = {}

local function history_picker(opts)
	local history = History.read()
	pickers
		.new(opts, {
			prompt_title = "History",
			finder = finders.new_table({
				results = history,
			}),
			sorter = conf.generic_sorter(),
			attach_mappings = function(prompt_bufnr, _)
				actions.select_default:replace(function()
					actions.close(prompt_bufnr)
					local selection = action_state.get_selected_entry()
					-- tm.run_task(selection.value)
					vim.print(selection.value)
				end)
				return true
			end,
		})
		:find()
end

function Telescope.history(opts)
	opts = opts or {}
	history_picker(opts)
end

return Telescope
