-- Freeminer-specific extensions for Minetest Game default nodes.

local light_max = core.LIGHT_MAX or 14

local function override_item(name, redefinition, del_fields)
	if core.override_item_if_exists then
		return core.override_item_if_exists(name, redefinition, del_fields)
	end

	if not core.registered_items[name] then
		return false
	end

	core.override_item(name, redefinition, del_fields)
	return true
end

local function add_groups(name, groups)
	local item = core.registered_items[name]
	if not item then
		return false
	end

	local merged_groups = {}
	for group, value in pairs(item.groups or {}) do
		merged_groups[group] = value
	end
	for group, value in pairs(groups) do
		merged_groups[group] = value
	end

	return override_item(name, {groups = merged_groups})
end

local function update_node(name, groups, fields, del_fields)
	if groups then
		add_groups(name, groups)
	end
	if fields or del_fields then
		override_item(name, fields or {}, del_fields)
	end
end

local flowing_sand_type = "source"
local flowing_sand_leveled = 1
local flowing_sand_paramtype2 = "leveled"
local flowing_sand_liquid_drop = 1
local flowing_sand_disable = tonumber(core.settings:get("flowing_sand_disable") or 0) or 0

if flowing_sand_disable == 1 then
	flowing_sand_type = "none"
	flowing_sand_leveled = 0
	flowing_sand_paramtype2 = "none"
end
if flowing_sand_disable >= 1 then
	flowing_sand_liquid_drop = 0
end

local lava_stones = {
	"default:stone",
	"default:cobble",
	"default:stonebrick",
	"default:desert_stone",
	"default:desert_cobble",
	"default:desert_stonebrick",
	"default:sandstone",
	"default:sandstonebrick",
}

for _, name in ipairs(lava_stones) do
	update_node(name, {melt = 3000}, {melt = "default:lava_source"})
end

update_node("default:mossycobble", {melt = 200}, {melt = "default:cobble"})
update_node("default:obsidian", {melt = 5000}, {melt = "default:lava_source"})
update_node("default:obsidianbrick", {melt = 5000}, {melt = "default:lava_source"})

update_node("default:dirt", {
	melt = 50,
	liquid_drop = flowing_sand_liquid_drop,
	weight = 2000,
	fall_damage_add_percent = -20,
}, {
	leveled = flowing_sand_leveled,
	liquidtype = flowing_sand_type,
	paramtype2 = flowing_sand_paramtype2,
	drowning = 1,
	melt = "default:dry_dirt",
})

update_node("default:dirt_with_grass", {
	melt = 51,
	freeze = -5,
	fall_damage_add_percent = -10,
}, {
	drowning = 1,
	melt = "default:dirt_with_dry_grass",
	freeze = "default:dirt_with_snow",
})

update_node("default:dirt_with_grass_footsteps", {
	melt = 51,
	freeze = -5,
	fall_damage_add_percent = -10,
}, {
	drowning = 1,
	melt = "default:dirt_with_dry_grass",
	freeze = "default:dirt_with_snow",
})

update_node("default:dirt_with_dry_grass", {
	melt = 71,
	freeze = -5,
}, {
	drowning = 1,
	melt = "default:dry_dirt",
	freeze = "default:dirt_with_snow",
})

update_node("default:dirt_with_snow", {
	slippery = 2,
	melt = 2,
	fall_damage_add_percent = -10,
}, {
	drowning = 1,
	melt = "default:dirt",
})

update_node("default:dry_dirt", {melt = 81}, {
	drowning = 1,
	melt = "default:sand",
})

local flowing_sands = {
	["default:sand"] = 2000,
	["default:desert_sand"] = 2001,
	["default:silver_sand"] = 2002,
}

for name, weight in pairs(flowing_sands) do
	update_node(name, {
		liquid_drop = flowing_sand_liquid_drop,
		weight = weight,
		fall_damage_add_percent = -30,
	}, {
		is_ground_content = name ~= "default:silver_sand" or nil,
		leveled = flowing_sand_leveled,
		liquidtype = flowing_sand_type,
		paramtype2 = flowing_sand_paramtype2,
		drowning = 1,
	})
end

update_node("default:gravel", {
	liquid_drop = flowing_sand_liquid_drop,
	weight = 2000,
	fall_damage_add_percent = -5,
}, {
	leveled = flowing_sand_leveled,
	liquidtype = flowing_sand_type,
	paramtype2 = flowing_sand_paramtype2,
	drowning = 1,
})

