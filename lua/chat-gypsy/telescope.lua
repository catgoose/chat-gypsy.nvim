local History = require("chat-gypsy").History
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local pickers = require("telescope.pickers")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local previewers = require("telescope.previewers")

local Telescope = {}

local function history_picker(opts)
	History.get_files(function(response)
		local files = response:result()
		pickers
			.new(opts, {
				prompt_title = "History",
				-- layout_config = {
				-- 	width = 0.5,
				-- 	height = 0.5,
				-- },
				finder = finders.new_table({
					results = files,
					-- :help telescope.make_entry
					entry_maker = function(entry)
						return {
							value = entry,
							display = "file: " .. entry,
							ordinal = entry,
							filename = entry,
						}
					end,
				}),
				sorter = conf.generic_sorter(),
				attach_mappings = function(prompt_bufnr, _)
					actions.select_default:replace(function()
						actions.close(prompt_bufnr)
						local selection = action_state.get_selected_entry()
						vim.print(string.format("history %s selected", selection.value))
					end)
					return true
				end,
				previewer = previewers.new_buffer_previewer({
					title = "Chat history",
					define_preview = function(self, entry, _)
						vim.api.nvim_buf_set_option(self.state.bufnr, "filetype", "markdown")
						vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, { entry.value })
					end,
				}),
			})
			:find()
	end)
end

function Telescope.history(opts)
	opts = opts or {}
	-- opts = require("telescope.themes").get_dropdown({})
	history_picker(opts)
end

return Telescope
