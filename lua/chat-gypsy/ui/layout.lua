---@class LayoutState
---@field private layout string
---@field private float_initilized boolean

---@alias LayoutTypes "float" | "split" | "tab"

---@class Layout
---@field private _ LayoutState
---@field public layout_init fun()
---@field public set_layout fun(layout: LayoutTypes): Layout
---@field public open_layout fun(layout: LayoutTypes): Layout
---@field public open_float fun()
---@field private initialize_float fun()

local Float = require("chat-gypsy.ui.float")

local Layout = setmetatable({}, Float)
Layout.__index = Layout
setmetatable(Layout, {
	__index = Float,
})

function Layout:layout_init()
	self.open_float = function()
		self.Log.debug("open_float")
	end
	self._ = {
		layout = "float",
		float_initilized = false,
	}
	self.initialize_float = function()
		if self._.float_initilized then
			return
		end
		self._.float_initilized = true
		self.Log.debug("initialize_float")
		self:float_init()
	end
end

function Layout:set_layout(layout)
	if vim.tbl_contains({ "float", "split", "tab" }, layout) then
		self._.layout = layout
	else
		self._ = {
			layout = "float",
		}
	end
	return self
end

function Layout:open_layout(layout)
	if layout then
		self:set_layout(layout)
	end
	if self._.layout == "float" then
		self.initialize_float()
		self.open_float()
	end
	if self._.layout == "split" then
		self.Log.debug("split")
	end
	if self._.layout == "tab" then
		self.Log.debug("tab")
	end
end

return Layout
