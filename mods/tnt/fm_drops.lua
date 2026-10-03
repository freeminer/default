-- Preserve full stack identity while keeping aggregate counts outside ItemStack's u16.
local function identity(item)
	local fields = item:get_meta():to_table().fields
	local keys = {}
	for key in pairs(fields) do keys[#keys + 1] = key end
	table.sort(keys)
	local name = item:get_name()
	local parts = {tostring(#name), ":", name, ":", tostring(item:get_wear()), ":"}
	for _, key in ipairs(keys) do
		local value = fields[key]
		-- Length prefixes distinguish embedded separators and arbitrary metadata.
		parts[#parts + 1] = #key .. ":" .. key .. #value .. ":" .. value
	end
	return table.concat(parts)
end

local function add(drops, value)
	local item = ItemStack(value)
	if item:is_empty() then return end
	local lost = item:get_definition()._tnt_loss or 0
	if lost > 0 and (lost == 1 or math.random(1, lost) == 1) then return end
	local count = item:get_count()
	item:set_count(1)
	local key = identity(item)
	local entry = drops[key]
	if entry then
		entry.count = entry.count + count
	else
		drops[key] = {item = item, count = count}
	end
end

local function each_stack(drops, emit)
	for _, entry in pairs(drops) do
		local left = entry.count
		local maximum = math.min(65535, math.max(1, entry.item:get_stack_max()))
		while left > 0 do
			local count = math.min(left, maximum)
			local item = ItemStack(entry.item)
			item:set_count(count)
			emit(item)
			left = left - count
		end
	end
end

return {add = add, each_stack = each_stack}
