
-- erosion
core.register_abm({
	nodenames = {"default:stone"},
	neighbors = {"default:water_flowing"},
	interval = 300.0,
	chance = 100,
	action = function (pos, node, active_object_count, active_object_count_wider)
		local np = addvectors(pos, {x=0, y=1, z=0})
		local light = core.get_node_light(np, 0.5)

--print("erosion test stone " .. light .. " " .. core.get_node(np).name)
    	--if not light or light < default.LIGHT_SUN then return end
    	if not light or light < 13 then return end
        local top_name = core.get_node(np).name
		if top_name == "default:water_flowing" then
print("erosion stone")
			core.set_node(pos, {name="default:gravel"})
		end
	end
})

core.register_abm({
	nodenames = {"default:gravel"},
	neighbors = {"default:water_flowing"},
	interval = 200.0,
	chance = 70,
	action = function (pos, node, active_object_count, active_object_count_wider)
		local np = addvectors(pos, {x=0, y=1, z=0})
		local light = core.get_node_light(np, 0.5)
--print("erosion test gravel " .. light .. " " .. core.get_node(np).name)
    	--if not light or light < default.LIGHT_SUN then return end
    	if not light or light < 13 then return end
        local top_name = core.get_node(np).name
		if top_name == "default:water_flowing" then
print("erosion gravel")
			core.set_node(pos, {name="default:dirt"})
		end
	end
})
