minetest.register_craft({
	output = 'default:ice',
	recipe = {
		{'default:snow', 'default:snow'},
		{'default:snow', 'default:snow'},
	}
})

-- Snow
core.register_globalstep(function(dtime)
	for _, player in ipairs(core.get_connected_players()) do
		local ppos = player:get_pos()
		local strength = get_snow(ppos, 1)
		if strength > 0
				and core.get_node(ppos).name == "air"
				and weather.exposed_to_sky(ppos, 1) then
	       local minpos = addvectors(player:get_pos(), {x = -30, y = 15, z = -30})
	       local maxpos = addvectors(player:get_pos(), {x = 30, y = 20, z = 30})
	       local wind = weather.get_block_wind(ppos)
	       local drift = {
		  x = (wind.x or 0) * 1.5,
		  y = (wind.y or 0) * 0.4,
		  z = (wind.z or 0) * 1.5,
	       }
	       local spread = {x = 6.0, y = 1.0, z = 6.0}
	       local acc = {
		  x = (wind.x or 0) * 0.35,
		  y = -2.0,
		  z = (wind.z or 0) * 0.35,
	       }
	       core.add_particlespawner(
		  {
		     amount = 8*strength,
		     time = 0.4,
		     minpos = minpos,
		     maxpos = maxpos,
		     minvel = {
			x = drift.x - spread.x,
			y = -5.0 + drift.y - spread.y,
			z = drift.z - spread.z,
		     },
		     maxvel = {
			x = drift.x + spread.x,
			y = -2.0 + drift.y + spread.y,
			z = drift.z + spread.z,
		     },
		     minacc = {x = acc.x - 1.0, y = -3.0, z = acc.z - 1.0},
		     maxacc = {x = acc.x + 1.0, y = -1.0, z = acc.z + 1.0},
		     minexptime = 1.0,
		     maxexptime = 1.4,
		     minsize = 3,
		     maxsize = 4,
		     collisiondetection = true,
		     vertical = false,
		     texture = "weather_snow.png",
		     playername = player:get_player_name()
		  }
	       )
		end
	end
end)

local snow_box =
{
	type  = "fixed",
	fixed = {-0.5, -0.5, -0.5, 0.5, -0.4, 0.5}
}


-- -[[ Enable this section if you have a very fast PC
core.register_core_abm({
	name = "weather:snow_fill",
	action = "snow_fill",
	nodenames = {"group:crumbly", "group:snappy", "group:cracky", "group:choppy", "group:melt", "group:snowy"},
	neighbors = {"air"},
	interval = 10.0,
	chance = 50,
	catch_up = true,
	params = {
		cloud_height = weather.cloud_height,
		heat_max = 2,
		phase_heat_min = -2,
		snow_humidity = 65,
		wet_heat_min = -12,
		wet_heat_span = 13,
		humidity_reference = 70,
		rate = 2,
		max_amount = 6,
		sky_tolerance = 1,
		wind_scale = 0.55,
		wind_limit = 2,
		wind_chance_scale = 0.35,
		time_speed = tonumber(core.settings:get("time_speed")) or 0,
		snow_node = "default:snow",
		ice_node = "default:ice",
	},
})

core.register_core_abm({
	name = "weather:snow_compact",
	action = "snow_compact",
	nodenames = {"default:snow"},
	neighbors = {"default:snow", "default:ice"},
	interval = 200,
	chance = 1,
	catch_up = true,
	params = {
		snow_node = "default:snow",
		ice_node = "default:ice",
	},
})
