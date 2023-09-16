Utils = {}

Utils.deepcopy = function(orig)
	local t = type(orig)
	local copy
	if t == "table" then
		copy = {}
		for k, v in pairs(orig) do
			copy[k] = Utils.deepcopy(v)
		end
	else
		copy = orig
	end
	return copy
end

return Utils