update_node("default:clay", {
	melt = 1500,
	fall_damage_add_percent = -10,
}, {
	drop = "default:clay",
	melt = "default:stone",
})

update_node("default:snow", {
	melt = 1,
	float = 1,
	slippery = 2,
	fall_damage_add_percent = -70,
}, {
	node_box = {
		type = "leveled",
		fixed = {
			{-0.5, -0.5, -0.5, 0.5, -0.25, 0.5},
		},
	},
	on_construct = function(pos)
		pos.y = pos.y - 1
		if minetest.get_node(pos).name == "default:dirt_with_grass" then
			minetest.set_node(pos, {name = "default:dirt_with_snow"}, 2)
		end
	end,
	leveled = 7,
	paramtype2 = "leveled",
	melt = "default:water_flowing",
})

update_node("default:snowblock", {
	melt = 2,
	slippery = 2,
	fall_damage_add_percent = -30,
}, {
	melt = "default:water_source",
})

update_node("default:ice", {melt = 3}, {
	melt = "default:water_source",
	drowning = 1,
	drawtype = "glasslike",
	use_texture_alpha = true,
})

update_node("default:cave_ice", {melt = 4}, {
	melt = "default:water_source",
	drowning = 1,
	drawtype = "glasslike",
	use_texture_alpha = true,
})

update_node("default:tree", {grow_tree = 1}, {
	liquid_alternative_source = "default:leaves",
})
update_node("default:leaves", {
	fall_damage_add_percent = -40,
	grow_leaves = 1,
}, {
	liquid_alternative_source = "default:apple",
})
update_node("default:apple", {fruit = 1})

update_node("default:jungletree", {
	grow_tree = 1,
	tree_water_max = 65,
	tree_get_water_max_from_humidity = 36,
	tree_grow_heat_min = 19,
	tree_grow_heat_max = 49,
	leaves_water_max = 30,
	leaves_grow_heat_min = 19,
	leaves_grow_heat_max = 49,
	tree_branch_chance = 20,
	tree_branch_water_min = 30,
	tree_branch_spacing = 3,
	tree_branch_cost = 3,
}, {
	liquid_alternative_source = "default:jungleleaves",
})

update_node("default:jungleleaves", {
	grow_leaves = 1,
	leaves_water_max = 30,
	leaves_grow_heat_min = 19,
	leaves_grow_heat_max = 49,
	leaves_die_heat_min = 60,
	fall_damage_add_percent = -40,
})

update_node("default:pine_tree", {
	grow_tree = 1,
	tree_water_max = 65,
	tree_grow_heat_min = 3,
	leaves_water_max = 10,
	leaves_grow_prefer_top = 1,
	leaves_die_heat_max = 0,
}, {
	liquid_alternative_source = "default:pine_needles",
})

update_node("default:pine_needles", {
	grow_leaves = 1,
	leaves_water_max = 10,
	leaves_grow_prefer_top = 1,
	leaves_die_heat_max = 0,
	fall_damage_add_percent = -20,
})

update_node("default:acacia_tree", {
	grow_tree = 1,
	tree_water_max = 40,
	tree_get_water_from_humidity = 15,
	tree_get_water_max_from_humidity = 12,
	tree_grow_water_min = 3,
	tree_grow_heat_min = 18,
	tree_grow_heat_max = 55,
	tree_grow_light_max = 13,
	tree_branch_chance = 12,
	tree_branch_water_min = 8,
	tree_branch_spacing = 2,
	tree_branch_cost = 2,
	leaves_water_max = 14,
	leaves_grow_light_min = 10,
	leaves_grow_water_min_top = 4,
	leaves_grow_water_min_side = 2,
	leaves_grow_heat_min = 18,
	leaves_grow_heat_max = 55,
	leaves_die_light_max = 9,
	leaves_die_heat_min = 0,
}, {
	liquid_alternative_source = "default:acacia_leaves",
})

update_node("default:acacia_leaves", {
	grow_leaves = 1,
	tree_get_water_from_humidity = 15,
	leaves_water_max = 14,
	leaves_grow_light_min = 10,
	leaves_grow_water_min_top = 4,
	leaves_grow_water_min_side = 2,
	leaves_grow_heat_min = 18,
	leaves_grow_heat_max = 55,
	leaves_die_light_max = 9,
	leaves_die_heat_min = 0,
	fall_damage_add_percent = -30,
})

