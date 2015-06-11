-- Snow
core.register_globalstep(function(dtime)
	for _, player in ipairs(core.get_connected_players()) do
		local ppos = player:getpos()
		local strength = get_snow(ppos)
		if strength > 0 and core.get_node(ppos).name == "air" then
--print("snow he=".. core.get_heat(ppos).." hu=".. core.get_humidity(ppos) .. " s=" .. strength)
		-- Make sure player is not in a cave/house...
		if core.get_node_light(ppos, 0.5) ~= 15 then return end

		local minp = addvectors(ppos, {x=-9, y=7, z=-9})
		local maxp = addvectors(ppos, {x= 9, y=7, z= 9})

		local minp_deep = addvectors(ppos, {x=-10, y=3.2, z=-10})
		local maxp_deep = addvectors(ppos, {x= 10, y=2.6, z= 10})

		local vel = {x=0, y=   -0.5, z=0}
		local acc = {x=0, y=   -0.5, z=0}

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
		end
	end
end)

local snow_box =
{
	type  = "fixed",
	fixed = {-0.5, -0.5, -0.5, 0.5, -0.4, 0.5}
}


-- -[[ Enable this section if you have a very fast PC
core.register_abm({
	nodenames = {"group:crumbly", "group:snappy", "group:cracky", "group:choppy", "group:melts"},
	neighbors = {"air"},
	interval = 10.0, 
	chance = 50,
	--interval = 1.0, 
	--chance = 5,
	action = function (pos, node, active_object_count, active_object_count_wider)
		local amount = get_snow(pos)
		if amount == 0 then return end
		if core.registered_nodes[node.name].drawtype ~= "normal"
			and core.registered_nodes[node.name].drawtype ~= "nodebox"
			and core.registered_nodes[node.name].drawtype ~= "allfaces_optional" then return end
		local np = addvectors(pos, {x=0, y=1, z=0})
		if core.get_node_light(np, 0.5) ~= 15 then return end
		local addsnow = 1
		if core.get_node(pos).name == "default:snow" then
			if core.add_node_level(pos, 4) > 0 then
				core.set_node(pos, {name="default:ice"})
			else
				addsnow = 0
			end
		end
		if addsnow > 0 and core.get_node(np).name == "air" then
			core.set_node(np, {name="snow"})
			core.add_node_level(np)
		end
	end
})
--]]
