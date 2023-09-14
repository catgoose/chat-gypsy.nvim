local nui_pu, nui_lo = require("nui.popup"), require("nui.layout")
local config = require("chat-gypsy.config")
local cfg = config.cfg

local UI = {}
UI.__index = UI

local function build_ui()
	local popup_base = {
		zindex = 50,
		focusable = true,
		border = {
			style = "rounded",
			text = {
				top_align = "left",
			},
			padding = {
				top = 1,
				left = 2,
				right = 2,
			},
		},
		win_options = {
			cursorline = false,
			winbar = nil,
			winblend = 5,
			winhighlight = "Normal:Normal,FloatBorder:FloatBorder",
			wrap = true,
		},
	}
	local prompt = nui_pu(vim.tbl_deep_extend("force", popup_base, {
		buf_options = {
			filetype = "prompt",
		},
		border = {
			text = {
				top = "Prompt",
			},
		},
		enter = true,
	}))
	local chat = nui_pu(vim.tbl_deep_extend("force", popup_base, {
		buf_options = {
			filetype = "markdown",
		},
		border = {
			text = {
				top = "Chat",
				bottom = "Tokens 0",
				bottom_align = "right",
			},
		},
	}))
	local layout = nui_lo(
		{
			position = {
				row = "20%",
				col = "50%",
			},
			size = {
				width = "70%",
				height = "70%",
			},
			relative = "editor",
		},
		nui_lo.Box({
			nui_lo.Box(chat, {
				size = "100%",
			}),
			nui_lo.Box(prompt, {
				size = {
					height = cfg.ui.prompt_height,
				},
			}),
		}, { dir = "col" })
	)
	return {
		layout = layout,
		boxes = { chat = chat, prompt = prompt },
	}
end

function UI.new(openai)
	local self = setmetatable({}, UI)
	self.layout = require("chat-gypsy.layout").new(openai, build_ui())
	return self
end

return UI
