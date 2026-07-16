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

local rain_material_groups = {
	crumbly = true,
	snappy = true,
	cracky = true,
	choppy = true,
	water = true,
	snowy = true,
}

core.register_on_mods_loaded(function()
	for name, def in pairs(core.registered_nodes) do
		local collect = rain_drawtypes[def.drawtype]
		if collect then
			collect = false
			for group in pairs(rain_material_groups) do
				if (def.groups and def.groups[group] or 0) > 0 then
					collect = true
					break
				end
			end
		end
		if collect then
			core.add_item_groups(name, {rain_collect = 1})
		end
	end
end)

core.register_core_abm({
	name = "weather:water_evaporate",
	action = "water_evaporate",
	nodenames = {"default:water_flowing"},
	neighbors = {"air"},
	interval = 10,
	chance = 10,
	catch_up = true,
	params = {
		humidity_stop = 96,
		humid_air_stop = 75,
		humid_heat_min = -2,
		humid_heat_max = 50,
		heat_min = -5,
		warm_scale = 45,
		warm_max = 1.8,
		shade_factor = 0.35,
		rate = 6,
		max_level_loss = 8,
	},
})

core.register_core_abm({
	name = "weather:steam_evaporate",
	action = "steam_evaporate",
	nodenames = {"group:steam"},
	neighbors = {"air"},
	interval = 10,
	chance = 1,
	catch_up = true,
	params = {
		humidity_reference = 100,
		min_evaporation_chance = 1,
		level_step = 1,
		evaporate_on_activate = true,
	},
})

core.register_core_abm({
	name = "weather:rain_fill",
	action = "rain_fill",
	nodenames = {"group:rain_collect"},
	neighbors = {"air"},
	interval = 15.0,
	chance = 50,
	catch_up = true,
	params = {
		water_node = "default:water_flowing",
		cloud_height = weather.cloud_height,
		heat_min = -2,
		heat_max = 50,
		phase_heat_max = 2,
		rain_humidity = 75,
		wet_humidity = 55,
		wet_span = 45,
		rate = 2.0,
		max_amount = 5,
		existing_water_multiplier = 4,
		wind_scale = 0.35,
		wind_limit = 1,
		wind_chance_scale = 0.25,
	},
})
