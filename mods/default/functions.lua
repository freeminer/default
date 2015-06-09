-- mods/default/functions.lua

--
-- Sounds
--

function default.node_sound_defaults(table)
	table = table or {}
	table.footstep = table.footstep or
			{name="", gain=1.0}
	table.dug = table.dug or
			{name="default_dug_node", gain=0.25}
	table.place = table.place or
			{name="default_place_node_hard", gain=1.0}
	return table
end

function default.node_sound_stone_defaults(table)
	table = table or {}
	table.footstep = table.footstep or
			{name="default_hard_footstep", gain=0.5}
	table.dug = table.dug or
			{name="default_hard_footstep", gain=1.0}
	default.node_sound_defaults(table)
	return table
end

function default.node_sound_dirt_defaults(table)
	table = table or {}
	table.footstep = table.footstep or
			{name="default_dirt_footstep", gain=1.0}
	table.dug = table.dug or
			{name="default_dirt_footstep", gain=1.5}
	table.place = table.place or
			{name="default_place_node", gain=1.0}
	default.node_sound_defaults(table)
	return table
end

function default.node_sound_sand_defaults(table)
	table = table or {}
	table.footstep = table.footstep or
			{name="default_sand_footstep", gain=0.2}
	table.dug = table.dug or
			{name="default_sand_footstep", gain=0.4}
	table.place = table.place or
			{name="default_place_node", gain=1.0}
	default.node_sound_defaults(table)
	return table
end

function default.node_sound_wood_defaults(table)
	table = table or {}
	table.footstep = table.footstep or
			{name="default_wood_footstep", gain=0.5}
	table.dug = table.dug or
			{name="default_wood_footstep", gain=1.0}
	default.node_sound_defaults(table)
	return table
end

function default.node_sound_leaves_defaults(table)
	table = table or {}
	table.footstep = table.footstep or
			{name="default_grass_footstep", gain=0.35}
	table.dug = table.dug or
			{name="default_grass_footstep", gain=0.7}
	table.dig = table.dig or
			{name="default_dig_crumbly", gain=0.4}
	table.place = table.place or
			{name="default_place_node", gain=1.0}
	default.node_sound_defaults(table)
	return table
end

function default.node_sound_glass_defaults(table)
	table = table or {}
	table.footstep = table.footstep or
			{name="default_glass_footstep", gain=0.5}
	table.dug = table.dug or
			{name="default_break_glass", gain=1.0}
	default.node_sound_defaults(table)
	return table
end


--
-- Lavacooling
--

minetest.register_abm({
	nodenames = {"default:lava_source", "default:lava_flowing"},
	neighbors = {"group:water"},
	interval = 3,
	chance = 3,
	action = function(pos, node, active_object_count, active_object_count_wider)
		core.freeze_melt(pos, -1);
		minetest.sound_play("default_cool_lava", {pos = pos,  gain = 0.25})
	end,
})

minetest.register_abm({
	nodenames = {"default:lava_source", "default:lava_flowing"},
	interval = 100,
	chance = 10,
	action = function(pos, node, active_object_count, active_object_count_wider)
		-- bad place: to not freeze lava in caves
		if not pos.y or pos.y < -100 then return end
		-- skip springs
		if node.param2 >= 128 then return end
		local light = core.get_node_light({x=pos.x,y=pos.y+1, z=pos.z}, 0.5)
		if not light or light < default.LIGHT_MAX then return end
		core.freeze_melt(pos, -1);
	end,
})


--
-- Papyrus and cactus growing
--

function default.grow_cactus(pos, node)
	if node.param2 ~= 0 then
		return
	end
	pos.y = pos.y-1
	if minetest.get_item_group(minetest.get_node(pos).name, "sand") == 0 then
		return
	end
	pos.y = pos.y+1
	local height = 0
	while node.name == "default:cactus" and height < 4 and node.param2 == 0 do
		height = height+1
		pos.y = pos.y+1
		node = minetest.get_node(pos)
	end
	if height == 4
	or node.name ~= "air" then
		return
	end
	minetest.set_node(pos, {name="default:cactus"})
	return true
end

function default.grow_papyrus(pos, node)
	pos.y = pos.y-1
	local name = minetest.get_node(pos).name
	if name ~= "default:dirt_with_grass"
	and name ~= "default:dirt" then
		return
	end
	if not minetest.find_node_near(pos, 3, {"group:water"}) then
		return
	end
	pos.y = pos.y+1
	local height = 0
	while node.name == "default:papyrus" and height < 4 do
		height = height+1
		pos.y = pos.y+1
		node = minetest.get_node(pos)
	end
	if height == 4
	or node.name ~= "air" then
		return
	end
	minetest.set_node(pos, {name="default:papyrus"})
	return true
end

