-- A registered "ignore" node is not a valid place to spawn a dropped object.
return function(center, pos, radius)
	for _ = 1, 5 do
		pos.x = center.x + math.random(-radius, radius)
		pos.y = center.y
		pos.z = center.z + math.random(-radius, radius)
		local node = core.get_node_or_nil(pos)
		local def = node and core.registered_nodes[node.name]
		if node and node.name ~= "ignore" and def and not def.walkable then
			return
		end
	end
	-- The explosion origin is already loaded; keep the fallback local.
	pos.x, pos.y, pos.z = center.x, center.y, center.z
end
