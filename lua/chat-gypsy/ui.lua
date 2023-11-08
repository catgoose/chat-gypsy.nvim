---@class UIOptsHistory
---@field openai_params table
---@field messages table

---@class UIOpts
---@field mount boolean
---@field placement string
---@field injection string[] | nil
---@field restore_history boolean
---@field history UIOptsHistory

---@class UI
---@field public new fun(ui_opts: table): UI
---@field public init fun() @abstract
---@field private layout table
---@field private boxes table
---@field private ui_opts UIOpts
---@field private Log Logger
---@return UI

local opts = require("chat-gypsy").Config.get("opts")
local nui_pu, nui_lo = require("nui.popup"), require("nui.layout")

local placements = { "center", "left", "right" }

local function build_ui(placement)
	placement = placement or "center"
	if not vim.tbl_contains(placements, placement) then
		placement = "center"
	end

	local popup_base = opts.ui.config
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

	local placement_strategy = function(_placement)
		local float = nui_lo(
			{
				position = opts.ui.layout.center.position,
				size = opts.ui.layout.center.size,
				relative = "editor",
			},
			nui_lo.Box({
				nui_lo.Box(chat, {
					size = "100%",
				}),
				nui_lo.Box(prompt, {
					size = {
						height = opts.ui.layout.center.prompt_height,
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

		if _placement == "center" then
			return float
		end
		if _placement == "right" or _placement == "left" then
			return create_side_layout(_placement)
		end
	end
	local layout = placement_strategy(placement)
	return {
		layout = layout,
		boxes = { chat = chat, prompt = prompt },
	}
end

local UI = {}
UI.__index = UI

function UI:new(ui_opts)
	setmetatable(self, UI)
	self.Log = require("chat-gypsy").Log
	local default = {
		mount = false,
		injection = nil,
		placement = opts.ui.layout_placement,
		restore_history = false,
		history = {
			openai_params = {},
			messages = {},
		},
	}
	ui_opts = vim.tbl_deep_extend("force", default, ui_opts)
	local ui = build_ui(ui_opts.placement)
	self.Log.trace(string.format("Building new ui with layout config: \n%s", vim.inspect(ui_opts.layout)))
	self.layout = ui.layout
	self.boxes = ui.boxes
	self.ui_opts = ui_opts
	self:init()
	return self
end

function UI:init()
	self.Log.warn("UI:layout_init: not implemented")
end

return UI
