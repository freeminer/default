local erosion_debug = core.settings:get_bool("erosion_debug_fast") or false
local erosion_cobble = core.settings:get_bool("erosion_cobble", false)

local water_nodes = {
	"default:water_flowing",
	"default:river_water_flowing",
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

local trigger_nodes = {}
local erosion_nodes = {}
local erosion_targets = {}
local erosion_resistances = {}
local erosion_humidity_min = {}
for name, rule in pairs(erosion_rules) do
	trigger_nodes[#trigger_nodes + 1] = name
	erosion_nodes[#erosion_nodes + 1] = name
	erosion_targets[#erosion_targets + 1] = rule.to
	erosion_resistances[#erosion_resistances + 1] = rule.resistance
	erosion_humidity_min[#erosion_humidity_min + 1] = rule.needs_humidity or 0
end

local deposit_nodes = {}
local deposit_targets = {}
for name, target in pairs(deposit_rules) do
	trigger_nodes[#trigger_nodes + 1] = name
	deposit_nodes[#deposit_nodes + 1] = name
	deposit_targets[#deposit_targets + 1] = target
end

core.register_core_abm({
	name = "weather:erosion",
	action = "erosion",
	nodenames = trigger_nodes,
	neighbors = {"air", "default:water_flowing", "default:river_water_flowing"},
	interval = erosion_debug and 1 or 180.0,
	chance = erosion_debug and 1 or 40,
	catch_up = true,
	params = {
		water_nodes = water_nodes,
		erosion_nodes = erosion_nodes,
		erosion_targets = erosion_targets,
		erosion_resistances = erosion_resistances,
		erosion_humidity_min = erosion_humidity_min,
		deposit_nodes = deposit_nodes,
		deposit_targets = deposit_targets,
		cloud_height = weather.cloud_height,
		rain_heat_min = -2,
		rain_heat_max = 50,
		rain_phase_max = 2,
		rain_humidity = 75,
		sky_tolerance = 1,
		water_above_weight = 2.2,
		water_side_weight = 1.0,
		water_below_weight = 0.35,
		water_level_divisor = 16,
		water_level_max_reduction = 0.75,
		water_strength = 1.25,
		rain_strength = 0.9,
		wet_min = 0.15,
		humidity_scale = 85,
		cold_offset = 20,
		cold_scale = 20,
		cold_min = 0.05,
		unsupported_slope = 0.6,
		air_side_slope = 0.12,
		deposit_strength_max = 0.55,
		deposit_humidity_min = 45,
		deposit_chance_max = 0.18,
		deposit_chance_divisor = 180,
		erosion_chance_max = 0.3,
		erosion_chance_scale = 0.07,
	},
})
