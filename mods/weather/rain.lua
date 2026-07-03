-- Rain
core.register_globalstep(function(dtime)
	for _, player in ipairs(core.get_connected_players()) do
		local ppos = player:get_pos()
		local strength = get_rain(ppos, 1)
		if strength > 0
				and core.get_node(ppos).name == "air"
				and weather.exposed_to_sky(ppos) then
--print("rain he=".. core.get_heat(ppos).." hu=".. core.get_humidity(ppos) .. " s=" .. strength)
	       local minpos = addvectors(player:get_pos(), {x = -15, y = 10, z = -15})
	       local maxpos = addvectors(player:get_pos(), {x = 15, y = 15, z = 15})
	       local wind = weather.get_block_wind(ppos)
	       local wind_x = (wind.x or 0) * 2.0
	       local wind_y = (wind.y or 0) * 0.5
	       local wind_z = (wind.z or 0) * 2.0
	       core.add_particlespawner(
		  {
		     amount = 30*strength,
		     time = 0.5,
		     minpos = minpos,
		     maxpos = maxpos,
		     minvel = {x = wind_x * 0.8, y = -22 + wind_y, z = wind_z * 0.8},
		     maxvel = {x = wind_x * 1.2, y = -18 + wind_y, z = wind_z * 1.2},
		     minexptime = 0.9,
		     maxexptime = 1.1,
		     minsize = 2,
		     maxsize = 3,
		     collisiondetection = false, --true,
		     vertical = true,
		     texture = "weather_rain.png",
		     playername = player:get_player_name()
		  }
		  )
		end
	end
end)

local rain_drawtypes = {
	normal = true,
	nodebox = true,
	flowingliquid = true,
	glasslike = true,
	liquid = true,
	allfaces_optional = true,
}

local rain_water_add_rate = 2.0 -- previous 3.0, reduced 1.5x
local rain_water_add_max = 5 -- previous 8, reduced 1.5x and rounded down

local function rain_fill_amount(pos)
	local rain = get_rain(pos) or 0
	if rain <= 0 then return 0 end

	local heat = core.get_heat(pos) or 10
	if heat < -2 then return 0 end

	local humidity = core.get_humidity(pos) or 50
	local wet_air = math.max(0, (humidity - 55) / 45)
	local amount = rain * (1.0 + wet_air) * rain_water_add_rate
	return weather.random_amount(amount, rain_water_add_max)
end

local function can_collect_rain(node)
	local def = core.registered_nodes[node.name]
	return def and rain_drawtypes[def.drawtype]
end

local function rain_target(base_pos, top_pos)
	local wind_top = weather.wind_target(top_pos, 0.35, 1, 0.25)
	if wind_top.x == top_pos.x and wind_top.z == top_pos.z then
		return base_pos, top_pos
	end

	if core.get_node(wind_top).name ~= "air" then
		return base_pos, top_pos
	end

	local wind_base = addvectors(wind_top, {x=0, y=-1, z=0})
	local wind_node = core.get_node(wind_base)
	if wind_node.name == "air" or can_collect_rain(wind_node) then
		return wind_base, wind_top
	end

	return base_pos, top_pos
end

core.register_abm({
	nodenames = {"group:crumbly", "group:snappy", "group:cracky", "group:choppy", "group:water", "group:snowy"},
	neighbors = {"air"},
	interval = 15.0,
	chance = 50,
	action = function (pos, node, active_object_count, active_object_count_wider, neighbor, activate)
		if not can_collect_rain(node) then return end

		local np = addvectors(pos, {x=0, y=1, z=0})
		if not weather.exposed_to_sky(np) then return end

		local amount = rain_fill_amount(pos)
		if amount <= 0 then return end

		local target_pos, target_np = rain_target(pos, np)
		local target_node = core.get_node(target_pos)

		if target_node.name == "default:water_flowing" then
			core.add_node_level(target_pos, 4 * amount, 2)
		elseif core.get_node(target_np).name == "air" then
			core.set_node(target_np, {name="default:water_flowing"})
			core.set_node_level(target_np, amount, 2)
		end
	end
})

local function evaporation_amount(pos)
	local humidity = core.get_humidity(pos) or 50
	if humidity >= 96 or get_rain(pos) > 0 then return 0 end

	local np = addvectors(pos, {x=0, y=1, z=0})
	if core.get_node(np).name ~= "air" then return 0 end

	local heat = core.get_heat(pos) or 10
	if heat < -5 then return 0 end

	local light = core.get_node_light(np, 0.5) or 0
	local sun = light >= default.LIGHT_SUN and 1.0 or light / default.LIGHT_SUN
	local dry = math.max(0, (96 - humidity) / 96)
	local warm = math.max(0, math.min(1.8, (heat + 5) / 45))
	local amount = dry * warm * (0.35 + 0.65 * sun) * 6
	local whole = math.floor(amount)
	local frac = amount - whole

	if math.random() < frac then
		whole = whole + 1
	end

	return math.max(0, math.min(8, whole))
end

-- evaporate
core.register_abm({
	nodenames = {"default:water_flowing"},
	neighbors = {"air"},
	interval = 10.0,
	chance = 10,
	action = function (pos, node, active_object_count, active_object_count_wider)
		local amount = evaporation_amount(pos)
		if amount > 0 then
			core.add_node_level(pos, -amount, 2)
		end
	end
})