-- wrapping the functions in abm action is necessary to make overriding them possible
minetest.register_abm({
	nodenames = {"default:cactus"},
	neighbors = {"group:sand", "default:dirt_dry", "default:dirt_dry_grass"},
	interval = 50,
	chance = 20,
	action = function(...)
		default.grow_cactus(...)
	end
})

minetest.register_abm({
	nodenames = {"default:papyrus"},
	neighbors = {"default:dirt", "default:dirt_with_grass"},
	interval = 50,
	chance = 20,
	action = function(...)
		default.grow_papyrus(...)
	end
})


--
-- dig upwards
--

function default.dig_up(pos, node, digger)
	if digger == nil then return end
	local np = {x = pos.x, y = pos.y + 1, z = pos.z}
	local nn = minetest.get_node(np)
	if nn.name == node.name then
		minetest.node_dig(np, nn, digger)
	end
end


--
-- Leafdecay
--

default.leafdecay_trunk_cache = {}
default.leafdecay_enable_cache = true
-- Spread the load of finding trunks
default.leafdecay_trunk_find_allow_accumulator = 0

minetest.register_globalstep(function(dtime)
	local finds_per_second = 5000
	default.leafdecay_trunk_find_allow_accumulator =
			math.floor(dtime * finds_per_second)
end)

default.after_place_leaves = function(pos, placer, itemstack, pointed_thing)
	local node = minetest.get_node(pos)
	node.param2 = 1
	minetest.set_node(pos, node)
end

minetest.register_abm({
	nodenames = {"group:leafdecay"},
	neighbors = {"air", "group:liquid"},
	-- A low interval and a high inverse chance spreads the load
	interval = 10,
	chance = 3,

	action = function(p0, node, _, _)
		--print("leafdecay ABM at "..p0.x..", "..p0.y..", "..p0.z..")")
		local do_preserve = false
		local d = minetest.registered_nodes[node.name].groups.leafdecay
		if not d or d == 0 then
			--print("not groups.leafdecay")
			return
		end
		local n0 = minetest.get_node(p0)
		if n0.param2 ~= 0 then
			--print("param2 ~= 0")
			return
		end
		local p0_hash = nil
		if default.leafdecay_enable_cache then
			p0_hash = minetest.hash_node_position(p0)
			local trunkp = default.leafdecay_trunk_cache[p0_hash]
			if trunkp then
				local n = minetest.get_node(trunkp)
				local reg = minetest.registered_nodes[n.name]
				-- Assume ignore is a trunk, to make the thing work at the border of the active area
				if n.name == "ignore" or (reg and reg.groups.tree and reg.groups.tree ~= 0) then
					--print("cached trunk still exists")
					return
				end
				--print("cached trunk is invalid")
				-- Cache is invalid
				table.remove(default.leafdecay_trunk_cache, p0_hash)
			end
		end
		if default.leafdecay_trunk_find_allow_accumulator <= 0 then
			return
		end
		default.leafdecay_trunk_find_allow_accumulator =
				default.leafdecay_trunk_find_allow_accumulator - 1
		-- Assume ignore is a trunk, to make the thing work at the border of the active area
		local p1 = minetest.find_node_near(p0, d, {"ignore", "group:tree"})
		if p1 then
			do_preserve = true
			if default.leafdecay_enable_cache then
				--print("caching trunk")
				-- Cache the trunk
				default.leafdecay_trunk_cache[p0_hash] = p1
			end
		end
		if not do_preserve then
			-- Drop stuff other than the node itself
			local itemstacks = minetest.get_node_drops(n0.name)
			for _, itemname in ipairs(itemstacks) do
				if minetest.get_item_group(n0.name, "leafdecay_drop") ~= 0 or
						itemname ~= n0.name then
					local p_drop = {
						x = p0.x - 0.5 + math.random(),
						y = p0.y - 0.5 + math.random(),
						z = p0.z - 0.5 + math.random(),
					}
					minetest.add_item(p_drop, itemname)
				end
			end
			-- Remove node
			minetest.remove_node(p0)
			nodeupdate(p0)
		end
	end
})

--
-- Grass growing
--

minetest.register_abm({
	nodenames = {"default:dirt", "default:dirt_dry", "default:dirt_dry_grass" },
	interval = 10,
	chance = 30,
	action = function(pos, node)
		local above = {x=pos.x, y=pos.y+1, z=pos.z}
		local name = core.get_node(above).name
		local nodedef = core.registered_nodes[name]
		if (name == "ignore" or not nodedef) then return end
		if ( not ((nodedef.sunlight_propagates or nodedef.paramtype == "light") and nodedef.liquidtype == "none")) then return end
		if (default.weather and core.get_heat(pos) < -10) or name == "default:snow" or
			name == "default:snowblock" or name == "default:ice"
		then
			core.set_node(pos, {name = "default:dirt_with_snow"}, 2)
		elseif (not default.weather or (core.get_heat(pos) > 5 and core.get_humidity(pos) > 22)) and nodedef and
			(core.get_node_light(above) or 0) >= 13
		then
			core.set_node(pos, {name = "default:dirt_with_grass"}, 2)
		end
	end
})

