local Usercmd = {}

Usercmd.init = function()
	vim.api.nvim_create_user_command("GypsyToggle", require("chat-gypsy").toggle, {})
	vim.api.nvim_create_user_command("GypsyOpen", require("chat-gypsy").open, {})
	vim.api.nvim_create_user_command("GypsyClose", require("chat-gypsy").close, {})
	vim.api.nvim_create_user_command("GypsyHide", require("chat-gypsy").hide, {})
	vim.api.nvim_create_user_command("GypsyShow", require("chat-gypsy").show, {})
end

return Usercmd