update_node("default:aspen_tree", {
	grow_tree = 1,
	tree_water_max = 50,
	tree_grow_heat_min = 0,
	tree_grow_heat_max = 35,
	leaves_water_max = 10,
	leaves_grow_light_min = 9,
	leaves_grow_heat_min = 0,
	leaves_grow_heat_max = 35,
	leaves_die_light_max = 8,
	leaves_die_heat_min = 45,
}, {
	liquid_alternative_source = "default:aspen_leaves",
})

update_node("default:aspen_leaves", {
	grow_leaves = 1,
	leaves_water_max = 10,
	leaves_grow_light_min = 9,
	leaves_grow_heat_min = 0,
	leaves_grow_heat_max = 35,
	leaves_die_light_max = 8,
	leaves_die_heat_min = 45,
})

update_node("default:stone_with_mese", {
	wield_light = 3,
}, {
	paramtype = "light",
	light_source = 3,
})
update_node("default:mese", {
	wield_light = 5,
}, {
	paramtype = "light",
	light_source = 5,
})

update_node("default:cactus", {
	grow_tree = 1,
	tree_get_water_from_humidity = 40,
	leaves_grow_light_min = 13,
	tree_grow_light_max = 15,
	tree_grow_chance = 30,
	tree_water_max = 6,
	tree_grow_water_min = 2,
	tree_grow_heat_min = 20,
	tree_grow_heat_max = 40,
	tree_grow_bottom = 0,
	tree_branch_chance = 0,
	tree_width_to_height = 0,
})

update_node("default:papyrus", {
	dig_immediate = 3,
	grow_tree = 1,
	tree_get_water_from_humidity = 0,
	leaves_grow_light_min = 12,
	tree_grow_light_max = 15,
	tree_grow_chance = 20,
	tree_water_max = 8,
	tree_grow_water_min = 2,
	tree_grow_heat_min = 20,
	tree_grow_heat_max = 30,
	tree_water_param2 = 1,
	tree_grow_bottom = 0,
	tree_branch_chance = 0,
	tree_width_to_height = 0,
})

update_node("default:dry_shrub", {
	dig_immediate = 3,
	drop_by_liquid = 1,
	falling_node = 1,
})

update_node("default:junglegrass", {
	dig_immediate = 3,
	drop_by_liquid = 1,
	melt = 50,
	falling_node = 1,
	fall_damage_add_percent = -20,
}, {
	melt = "default:dry_grass_5",
})

for i = 1, 5 do
	update_node("default:grass_" .. i, {
		dig_immediate = 3,
		drop_by_liquid = 1,
		melt = 40,
		falling_node = 1,
	}, {
		melt = "default:dry_grass_" .. i,
	})
end

for i = 1, 5 do
	update_node("default:dry_grass_" .. i, {
		dig_immediate = 3,
		drop_by_liquid = 1,
		falling_node = 1,
	})
end

update_node("default:water_source", {
	freeze = -1,
	melt = 105,
	liquid_drop = 1,
	weight = 1000,
	pressure = 32,
}, {
	leveled = 8,
	paramtype2 = "leveled",
	freeze = "default:ice",
	melt = "air",
	light_vertical_dimnish = 0.1,
})

update_node("default:water_flowing", {
	freeze = -5,
	melt = 100,
	liquid_drop = 1,
	weight = 1000,
}, {
	leveled = 8,
	paramtype2 = "leveled",
	freeze = "default:snow",
	melt = "air",
})

core.register_alias_force("default:river_water_source", "default:water_source")
core.register_alias_force("default:river_water_flowing", "default:water_flowing")

update_node("default:lava_source", {
	hot = 1200,
	wield_light = 5,
	liquid_drop = 1,
	weight = 2000,
	pressure = 32,
}, {
	paramtype2 = "leveled",
	leveled = 4,
	freeze = "default:obsidian",
})

update_node("default:lava_flowing", {
	hot = 700,
	wield_light = 2,
	liquid_drop = 1,
	weight = 2000,
}, {
	paramtype2 = "leveled",
	leveled = 4,
	freeze = "default:stone",
})

update_node("default:glass", {melt = 1500}, {
	melt = "default:obsidian_glass",
}, {"sunlight_propagates"})

