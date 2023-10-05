local Log = require("chat-gypsy").Log
local opts = require("chat-gypsy").Config.get("opts")
local nui_pu, nui_lo = require("nui.popup"), require("nui.layout")

local layout_configs = { "center", "left", "right" }

local function build_ui(layout_config)
	layout_config = layout_config or {
		direction = "center",
	}
	if not vim.tbl_contains(layout_configs, layout_config.direction) then
		layout_config.direction = "center"
	end

	local popup_base = vim.tbl_deep_extend("force", opts.ui.config, {
		zindex = 50,
	})
	local prompt_config = vim.tbl_deep_extend("force", popup_base, {
		buf_options = {
			filetype = "prompt",
		},
		enter = true,
	})
	local chat_config = vim.tbl_deep_extend("force", popup_base, {
		buf_options = {
			filetype = "markdown",
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
			local side_config = opts.ui.layout[side]
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

		if _layout_config.direction == "center" then
			return float
		end
		if _layout_config.direction == "right" then
			return create_side_layout(_layout_config.direction)
		end
		if _layout_config.direction == "left" then
			return create_side_layout(_layout_config.direction)
		end
	end
	local layout = layout_strategy(layout_config)
	return {
		layout = layout,
		layout_config = layout_config,
		boxes = { chat = chat, prompt = prompt },
	}
end

local UI = {}
UI.__index = UI

function UI:new(ui_config)
	setmetatable(self, UI)
	local ui_config_defaults = {
		mount = false,
		layout = {
			direction = "center",
		},
		render_history = false,
	}
	--  TODO: 2023-10-05 - extend ui_config_defaults over ui_config, keeping
	--  values from ui_config
	-- vim.tbl_deep_extend("force", ui_config_defaults, ui_config)
	vim.print(ui_config)
	local ui = build_ui(ui_config.layout)
	Log.trace(string.format("Building new ui with layout config: \n%s", vim.inspect(ui_config.layout)))
	self.layout = ui.layout
	self.boxes = ui.boxes
	self:init()
	if ui_config.mount then
		self:mount()
	end
	return self
end

function UI:init()
	Log.warn("UI:layout_init: not implemented")
end

return UI
