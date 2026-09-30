-- Explosion markers provide a brief flash, then leave air behind.
local function remove_boom(pos)
	if minetest.get_node(pos).name == "tnt:boom" then
		minetest.remove_node(pos)
	end
end

minetest.override_item("tnt:boom", {
	on_construct = function(pos)
		minetest.get_node_timer(pos):start(0.4)
	end,
	on_timer = function(pos)
		remove_boom(pos)
		return false
	end,
})

-- Old markers have no timer. Also clean up interrupted flashes on later loads.
minetest.register_lbm({
	label = "Remove stale TNT explosion markers",
	name = "tnt:remove_boom",
	nodenames = {"tnt:boom"},
	run_at_every_load = true,
	action = remove_boom,
})
