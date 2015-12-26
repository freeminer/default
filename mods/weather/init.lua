-- Weather:
-- * rain
-- * snow
-- * wind (not implemented)

assert(core.add_particlespawner, "I told you to run the latest GitHub!")
assert(core.get_heat, "I told you to run the latest freeminer!")

addvectors = function (v1, v2)
	return {x=v1.x+v2.x, y=v1.y+v2.y, z=v1.z+v2.z}
end

local cloud_height = tonumber(core.setting_get("cloud_height"));
local snow_humidity = 65
local rain_humidity = 75

get_snow = function (p)
	if not p then return 0 end
	if p.y > cloud_height then return 0 end
	local heat = core.get_heat(p)
	if heat >= 0 then return 0 end
	local humidity = core.get_humidity(p)
	if humidity < snow_humidity then return 0 end
	--print('S h='..core.get_heat(p)..' h='..core.get_humidity(p))
	return (humidity-snow_humidity)/(100-snow_humidity)
end

get_rain = function (p)
	if not p then return 0 end
	if p.y > cloud_height then return 0 end
	local heat = core.get_heat(p)
	if heat <= 0 then return 0 end
	if heat > 50 then return 0 end
	local humidity = core.get_humidity(p)
	if humidity < rain_humidity then return 0 end
	--print('R h='..core.get_heat(p)..' h='..core.get_humidity(p))
	return (humidity-rain_humidity)/(100-rain_humidity)
end

if default.weather then
	if core.setting_getbool("liquid_real") then
		dofile(core.get_modpath("weather").."/rain.lua")
	end

	dofile(core.get_modpath("weather").."/snow.lua")
end


if default.weather then
local grass_heat_max = 41
local grass_heat_max2 = 71
local grass_humidity_min = 10
local grass_humidity_min2 = 50
local grass_light_min = 2

core.register_abm({
	nodenames = {"default:dirt", "default:dirt_with_grass", "default:dirt_dry", "default:dirt_with_dry_grass" },
	interval = 10,
	chance = 30,
	action = function(pos, node)
		local top_pos = {x=pos.x, y=pos.y+1, z=pos.z}
		local top_name = core.get_node(top_pos).name
		local top_nodedef = core.registered_nodes[top_name]
		if top_name == "ignore" or not top_nodedef then return end

		local light = core.get_node_light(top_pos) or 0
		local heat = core.get_heat(pos)
		local humidity = core.get_humidity(pos)
		local new_name

		if not ((top_nodedef.sunlight_propagates or top_nodedef.paramtype == "light") and top_nodedef.liquidtype == "none") then
			if node.name == "default:dirt_with_dry_grass" then
				new_name = "default:dirt_dry"
			elseif node.name == "default:dirt_with_grass" then
				new_name = "default:dirt"
			end
		else
			if top_name == "default:snow" or top_name == "default:snowblock" or top_name == "default:ice" then
					new_name = "default:dirt_with_snow"
			elseif top_name == "air" then
				if node.name == "default:dirt_with_grass" and (light <= grass_light_min or (heat > grass_heat_max and humidity < grass_humidity_min2) or humidity < 2 or heat > grass_heat_max2) then
					new_name = "default:dirt_with_dry_grass"
				elseif node.name == "default:dirt" and (light <= grass_light_min or (heat > grass_heat_max and humidity < grass_humidity_min2) or humidity < grass_humidity_min or heat > grass_heat_max2) then
					new_name = "default:dirt_dry"
				end
				if (default.weather and heat < -5 and humidity > 5) then
					new_name = "default:dirt_with_snow"
				elseif (not default.weather or (heat > 5 and heat < grass_heat_max and humidity > grass_humidity_min)) and light >= grass_light_min then
					new_name = "default:dirt_with_grass"
				end
			end
		end

		if new_name and new_name ~= node.name then
			node.name = new_name
			core.set_node(pos, node, 2)
		else
			if node.name == "default:dirt_with_grass" and top_name == "air" and (default.weather and heat > 5 and heat < grass_heat_max and humidity > grass_humidity_min)
				and math.random(1, 50) == 1 and light >= grass_light_min then
				core.set_node(top_pos, {name = "default:grass_1"}, 2)
			end
		end

	end
})

core.register_abm({
	nodenames = {"default:grass_1", "default:grass_2", "default:grass_3", "default:grass_4", "default:grass_5", "default:dry_shrub"},
	neighbors = {"default:dirt_with_grass", "default:dirt"},
	interval = 20,
	chance = 30,
	action = function(pos, node)
		local humidity = core.get_humidity(pos)
		local heat = core.get_heat(pos)
		if (heat < -5 or heat > grass_heat_max or humidity < 3) and (name == "default:grass_4" or name == "default:grass_5") then
			node.name = "default:dry_shrub"
			core.set_node(pos, node, 2)
			return
		end
		if heat < 5 or heat > grass_heat_max or (core.get_node_light(pos) or 0) < grass_light_min then return end
		local rnd = math.random(1, 110-humidity)
		local node = core.get_node(pos)
		local name = node.name
		if name == "default:grass_5" then
				if rnd >= 2 then return end
				if     humidity > 75 and heat > 25 then node.name = "default:junglesapling" 
				elseif humidity < 20 and heat > 25 then node.name = "default:acacia_sapling"
				elseif humidity > 30 and heat < 10 then node.name = "default:pine_sapling"
				elseif humidity > 40 and heat < 40 then node.name = "default:sapling"
				else return end
				core.set_node(pos, node, 2)
		elseif name == "default:dry_shrub" then
			node.name = "default:grass_" .. 1
			core.set_node(pos, node, 2)
		else
			for i=1,4 do
				if rnd >= i+5 then return end
				if name == "default:grass_"..i then
					node.name = "default:grass_"..(i+1)
					core.set_node(pos, node, 2)
				end
			end
		end
	end
})

core.register_abm({
	nodenames = {"default:sand", "default:desert_sand", "default:dirt_dry", "default:dirt_with_dry_grass"},
	neighbors = {"default:water_flowing"},
	interval = 20,
	neighbors_range = 3,
	chance = 10,
	action = function(pos, node)
		if ((core.get_heat(pos) > grass_heat_max or core.get_humidity(pos) < grass_humidity_min)) then return end
		if node.name == "default:dirt_with_dry_grass" then
			node.name = "default:dirt_with_grass"
		else
			node.name = "default:dirt"
		end
		core.set_node(pos, node, 2)
	end
})

--[[ now in mt

core.register_abm({
	nodenames = {"default:cobble"},
	neighbors = {"default:water_flowing"},
	interval = 20,
	neighbors_range = 2,
	chance = 50,
	action = function(pos, node)
		if ((core.get_heat(pos) < 5 or core.get_heat(pos) > 40 or core.get_humidity(pos) < 15)) then return end
		node.name = "default:mossycobble"
		core.set_node(pos, node, 2)
	end
})

]]

end
