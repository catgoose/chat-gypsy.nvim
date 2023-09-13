FuncQueue = {}
FuncQueue.__index = FuncQueue

function FuncQueue.new()
	local self = setmetatable({}, FuncQueue)
	self.queue = {}
	self.isRunning = false
	return self
end

function FuncQueue:add(func)
	table.insert(self.queue, func)
	self:executeNext()
end

function FuncQueue:executeNext()
	if not self.isRunning and #self.queue > 0 then
		self.isRunning = true

		local func = table.remove(self.queue, 1)

		func(function()
			self.isRunning = false
			self:executeNext()
		end)
	end
end

function FuncQueue:clear()
	self.queue = {}
	self.isRunning = false
end

return FuncQueue
