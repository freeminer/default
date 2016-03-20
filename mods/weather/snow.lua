-- Snow
core.register_globalstep(function(dtime)
	for _, player in ipairs(core.get_connected_players()) do
		local ppos = player:getpos()
		local strength = get_snow(ppos)
		if strength > 0 and core.get_node(ppos).name == "air" then
--print("snow he=".. core.get_heat(ppos).." hu=".. core.get_humidity(ppos) .. " s=" .. strength)
		-- Make sure player is not in a cave/house...
		if core.get_node_light(ppos, 0.5) ~= default.LIGHT_SUN then return end

		local minp = addvectors(ppos, {x=-9, y=7, z=-9})
		local maxp = addvectors(ppos, {x= 9, y=7, z= 9})

		local minp_deep = addvectors(ppos, {x=-10, y=3.2, z=-10})
		local maxp_deep = addvectors(ppos, {x= 10, y=2.6, z= 10})

		local vel = {x=0, y=   -0.5, z=0}
		local acc = {x=0, y=   -0.5, z=0}

--[[
		core.add_particlespawner({
			amount=5*strength, time=0.5,
			minpos=minp, maxpos=maxp,
			minvel=vel, maxvel=vel,
			minacc=acc, maxacc=acc,
			minexptime=5, maxexptime=5,
			minsize=25, maxsize=25,
			collisiondetection=false,
			texture="weather_snow.png",
			player=player:get_player_name()
		})

		core.add_particlespawner({
			amount=4*strength, time=0.5,
			minpos=minp, maxpos=maxp,
			minvel=vel, maxvel=vel,
			minacc=acc, maxacc=acc,
			minexptime=4, maxexptime=4,
			minsize=25, maxsize=25,
			collisiondetection=false,
			texture="weather_snow.png",
			player=player:get_player_name()
		})
]]
	       local minpos = addvectors(player:getpos(), {x = -30, y = 20, z = -30})
	       local maxpos = addvectors(player:getpos(), {x = 30, y = 15, z = 30})
	       local vel = {x = 16.0, y = -8, z = 13.0}
	       local acc = {x = -16.0, y = -8, z = -13.0}
	       core.add_particlespawner(
		  {
		     amount = 8*strength,
		     time = 0.4,
		     minpos = minpos,
		     maxpos = maxpos,
		     minvel = {x=-vel.x, y=vel.y, z=-vel.z},
		     maxvel = vel,
		     minacc = acc,
		     maxacc = acc,
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


default.time_speed = tonumber(core.setting_get("time_speed"))

-- -[[ Enable this section if you have a very fast PC
core.register_abm({
	nodenames = {"group:crumbly", "group:snappy", "group:cracky", "group:choppy", "group:melts"},
	neighbors = {"air"},
	interval = 10.0,
	chance = 50,

	action = function (pos, node, active_object_count, active_object_count_wider)
		local amount = get_snow(pos)
		if amount == 0 then return end
		local add = 1 + (amount * 2);
		if core.registered_nodes[node.name].drawtype ~= "normal"
			and core.registered_nodes[node.name].drawtype ~= "nodebox"
			and core.registered_nodes[node.name].drawtype ~= "allfaces_optional" then return end
		local np = addvectors(pos, {x=0, y=1, z=0})
		if core.get_node_light(np, 0.5) ~= default.LIGHT_SUN then return end
		if core.get_node(pos).name == "default:snow" then
			local min_level = core.get_node_level(pos)
			local min_pos = pos

			-- smooth
			--local rnd = math.random(1, 4)
			for rnd = 1, 4 do
				if min_level <= 1 then break end
				local addv = {x=0, y=0, z=0}
				if     rnd == 1 then addv.x = 1
				elseif rnd == 2 then addv.x = -1
				elseif rnd == 3 then addv.z = -1
				elseif rnd == 4 then addv.z = 1 end
				local ngp = addvectors(min_pos, addv)
				local lev = core.get_node_level(ngp)
				if core.get_node(ngp).name == "default:snow" and lev < min_level then
					min_level = lev
					min_pos = ngp
				end
			end

			pos = min_pos
			np = addvectors(pos, {x=0, y=1, z=0})
			add = core.add_node_level(pos, add);
			if default.time_speed <= 0 then add = 0 end
			if add > 0 then
				core.set_node(pos, {name="default:ice"})
			end
		end
		if add > 0 and core.get_node(np).name == "air" then
			core.set_node(np, {name="snow"})
			core.add_node_level(np, add)
		end
	end
})
--]]
