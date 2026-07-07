local erosion_debug = core.settings:get_bool("erosion_debug_fast") or false
local erosion_cobble = core.settings:get_bool("erosion_cobble", false)

local water_nodes = {
	["default:water_flowing"] = true,
	["default:river_water_flowing"] = true,
}

local deposit_rules = {
	["default:sand"] = "default:dirt",
	["default:desert_sand"] = "default:dry_dirt",
	["default:silver_sand"] = "default:dirt",
}

local erosion_rules = {
	["default:stone"] = {
		to = "default:gravel",
		resistance = 1.0,
	},
	["default:stone_block"] = {
		to = "default:gravel",
		resistance = 1.4,
	},
	["default:stonebrick"] = {
		to = "default:gravel",
		resistance = 1.2,
	},
	["default:desert_stone"] = {
		to = "default:desert_sand",
		resistance = 0.8,
	},
	["default:desert_stone_block"] = {
		to = "default:desert_sand",
		resistance = 1.2,
	},
	["default:desert_stonebrick"] = {
		to = "default:desert_sand",
		resistance = 1.0,
	},
	["default:sandstone"] = {
		to = "default:sand",
		resistance = 0.6,
	},
	["default:sandstone_block"] = {
		to = "default:sandstone",
		resistance = 1.0,
	},
	["default:sandstonebrick"] = {
		to = "default:sandstone",
		resistance = 0.9,
	},
	["default:desert_sandstone"] = {
		to = "default:desert_sand",
		resistance = 0.6,
	},
	["default:desert_sandstone_block"] = {
		to = "default:desert_sandstone",
		resistance = 1.0,
	},
	["default:desert_sandstone_brick"] = {
		to = "default:desert_sandstone",
		resistance = 0.9,
	},
	["default:silver_sandstone"] = {
		to = "default:silver_sand",
		resistance = 0.6,
	},
	["default:silver_sandstone_block"] = {
		to = "default:silver_sandstone",
		resistance = 1.0,
	},
	["default:silver_sandstone_brick"] = {
		to = "default:silver_sandstone",
		resistance = 0.9,
	},
	["default:gravel"] = {
		to = "default:dirt",
		resistance = 0.35,
		needs_humidity = 55,
	},
	["default:dirt_with_grass"] = {
		to = "default:dirt",
		resistance = 0.25,
	},
	["default:dirt_with_dry_grass"] = {
		to = "default:dry_dirt",
		resistance = 0.2,
	},
	["default:dry_dirt"] = {
		to = "default:sand",
		resistance = 0.2,
	},
	["default:clay"] = {
		to = "default:dirt",
		resistance = 0.3,
		needs_humidity = 65,
	},
}

if erosion_cobble then
	erosion_rules["default:cobble"] = {
		to = "default:gravel",
		resistance = 0.8,
	}
	erosion_rules["default:mossycobble"] = {
		to = "default:gravel",
		resistance = 0.6,
		needs_humidity = 45,
	}
	erosion_rules["default:desert_cobble"] = {
		to = "default:desert_sand",
		resistance = 0.7,
	}
end

local erosion_nodes = {}
for name in pairs(erosion_rules) do
	erosion_nodes[#erosion_nodes + 1] = name
end
for name in pairs(deposit_rules) do
	erosion_nodes[#erosion_nodes + 1] = name
end

local water_dirs = {
	{x = 0, y = 1, z = 0, weight = 2.2},
	{x = 1, y = 0, z = 0, weight = 1.0},
	{x = -1, y = 0, z = 0, weight = 1.0},
	{x = 0, y = 0, z = 1, weight = 1.0},
	{x = 0, y = 0, z = -1, weight = 1.0},
	{x = 0, y = -1, z = 0, weight = 0.35},
}

local function exposed_to_rain(pos)
	local np = addvectors(pos, {x=0, y=1, z=0})
	return weather.exposed_to_sky(np, 1)
end

local function water_energy(pos)
	local energy = 0

	for _, dir in ipairs(water_dirs) do
		local p = addvectors(pos, dir)
		if water_nodes[core.get_node(p).name] then
			local level = core.get_node_level(p) or 0
			local moving = 1.0 - math.min(0.75, level / 16)
			energy = energy + dir.weight * moving
		end
	end

	return energy
end

local function slope_energy(pos)
	if core.get_node(addvectors(pos, {x=0, y=-1, z=0})).name == "air" then
		return 0.6
	end

	local air_sides = 0
	for _, dir in ipairs({
			{x=1, y=0, z=0},
			{x=-1, y=0, z=0},
			{x=0, y=0, z=1},
			{x=0, y=0, z=-1},
	}) do
		if core.get_node(addvectors(pos, dir)).name == "air" then
			air_sides = air_sides + 1
		end
	end
	return air_sides * 0.12
end

local function erosion_strength(pos)
	local water = water_energy(pos)
	local rain = exposed_to_rain(pos) and (get_rain(pos) or 0) or 0
	if water <= 0 and rain <= 0 then return 0 end

	local humidity = core.get_humidity(pos) or 50
	local heat = core.get_heat(pos) or 10
	local wet = math.max(0.15, humidity / 85)
	local warm = heat > 0 and 1.0 or math.max(0.05, (heat + 20) / 20)
	local slope = 1.0 + slope_energy(pos)

	return (water * 1.25 + rain * 0.9) * wet * warm * slope
end

local function try_deposit(pos, strength, humidity)
	if strength > 0.55 or humidity < 45 then return false end

	local node = core.get_node(pos)
	local target = deposit_rules[node.name]
	if not target then return false end

	local above = addvectors(pos, {x=0, y=1, z=0})
	if core.get_node(above).name ~= "air" then return false end

	local chance = math.min(0.18, (0.55 - strength) * humidity / 180)
	if math.random() >= chance then return false end

	core.set_node(pos, {name = target})
	return true
end

core.register_abm({
	nodenames = erosion_nodes,
	neighbors = {"air", "default:water_flowing", "default:river_water_flowing"},
	interval = erosion_debug and 1 or 180.0,
	chance = erosion_debug and 1 or 40,
	action = function(pos, node, active_object_count, active_object_count_wider)
		local rule = erosion_rules[node.name]

		local humidity = core.get_humidity(pos) or 50
		if rule and rule.needs_humidity and humidity < rule.needs_humidity then return end

		local strength = erosion_strength(pos)
		if strength <= 0 then return end
		if try_deposit(pos, strength, humidity) then return end
		if not rule then return end

		local chance = math.min(0.3, (strength / rule.resistance) * 0.07)
		if math.random() >= chance then return end

		core.set_node(pos, {name = rule.to})
		if core.check_single_for_falling then
			core.check_single_for_falling(pos)
		end
	end,
})