minetest.register_abm({
	nodenames = {"default:dirt_with_grass", "default:dirt_dry_grass"},
	interval = 10,
	chance = 10,
	action = function(pos, node)
		local above = {x=pos.x, y=pos.y+1, z=pos.z}
		local name = minetest.get_node(above).name
		local nodedef = minetest.registered_nodes[name]
		if (name == "ignore" or not nodedef) then return end
		if ( not ((nodedef.sunlight_propagates or nodedef.paramtype == "light")
				and nodedef.liquidtype == "none")) or (default.weather
				and (core.get_heat(pos) < -5 or core.get_heat(pos) > 50 or core.get_humidity(pos) < 10))
				or name == "default:snow" or name == "default:snowblock" or name == "default:ice"
		then
			if name == "default:dirt_with_grass" then
				core.set_node(pos, {name = "default:dirt"}, 2)
			elseif name == "default:dirt_dry_grass" then
				core.set_node(pos, {name = "default:dirt_dry"}, 2)
			end
		elseif name == "air" and (default.weather and core.get_heat(pos) > 5 and core.get_heat(pos) < 40 and core.get_humidity(pos) > 20) 
			and math.random(1, 50) == 1 and (core.get_node_light(above) or 0) >= 13 then
			core.set_node(above, {name = "default:grass_1"}, 2)
		end
	end
})

minetest.register_abm({
	nodenames = {"default:grass_1", "default:grass_2", "default:grass_3", "default:grass_4", "default:grass_5"},
	neighbors = {"default:dirt_with_grass", "default:dirt"},
	interval = 20,
	chance = 30,
	action = function(pos, node)
		local humidity = core.get_humidity(pos)
		local heat = core.get_heat(pos)
		if heat < 5 or heat > 40 or (core.get_node_light(pos) or 0) < 12 then return end
		local rnd = math.random(1, 110-humidity)
		local node = core.get_node(pos)
		local name = node.name
		if name == "default:grass_5" then
				if rnd >= 2 then return end
				if     humidity > 75 and heat > 25 then node.name = "default:junglesapling" 
				elseif humidity > 40 then node.name = "default:sapling"
				elseif humidity > 30 and heat < 10 then node.name = "default:pine_sapling"
				else return end
				core.set_node(pos, node, 2)
		else
			for i=1,4 do
				if rnd >= i+5 then return end
				if name == "default:grass_"..i then
					node.name = "default:grass_"..(i+1)
					core.set_node(pos, node, 2)
				end
			end
		end
	end
})


core.register_abm({
	nodenames = {"default:dirt_with_snow"},
	interval = 10,
	chance = 100,
	action = function(pos, node)
		local above = {x=pos.x, y=pos.y+1, z=pos.z}
		local name = core.get_node(above).name
		local nodedef = core.registered_nodes[name]
		if (name == "ignore" or not nodedef) then return end
		if (not ((nodedef.sunlight_propagates or nodedef.paramtype == "light")
				and nodedef.liquidtype == "none") or
			(default.weather and core.get_heat(pos) > 3 and name ~= "default:snow" and name ~= "default:snowblock" and name ~= "default:ice"))
		then
			if core.get_humidity(pos) > 30 then
				core.set_node(pos, {name = "default:dirt"}, 2)
			else
				core.set_node(pos, {name = "default:dirt_dry"}, 2)
			end
		end
	end
})

if default.weather then
core.register_abm({
	nodenames = {"default:sand", "default:desert_sand", "default:dirt_dry", "default:dirt_dry_grass"},
	neighbors = {"default:water_flowing"},
	interval = 20,
	neighbors_range = 3,
	chance = 10,
	action = function(pos, node)
		if ((core.get_heat(pos) > 40 or core.get_humidity(pos) < 20)) then return end
		if node.name == "default:dirt_dry_grass" then
			core.set_node(pos, {name = "default:dirt_with_grass"}, 2)
		else
			core.set_node(pos, {name = "default:dirt"}, 2)
		end
	end
})

core.register_abm({
	nodenames = {"default:cobble"},
	neighbors = {"default:water_flowing"},
	interval = 20,
	neighbors_range = 2,
	chance = 50,
	action = function(pos, node)
		if ((core.get_heat(pos) < 5 or core.get_heat(pos) > 40 or core.get_humidity(pos) < 20)) then return end
		core.set_node(pos, {name = "default:mossycobble", param1 = node.param1, param2 = node.param2, }, 2)
	end
})
end
