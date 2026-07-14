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


default.time_speed = tonumber(core.settings:get("time_speed"))

local function shuffle(t)
	for i = #t, 2, -1 do
		local j = math.random(i)
		t[i], t[j] = t[j], t[i]
	end
end

local snow_drawtypes = {
	normal = true,
	nodebox = true,
	allfaces_optional = true,
	glasslike = true,
}

local function snow_fill_amount(pos, heat, humidity)
	local snow = get_snow(pos) or 0
	if snow <= 0 then return 0 end

	heat = heat or core.get_heat(pos) or -5
	if heat > 2 then return 0 end

	humidity = humidity or core.get_humidity(pos) or 70
	local wet = math.max(0, math.min(1, (heat + 12) / 13))
	local humid = math.max(0.5, math.min(1.5, humidity / 70))
	local amount = snow * (1.0 + wet) * humid * 2
	return weather.random_amount(amount, 6)
end

local function snow_target(base_pos, top_pos)
	local wind_top = weather.wind_target(top_pos, 0.55, 2, 0.35)
	if wind_top.x == top_pos.x and wind_top.z == top_pos.z then
		return base_pos, top_pos
	end

	if core.get_node(wind_top).name ~= "air" then
		return base_pos, top_pos
	end

	local wind_base = addvectors(wind_top, {x=0, y=-1, z=0})
	local wind_node = core.get_node(wind_base)
	local wind_def = core.registered_nodes[wind_node.name]
	if wind_node.name == "default:snow"
			or (wind_def and snow_drawtypes[wind_def.drawtype]) then
		return wind_base, wind_top
	end

	return base_pos, top_pos
end

-- -[[ Enable this section if you have a very fast PC
core.register_abm({
	nodenames = {"group:crumbly", "group:snappy", "group:cracky", "group:choppy", "group:melt", "group:snowy"},
	neighbors = {"air"},
	interval = 10.0,
	chance = 50,

	action = function (pos, node, active_object_count, active_object_count_wider, neighbor, activate)
		local def = core.registered_nodes[node.name]
		if not def or not snow_drawtypes[def.drawtype] then return end

		local np = addvectors(pos, {x=0, y=1, z=0})
		if not weather.exposed_to_sky(np, 1) then return end

		local heat = core.get_heat(pos) or -5
		local add = snow_fill_amount(pos, heat, core.get_humidity(pos) or 70)
		if add <= 0 then return end

		pos, np = snow_target(pos, np)
		node = core.get_node(pos)

		if node.name == "default:snow" then
			local min_level = core.get_node_level(pos)
			local min_pos = pos

			local update_falling
			-- smooth
			--local rnd = math.random(1, 4)
			local arr = {1, 2, 3, 4, 5, 6, 7}
			-- smooth or wet snow
			if heat < -10 then table.remove(arr) end
			-- if heat < -20 then table.remove(arr) end
			shuffle(arr)
			for _,rnd in ipairs(arr) do
				if min_level <= 1 then break end
				local addv = {x=0, y=0, z=0}
				if     rnd == 1 then addv.x = 1
				elseif rnd == 2 then addv.x = -1
				elseif rnd == 3 then addv.z = -1
				elseif rnd == 4 then addv.z = 1
				elseif rnd >= 5 then break
				end

				local ngp = addvectors(min_pos, addv)
				local lev = core.get_node_level(ngp)

				local test_name = core.get_node(ngp).name
				if test_name == "air" then
					min_pos = ngp
					core.set_node(min_pos, {name="default:snow"}, 2)
					local random_max = -heat/2
					if random_max > 1 and math.random(random_max) > 1 then
						update_falling = 1
					end
					break
				end

				if test_name == "default:snow" and lev < min_level then
					min_level = lev
					min_pos = ngp
				end
			end

			pos = min_pos
			np = addvectors(pos, {x=0, y=1, z=0})
			add = core.add_node_level(pos, add, 2);
			if default.time_speed <= 0 then add = 0 end
			if add > 0 then
				core.set_node(pos, {name="default:ice"}, 2)
			elseif activate ~= 1 and update_falling then
				-- core.nodeupdate(pos, 0)
				core.check_single_for_falling(pos)
			end
		end
		if add > 0 and core.get_node(np).name == "air" then
			core.set_node(np, {name="default:snow"}, 2)
			core.add_node_level(np, add, 2)
		end
	end
})

core.register_abm({
	nodenames = {"default:snow"},
	neighbors = {"default:snow", "default:ice"},
	interval = 200,
	chance = 1,
	action = function (pos, node, active_object_count, active_object_count_wider)
		local bottom_name = core.get_node(addvectors(pos, {x=0, y=-1, z=0})).name
		if bottom_name == "ignore" or bottom_name == "air" then return end

		local top_name = core.get_node(addvectors(pos, {x=0, y=1, z=0})).name
		if top_name == "default:snow" or top_name == "default:ice" then
			core.set_node(pos, {name="default:ice"})
		end
	end
})
