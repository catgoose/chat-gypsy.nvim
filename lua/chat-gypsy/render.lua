local utils = require("chat-gypsy.utils")

local Render = {}
Render.__index = Render

function Render:new()
	setmetatable(self, Render)
	return self
end

function Render:chat_from_history(bufnr, file_path)
	vim.api.nvim_buf_set_option(bufnr, "filetype", "markdown")
	local contents = utils.decode_json_from_path(file_path)
	for _, message_tbls in pairs(contents.messages) do
		vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { message_tbls.role, "" })
		for line in message_tbls.message:gmatch("[^\n]+") do
			vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { line })
		end
		vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { "" })
	end
end

return Render
