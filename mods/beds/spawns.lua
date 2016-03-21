--[[
local world_path = minetest.get_worldpath()
local org_file = world_path .. "/beds_spawns"
local file = world_path .. "/beds_spawns"
local bkwd = false

-- check for PA's beds mod spawns
local cf = io.open(world_path .. "/beds_player_spawns", "r")
if cf ~= nil then
	io.close(cf)
	file = world_path .. "/beds_player_spawns"
	bkwd = true
end
]]

function beds.read_spawns(player)
	--local spawns = beds.spawn
	local name = player:get_player_name()
	local bed = core.kv_get('p_' .. name .. '_beds')
	if not bed then return end
	beds.spawn[name] = bed.spawn

--[[
	local input = io.open(file, "r")
	if input and not bkwd then
		repeat
			local x = input:read("*n")
			if x == nil then
				break
			end
			local y = input:read("*n")
			local z = input:read("*n")
			local name = input:read("*l")
			spawns[name:sub(2)] = {x = x, y = y, z = z}
		until input:read(0) == nil
		io.close(input)
	elseif input and bkwd then
		beds.spawn = minetest.deserialize(input:read("*all"))
		input:close()
		beds.save_spawns()
		os.rename(file, file .. ".backup")
		file = org_file
	else
		beds.spawn = {}
	end
]]
end

function beds.save_spawns()
--[[
	if not beds.spawn then
		return
	end
	local output = io.open(org_file, "w")
	for i, v in pairs(beds.spawn) do
		output:write(v.x .. " " .. v.y .. " " .. v.z .. " " .. i .. "\n")
	end
	io.close(output)
]]
end

function beds.set_spawns()
	for name,_ in pairs(beds.player) do
		local player = minetest.get_player_by_name(name)
		local p = player:getpos()
		-- but don't change spawn location if borrowing a bed
		if not minetest.is_protected(p, name) then
			beds.spawn[name] = p
			core.kv_put('p_' .. name .. '_beds', {spawn = p})
		end
	end
	--beds.save_spawns()
end
