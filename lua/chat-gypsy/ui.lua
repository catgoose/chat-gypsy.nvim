local nui_pu, nui_lo = require("nui.popup"), require("nui.layout")
local config = require("chat-gypsy.config")
local opts = config.opts
local Log = require("chat-gypsy").Log

local layout_configs = { "float", "left", "right" }

local function build_ui(layout_config)
	layout_config = layout_config or {
		type = "float",
	}
	if not vim.tbl_contains(layout_configs, layout_config.type) then
		layout_config.type = "float"
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
	local response_config = vim.tbl_deep_extend("force", popup_base, {
		buf_options = {
			filetype = "markdown",
		},
	})

	local prompt = nui_pu(prompt_config)
	local response = nui_pu(response_config)

	local layout_strategy = function(_layout_config)
		local float = nui_lo(
			{
				position = opts.ui.layout.float.position,
				size = opts.ui.layout.float.size,
				relative = "editor",
			},
			nui_lo.Box({
				nui_lo.Box(response, {
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
					nui_lo.Box(response, {
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

		if _layout_config.type == "float" then
			return float
		end
		if _layout_config.type == "right" then
			return create_side_layout(_layout_config.type)
		end
		if _layout_config.type == "left" then
			return create_side_layout(_layout_config.type)
		end
	end
	local layout = layout_strategy(layout_config)
	return {
		layout = layout,
		layout_config = layout_config,
		boxes = { response = response, prompt = prompt },
	}
end

local UI = {}
UI.__index = UI

setmetatable(UI, {
	__call = function(cls, ...)
		local self = setmetatable({}, cls)
		self:_init(...)
		return self
	end,
})

function UI:new()
	setmetatable(self, UI)
	local layout_config = {
		type = "float",
	}
	local ui = build_ui(layout_config)
	Log.trace(string.format("Building new ui with layout config: \n%s", vim.inspect(layout_config)))
	self.layout = ui.layout
	self.boxes = ui.boxes
	self:layout_init()
	return self
end

function UI:layout_init()
	Log.warn("UI:layout_init: not implemented")
end

return UI
