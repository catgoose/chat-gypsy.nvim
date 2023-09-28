FuncQueue = {}

function FuncQueue:new(config)
	local instance = {}
	setmetatable(instance, { __index = self })
	config = config or {}
	config.sync = config.sync or true
	instance.sync = config.sync
	instance.queue = {}
	instance.isRunning = false
	return instance
end

function FuncQueue:add(func)
	table.insert(self.queue, func)
	self:executeNext()
end

function FuncQueue:executeNext()
	if self.sync then
		if not self.isRunning and #self.queue > 0 then
			self.isRunning = true
			local func = table.remove(self.queue, 1)
			func(function()
				self.isRunning = false
				self:executeNext()
			end)
		end
		return
	else
		while #self.queue > 0 do
			local func = table.remove(self.queue, 1)
			func()
		end
	end
end

function FuncQueue:clear()
	self.queue = {}
	self.isRunning = false
end

return FuncQueue
