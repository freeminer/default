-- A timed-out explosion must not recursively spend another full budget in Lua.
return function(positions, def)
	for _, pos in ipairs(positions or {}) do
		local next_pos = vector.new(pos)
		local next_def = table.copy(def)
		core.after(0, function()
			local node = core.get_node(next_pos)
			local burning = next_def.tnt_burning_node or "tnt:tnt_burning"
			if node.name ~= burning then return end
			core.get_node_timer(next_pos):stop()
			tnt.boom(next_pos, next_def)
		end)
	end
end
