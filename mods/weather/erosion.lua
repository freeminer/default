
-- erosion
core.register_abm({
	nodenames = {"default:stone"},
	neighbors = {"default:water_flowing"},
	interval = 300.0,
	chance = 100,
	action = function (pos, node, active_object_count, active_object_count_wider)
		local np = addvectors(pos, {x=0, y=1, z=0})
		local light = core.get_node_light(np, 0.5)
		if not light or light < 13 then return end
		local top_name = core.get_node(np).name
		if top_name == "default:water_flowing" then
			core.set_node(pos, {name="default:gravel"}, 2)
		end
	end
})

core.register_abm({
	nodenames = {"default:desert_stone"},
	neighbors = {"default:water_flowing"},
	interval = 300.0,
	chance = 150,
	action = function (pos, node, active_object_count, active_object_count_wider)
		local np = addvectors(pos, {x=0, y=1, z=0})
		local light = core.get_node_light(np, 0.5)
		if not light or light < 14 then return end
		local top_name = core.get_node(np).name
		if top_name == "default:water_flowing" then
			core.set_node(pos, {name="default:desert_sand"}, 2)
		end
	end
})

core.register_abm({
	nodenames = {"default:sandstone"},
	neighbors = {"default:water_flowing"},
	interval = 300.0,
	chance = 130,
	action = function (pos, node, active_object_count, active_object_count_wider)
		local np = addvectors(pos, {x=0, y=1, z=0})
		local light = core.get_node_light(np, 0.5)
		if not light or light < 14 then return end
		local top_name = core.get_node(np).name
		if top_name == "default:water_flowing" then
			core.set_node(pos, {name="default:sand"}, 2)
		end
	end
})

core.register_abm({
	nodenames = {"default:gravel"},
	neighbors = {"default:water_flowing"},
	interval = 200.0,
	chance = 50,
	action = function (pos, node, active_object_count, active_object_count_wider)
		local np = addvectors(pos, {x=0, y=1, z=0})
		local light = core.get_node_light(np, 0.5)
    	if not light or light < 12 then return end
        local top_name = core.get_node(np).name
		if top_name == "default:water_flowing" then
			core.set_node(pos, {name="default:dirt"})
		end
	end
})