update_node("default:brick", {melt = 3500}, {
	melt = "default:lava_source",
})

update_node("default:meselamp", {
	wield_light = light_max,
	hot = 30,
})

for _, name in ipairs({
	"default:mese_post_light",
	"default:mese_post_light_acacia_wood",
	"default:mese_post_light_junglewood",
	"default:mese_post_light_pine_wood",
	"default:mese_post_light_aspen_wood",
}) do
	update_node(name, {
		wield_light = light_max,
	})
end

for _, name in ipairs({
	"default:torch",
	"default:torch_wall",
	"default:torch_ceiling",
}) do
	update_node(name, {
		hot = 39,
		wield_light = light_max - 1,
		drop_by_liquid = 1,
	})
end

local optional_wield_light_nodes = {
	{"fireflies:firefly", 6},
	{"fireflies:firefly_bottle", 9},
	{"pbj_pup:pbj_pup", 14},
	{"nyancat:nyancat", 14},
	{"moognu:moognu", 14},
	{"nyancat:nyancat_rainbow", 14},
	{"protector:protect", 4},
	{"protector:protect2", 4},
}

core.register_on_mods_loaded(function()
	for _, def in ipairs(optional_wield_light_nodes) do
		update_node(def[1], {
			wield_light = def[2],
		})
	end
end)

