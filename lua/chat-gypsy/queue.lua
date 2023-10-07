FuncQueue = {}

function FuncQueue:new(cfg)
	local instance = {}
	setmetatable(instance, { __index = self })
	cfg = cfg or {}
	cfg.sequential = cfg.sequential or true
	instance.sequential = cfg.sequential
	instance.queue = {}
	instance.isRunning = false
	return instance
end

function FuncQueue:add(...)
	local funcs = { ... }
	for _, func in ipairs(funcs) do
		table.insert(self.queue, func)
	end
	self:executeNext()
end

function FuncQueue:executeNext()
	if self.sequential then
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
