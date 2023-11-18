---@class Float
---@field public float_init fun()

local Float = {}
Float.__index = Float

function Float:float_init()
	self.Log.debug("init_float")
end

return Float