-- Explicit TNT resistance for the C++ blast solver.  Values are the strength
-- cost a blast ray pays when it crosses or destroys this node.
local tnt_resistance_by_node = {
	["default:stone"] = 6.0,
	["default:cobble"] = 5.5,
	["default:stonebrick"] = 6.5,
	["default:stone_block"] = 7.0,
	["default:mossycobble"] = 4.5,
	["default:desert_stone"] = 6.0,
	["default:desert_cobble"] = 5.5,
	["default:desert_stonebrick"] = 6.5,
	["default:desert_stone_block"] = 7.0,
	["default:sandstone"] = 4.0,
	["default:sandstonebrick"] = 4.5,
	["default:sandstone_block"] = 5.0,
	["default:desert_sandstone"] = 4.0,
	["default:desert_sandstone_brick"] = 4.5,
	["default:desert_sandstone_block"] = 5.0,
	["default:silver_sandstone"] = 4.0,
	["default:silver_sandstone_brick"] = 4.5,
	["default:silver_sandstone_block"] = 5.0,
	["default:obsidian"] = 35.0,
	["default:obsidianbrick"] = 40.0,
	["default:obsidian_block"] = 45.0,

	["default:dirt"] = 1.2,
	["default:dirt_with_grass"] = 1.2,
	["default:dirt_with_grass_footsteps"] = 1.1,
	["default:dirt_with_dry_grass"] = 1.1,
	["default:dirt_with_snow"] = 1.3,
	["default:dirt_with_rainforest_litter"] = 1.2,
	["default:dirt_with_coniferous_litter"] = 1.2,
	["default:dry_dirt"] = 1.3,
	["default:dry_dirt_with_dry_grass"] = 1.2,
	["default:permafrost"] = 2.4,
	["default:permafrost_with_stones"] = 3.0,
	["default:permafrost_with_moss"] = 2.5,
	["default:sand"] = 1.0,
	["default:desert_sand"] = 1.1,
	["default:silver_sand"] = 1.0,
	["default:gravel"] = 1.5,
	["default:clay"] = 1.7,
	["default:snow"] = 0.2,
	["default:snowblock"] = 0.8,
	["default:ice"] = 1.5,
	["default:cave_ice"] = 1.8,

	["default:tree"] = 2.6,
	["default:wood"] = 2.3,
	["default:sapling"] = 0.5,
	["default:leaves"] = 0.8,
	["default:apple"] = 0.4,
	["default:apple_mark"] = 0.4,
	["default:jungletree"] = 2.8,
	["default:junglewood"] = 2.4,
	["default:jungleleaves"] = 0.9,
	["default:junglesapling"] = 0.5,
	["default:emergent_jungle_sapling"] = 0.5,
	["default:pine_tree"] = 2.6,
	["default:pine_wood"] = 2.3,
	["default:pine_needles"] = 0.7,
	["default:pine_sapling"] = 0.5,
	["default:acacia_tree"] = 3.0,
	["default:acacia_wood"] = 2.6,
	["default:acacia_leaves"] = 0.8,
	["default:acacia_sapling"] = 0.5,
	["default:aspen_tree"] = 2.4,
	["default:aspen_wood"] = 2.1,
	["default:aspen_leaves"] = 0.7,
	["default:aspen_sapling"] = 0.5,

	["default:stone_with_coal"] = 6.5,
	["default:coalblock"] = 4.5,
	["default:stone_with_iron"] = 7.0,
	["default:steelblock"] = 16.0,
	["default:stone_with_copper"] = 7.0,
	["default:copperblock"] = 12.0,
	["default:stone_with_tin"] = 7.0,
	["default:tinblock"] = 11.0,
	["default:bronzeblock"] = 14.0,
	["default:stone_with_mese"] = 10.0,
	["default:mese"] = 18.0,
	["default:stone_with_gold"] = 8.0,
	["default:goldblock"] = 10.0,
	["default:stone_with_diamond"] = 12.0,
	["default:diamondblock"] = 24.0,

	["default:cactus"] = 1.2,
	["default:large_cactus_seedling"] = 0.8,
	["default:papyrus"] = 0.7,
	["default:dry_shrub"] = 0.4,
	["default:junglegrass"] = 0.5,
	["default:bush_stem"] = 1.4,
	["default:bush_leaves"] = 0.8,
	["default:bush_sapling"] = 0.5,
	["default:blueberry_bush_leaves_with_berries"] = 0.8,
	["default:blueberry_bush_leaves"] = 0.8,
	["default:blueberry_bush_sapling"] = 0.5,
	["default:acacia_bush_stem"] = 1.6,
	["default:acacia_bush_leaves"] = 0.8,
	["default:acacia_bush_sapling"] = 0.5,
	["default:pine_bush_stem"] = 1.4,
	["default:pine_bush_needles"] = 0.7,
	["default:pine_bush_sapling"] = 0.5,
	["default:sand_with_kelp"] = 1.0,
	["default:coral_green"] = 1.2,
	["default:coral_pink"] = 1.2,
	["default:coral_cyan"] = 1.2,
	["default:coral_brown"] = 3.0,
	["default:coral_orange"] = 3.0,
	["default:coral_skeleton"] = 3.5,

	["default:water_source"] = 0.25,
	["default:water_flowing"] = 0.2,
	["default:river_water_source"] = 0.25,
	["default:river_water_flowing"] = 0.2,
	["default:lava_source"] = 1.5,
	["default:lava_flowing"] = 1.2,

	["default:bookshelf"] = 1.8,
	["default:sign_wall_wood"] = 1.2,
	["default:sign_wall_steel"] = 5.5,
	["default:ladder_wood"] = 1.0,
	["default:ladder_steel"] = 5.0,
	["default:fence_wood"] = 1.6,
	["default:fence_acacia_wood"] = 1.8,
	["default:fence_junglewood"] = 1.7,
	["default:fence_pine_wood"] = 1.6,
	["default:fence_aspen_wood"] = 1.5,
	["default:fence_rail_wood"] = 1.3,
	["default:fence_rail_acacia_wood"] = 1.5,
	["default:fence_rail_junglewood"] = 1.4,
	["default:fence_rail_pine_wood"] = 1.3,
	["default:fence_rail_aspen_wood"] = 1.2,
	["default:glass"] = 1.2,
	["default:obsidian_glass"] = 45.0,
	["default:brick"] = 5.0,
	["default:meselamp"] = 3.0,
	["default:mese_post_light"] = 2.0,
	["default:mese_post_light_acacia_wood"] = 2.2,
	["default:mese_post_light_junglewood"] = 2.1,
	["default:mese_post_light_pine_wood"] = 2.0,
	["default:mese_post_light_aspen_wood"] = 1.9,
	["default:cloud"] = 0.2,
}

for name, resistance in pairs(tnt_resistance_by_node) do
	update_node(name, nil, {tnt_resistance = resistance})
end

for i = 1, 5 do
	update_node("default:grass_" .. i, nil, {tnt_resistance = 0.4})
	update_node("default:dry_grass_" .. i, nil, {tnt_resistance = 0.3})
end

for i = 1, 3 do
	update_node("default:fern_" .. i, nil, {tnt_resistance = 0.4})
	update_node("default:marram_grass_" .. i, nil, {tnt_resistance = 0.4})
end
