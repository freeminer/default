-- Rain
core.register_globalstep(function(dtime)
	for _, player in ipairs(core.get_connected_players()) do
		local ppos = player:getpos()
		local strength = get_rain(ppos)
		if strength > 0 and core.get_node(ppos).name == "air" then
--print("rain he=".. core.get_heat(ppos).." hu=".. core.get_humidity(ppos) .. " s=" .. strength)
		-- Make sure player is not in a cave/house...
		if core.get_node_light(ppos, 0.5) ~= 15 then return end

		local minp = addvectors(ppos, {x=-9, y=7, z=-9})
		local maxp = addvectors(ppos, {x= 9, y=7, z= 9})

		local vel = {x=0, y=   -4, z=0}
		local acc = {x=0, y=-9.81, z=0}

		core.add_particlespawner({
			amount=10*strength, time=0.5,
			minpos=minp, maxpos=maxp,
			minvel=vel, maxvel=vel,
			minacc=acc, maxacc=acc,
			minexptime=0.8, maxexptime=0.8,
			minsize=25, maxsize=25,
			collisiondetection=false, 
			vertical=true,
			texture="weather_rain.png",
			player=player:get_player_name()
		})
		end
	end
end)

core.register_abm({
	nodenames = {"group:crumbly", "group:snappy", "group:cracky", "group:choppy", "group:water"},
	neighbors = {"air"},
	interval = 15.0,
	chance = 50,
	action = function (pos, node, active_object_count, active_object_count_wider)
		-- todo! chance must depend on rain value
		local amount = get_rain(pos)
		if amount == 0 then return end
		amount = amount * 4
		if amount < 1 then amount = 1 end
		if core.registered_nodes[node.name].drawtype ~= "normal"
			and core.registered_nodes[node.name].drawtype ~= "nodebox"
			and core.registered_nodes[node.name].drawtype ~= "flowingliquid"
			and core.registered_nodes[node.name].drawtype ~= "liquid"
			and core.registered_nodes[node.name].drawtype ~= "allfaces_optional" then  return end
		local np = addvectors(pos, {x=0, y=1, z=0})
		if core.get_node_light(np, 0.5) ~= 15 then return end
			if core.get_node(pos).name == "default:water_flowing" then
				core.add_node_level(pos, 4*amount)
			elseif core.get_node(np).name == "air" then
				core.set_node(np, {name="water_flowing"})
				core.set_node_level(np, amount)
			end
	end
})

-- evaporate
core.register_abm({
	nodenames = {"default:water_flowing"},
	neighbors = {"air"},
	interval = 10.0,
	chance = 10,
	action = function (pos, node, active_object_count, active_object_count_wider)
		-- todo! chance must depend on humidity and temperature
		local humidity = core.get_humidity(pos)
		if get_rain(pos) > 0 or humidity > 90 then return end
		local np = addvectors(pos, {x=0, y=1, z=0})
		--if core.get_node_light(np, 0.5) == 15 then
		if core.get_node(np).name == "air" then
		local amount = ((100-humidity)/20)
		if amount < 1 then amount = 1 end
			core.add_node_level(pos, -amount)
		end
	end
})
