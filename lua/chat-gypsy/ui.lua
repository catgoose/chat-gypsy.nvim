local nui_pu, nui_lo = require("nui.popup"), require("nui.layout")
local config = require("chat-gypsy.config")
local opts = config.opts
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

	local popup_base = vim.tbl_deep_extend("force", opts.ui.config, {
		zindex = 50,
	})
	local prompt_config = vim.tbl_deep_extend("force", popup_base, {
		buf_options = {
			filetype = "prompt",
		},
		border = {
			text = {
				top = "Prompt",
			},
		},
		enter = true,
	})
	local chat_config = vim.tbl_deep_extend("force", popup_base, {
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
	})

	local prompt = nui_pu(prompt_config)
	local chat = nui_pu(chat_config)

	local layout_strategy = function(_layout_config)
		local float = nui_lo(
			{
				position = opts.ui.layout.float.position,
				size = opts.ui.layout.float.size,
				relative = "editor",
			},
			nui_lo.Box({
				nui_lo.Box(chat, {
					size = "100%",
				}),
				nui_lo.Box(prompt, {
					size = {
						height = opts.ui.layout.float.prompt_height,
					},
				}),
			}, { dir = "col" })
		)

		local create_side_layout = function(side)
			if side ~= "left" and side ~= "right" then
				side = "left"
			end
			local side_config = opts.ui[side]
			local side_layout = nui_lo(
				vim.tbl_deep_extend("force", {
					relative = "editor",
				}, side_config),
				nui_lo.Box({
					nui_lo.Box(chat, {
						size = {
							height = vim.o.lines - opts.ui.layout[side].prompt_height - 1,
						},
					}),
					nui_lo.Box(prompt, {
						size = {
							height = opts.ui.layout[side].prompt_height,
						},
					}),
				}, { dir = "col" })
			)
			return side_layout
		end

		if _layout_config.layout == "float" then
			return float
		end
		if _layout_config.layout == "right" then
			return create_side_layout(_layout_config.layout)
		end
		if _layout_config.layout == "left" then
			return create_side_layout(_layout_config.layout)
		end
	end
	local layout = layout_strategy(layout_config)
	return {
		layout = layout,
		layout_config = layout_config,
		boxes = { chat = chat, prompt = prompt },
	}
end

function UI.new()
	local self = setmetatable({}, UI)
	local layout_config = {
		layout = "float",
	}
	local ui = build_ui(layout_config)
	Log.trace(string.format("Building new ui with layout config: \n%s", vim.inspect(layout_config)))
	self.layout = require("chat-gypsy.layout").new(ui)
	return self
end

return UI
