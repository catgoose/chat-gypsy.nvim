local nui_pu, nui_lo = require("nui.popup"), require("nui.layout")
local config = require("chat-gypsy.config")
local cfg = config.cfg
local Log = require("chat-gypsy").Log

local UI = {}
UI.__index = UI

local layout_configs = { "float", "left", "right" }

local function build_ui(layout_config)
	layout_config = layout_config or {
		layout = "float",
	}
	if not vim.tbl_contains(layout_configs, layout_config.layout) then
		layout_config.layout = "float"
	end

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

	local layout_strategy = function(lc)
		local float = nui_lo(
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
						height = cfg.ui.float.prompt_height,
					},
				}),
			}, { dir = "col" })
		)

		local left = nui_lo(
			{
				position = {
					row = "0%",
					col = "0%",
				},
				size = {
					width = "40%",
					height = "100%",
				},
				relative = "editor",
			},
			nui_lo.Box({
				nui_lo.Box(chat, {
					size = {
						height = vim.o.lines - cfg.ui.left.prompt_height - 1,
					},
				}),
				nui_lo.Box(prompt, {
					size = {
						height = cfg.ui.left.prompt_height,
					},
				}),
			}, { dir = "col" })
		)

		if lc.layout == "float" then
			return float
		end
		if lc.layout == "right" then
			return left
		end
		if lc.layout == "left" then
			return left
		end
	end
	local layout = layout_strategy(layout_config)
	return {
		layout = layout,
		boxes = { chat = chat, prompt = prompt },
	}
end

function UI.new()
	local self = setmetatable({}, UI)
	local layout_config = {
		layout = "float",
	}
	local ui = build_ui(layout_config)
	Log.debug(string.format("Building new ui with layout config: \n%s", vim.inspect(layout_config)))
	self.layout = require("chat-gypsy.layout").new(ui)
	return self
end

return UI
