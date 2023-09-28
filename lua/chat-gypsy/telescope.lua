local History = require("chat-gypsy").History
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local pickers = require("telescope.pickers")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local previewers = require("telescope.previewers")
local utils = require("chat-gypsy.utils")

local Telescope = {}

local function history_picker(opts)
	History.get_picker_entries(function(entries)
		pickers
			.new(opts, {
				prompt_title = "History",
				-- layout_config = {
				-- 	width = 0.5,
				-- 	height = 0.5,
				-- },
				finder = finders.new_table({
					results = entries,
					entry_maker = function(item)
						return {
							value = item.entries,
							display = string.format("%s: %s", item.entries.name, item.entries.description),
							ordinal = item.entries.name,
							filename = item.path.full,
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
						local contents = utils.decode_json_from_path(entry.filename)
						for _, message_tbls in pairs(contents.messages) do
							vim.api.nvim_buf_set_lines(self.state.bufnr, -1, -1, false, { message_tbls.type, "" })
							for line in message_tbls.message:gmatch("[^\n]+") do
								vim.api.nvim_buf_set_lines(self.state.bufnr, -1, -1, false, { line })
							end
							vim.api.nvim_buf_set_lines(self.state.bufnr, -1, -1, false, { "" })
						end
					end,
				}),
			})
			:find()
	end)
end

function Telescope.history(opts)
	opts = opts or {}
	history_picker(opts)
end

return Telescope
