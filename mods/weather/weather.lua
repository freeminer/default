-- Weather:
-- * rain
-- * snow
-- * wind

assert(core.add_particlespawner, "I told you to run the latest GitHub!")
assert(core.get_heat, "I told you to run the latest freeminer!")

addvectors = function (v1, v2)
	return {x=v1.x+v2.x, y=v1.y+v2.y, z=v1.z+v2.z}
end

weather = weather or {}

local cloud_height = tonumber(core.settings:get("cloud_height")) or 120
weather.cloud_height = cloud_height
local snow_humidity = 65
local rain_humidity = 75
local cloud_noise
local cloud_detail_noise
local terrain_cache = {}
local terrain_cache_time = -1

local function clamp(value, min_value, max_value)
	return math.max(min_value, math.min(max_value, value))
end

local function precipitation_phase(heat, cold, warm)
	if heat <= cold then return 0 end
	if heat >= warm then return 1 end
	return (heat - cold) / (warm - cold)
end

local function get_noise(noise_params)
	local factory = core.get_value_noise or core.get_perlin
	return factory and factory(noise_params)
end

local function cloud_motion(pos)
	local time = core.get_gametime and core.get_gametime() or 0
	local wind = weather.get_block_wind({
		x = pos.x,
		y = weather.cloud_height,
		z = pos.z,
	})
	local wx = wind.x or 0
	local wz = wind.z or 0
	if math.abs(wx) + math.abs(wz) < 0.15 then
		wx = 0.45
		wz = 0.18
	end
	return {
		x = pos.x - wx * time * 0.35,
		z = pos.z - wz * time * 0.35,
	}
end

local function cloud_value(pos)
	cloud_noise = cloud_noise or get_noise({
		offset = 0.5,
		scale = 0.5,
		spread = {x = 260, y = 260, z = 260},
		seed = 7283,
		octaves = 3,
		persist = 0.55,
		lacunarity = 2,
	})
	cloud_detail_noise = cloud_detail_noise or get_noise({
		offset = 0.5,
		scale = 0.5,
		spread = {x = 80, y = 80, z = 80},
		seed = 19351,
		octaves = 2,
		persist = 0.45,
		lacunarity = 2,
	})
	if not cloud_noise or not cloud_detail_noise then return 1 end

	local p = cloud_motion(pos)
	local base = cloud_noise:get_2d({x = p.x, y = p.z})
	local detail = cloud_detail_noise:get_2d({x = p.x, y = p.z})
	return clamp(base * 0.75 + detail * 0.25, 0, 1)
end

function weather.cloud_cover(pos, humidity)
	humidity = humidity or core.get_humidity(pos) or 50
	local moisture = clamp((humidity - 25) / 65, 0.05, 1.25)
	return clamp(cloud_value(pos) * (0.45 + moisture), 0, 1)
end

function weather.cloud_speed(pos)
	local wind = weather.get_block_wind({
		x = pos.x,
		y = weather.cloud_height,
		z = pos.z,
	})
	local speed = {
		x = (wind.x or 0) * 4,
		z = (wind.z or 0) * 4,
	}
	if math.abs(speed.x) + math.abs(speed.z) < 0.1 then
		speed.x = 1.8
		speed.z = 0.7
	end
	return speed
end

function weather.get_block_wind(pos)
	if not core.get_wind then return {x=0, y=0, z=0} end
	return core.get_wind(pos) or {x=0, y=0, z=0}
end

function weather.random_amount(amount, max_amount)
	local whole = math.floor(amount)
	if math.random() < amount - whole then
		whole = whole + 1
	end
	return clamp(whole, 0, max_amount)
end

local function rounded_offset(value, scale, limit)
	local scaled = value * scale
	local offset
	if scaled >= 0 then
		offset = math.floor(scaled + 0.5)
	else
		offset = math.ceil(scaled - 0.5)
	end
	return clamp(offset, -limit, limit)
end

function weather.wind_target(pos, scale, limit, chance_scale)
	local wind = weather.get_block_wind(pos)
	local wx = wind.x or 0
	local wz = wind.z or 0
	local speed = math.sqrt(wx * wx + wz * wz)
	local chance = clamp(speed * (chance_scale or 0.25), 0, 0.85)
	if speed < 0.25 or math.random() >= chance then
		return pos
	end

	local dx = rounded_offset(wx, scale or 0.4, limit or 1)
	local dz = rounded_offset(wz, scale or 0.4, limit or 1)
	if dx == 0 and dz == 0 then
		return pos
	end
	return {x = pos.x + dx, y = pos.y, z = pos.z + dz}
end

function weather.exposed_to_sky(pos, tolerance)
	local light = core.get_node_light(pos, 0.5)
	if not light or light < default.LIGHT_SUN - (tolerance or 0) then
		return false
	end

	if core.get_node(pos).name ~= "air" then
		return false
	end

	--[[
	if core.line_of_sight then
		local top = {
			x = pos.x,
			y = math.max(pos.y + 16, weather.cloud_height + 2),
			z = pos.z,
		}
		return core.line_of_sight(pos, top)
	end
	]]

	return true
end

local function blocks_moisture(node)
	if node.name == "air" or node.name == "ignore" then return false end

	local def = core.registered_nodes[node.name]
	return def and def.walkable and def.liquidtype == "none"
end

local function highest_solid_y(x, z, min_y, max_y)
	local time = core.get_gametime and math.floor(core.get_gametime() / 30) or 0
	if terrain_cache_time ~= time then
		terrain_cache = {}
		terrain_cache_time = time
	end

	local key = math.floor(x / 8) .. ":" .. math.floor(z / 8)
			.. ":" .. math.floor(min_y / 16) .. ":" .. math.floor(max_y / 16)
	local cached = terrain_cache[key]
	if cached ~= nil then return cached or nil end

	for y = max_y, min_y, -4 do
		local p = {x = math.floor(x), y = y, z = math.floor(z)}
		local node = core.get_node_or_nil and core.get_node_or_nil(p) or core.get_node(p)
		if node and blocks_moisture(node) then
			terrain_cache[key] = y
			return y
		end
	end

	terrain_cache[key] = false
	return nil
end

function weather.rain_shadow(pos)
	local wind = weather.get_block_wind({
		x = pos.x,
		y = weather.cloud_height,
		z = pos.z,
	})
	local wx = wind.x or 0
	local wz = wind.z or 0
	local speed = math.sqrt(wx * wx + wz * wz)
	if speed < 0.2 then return 1 end

	wx = wx / speed
	wz = wz / speed

	local max_y = math.floor(math.max(pos.y + 24, weather.cloud_height - 4))
	local min_y = math.floor(pos.y + 4)
	local shadow = 0
	local lift = 0

	for i, distance in ipairs({24, 48, 80, 120}) do
		local weight = 1.0 / i
		local upwind_y = highest_solid_y(
				pos.x - wx * distance,
				pos.z - wz * distance,
				min_y,
				max_y)
		if upwind_y and upwind_y > pos.y + 8 then
			shadow = shadow + ((upwind_y - pos.y - 8) / 80) * weight
		end

		local downwind_y = highest_solid_y(
				pos.x + wx * distance,
				pos.z + wz * distance,
				min_y,
				max_y)
		if downwind_y and downwind_y > pos.y + 8 then
			lift = lift + ((downwind_y - pos.y - 8) / 110) * weight
		end
	end

	return clamp((1.0 + math.min(lift, 0.35)) * (1.0 - math.min(shadow, 0.8)),
			0.2, 1.35)
end

function weather.precipitation_factor(pos, humidity)
	local cover = weather.cloud_cover(pos, humidity)
	local precip = clamp((cover - 0.38) / 0.62, 0, 1)
	return precip * weather.rain_shadow(pos)
end

get_snow = function (p, visible)
	if not p then return 0 end
	if visible and p.y > cloud_height then return 0 end
	local heat = core.get_heat(p)
	if heat > 2 then return 0 end
	local humidity = core.get_humidity(p)
	if humidity < snow_humidity then return 0 end
	local phase = 1 - precipitation_phase(heat, -2, 2)
	local precip = weather.precipitation_factor(p, humidity)
	return ((humidity-snow_humidity)/(100-snow_humidity)) * phase * precip
end

get_rain = function (p, visible)
	if not p then return 0 end
	if visible and p.y > cloud_height then return 0 end
	local heat = core.get_heat(p)
	if heat < -2 then return 0 end
	if heat > 50 then return 0 end
	local humidity = core.get_humidity(p)
	if humidity < rain_humidity then return 0 end
	local phase = precipitation_phase(heat, -2, 2)
	local precip = weather.precipitation_factor(p, humidity)
	return ((humidity-rain_humidity)/(100-rain_humidity)) * phase * precip
end

if default.weather then
	if core.settings:get_bool("liquid_real") then
		dofile(core.get_modpath("weather").."/rain.lua")
		dofile(core.get_modpath("weather").."/erosion.lua")
	end

	dofile(core.get_modpath("weather").."/snow.lua")
end

if default.weather then
local grass_heat_max = 51
local grass_heat_max2 = 71
local grass_humidity_min = 4
local grass_humidity_min2 = 40
local grass_light_min = 6
local dirt_dry_humidity = 10
local tree_light_min = 12
local grow_debug = (tonumber(core.settings:get("grow_debug_fast")) or 0) ~= 0

--[[ all dirt types:
default:dirt
default:dirt_with_grass
default:dirt_with_grass_footsteps
default:dirt_with_dry_grass
default:dirt_with_snow
default:dirt_with_rainforest_litter
default:dirt_with_coniferous_litter
default:dry_dirt
default:dry_dirt_with_dry_grass
]]

core.register_core_abm({
	name = "weather:soil_weather",
	action = "soil_weather",
	nodenames = {"default:dirt", "default:dirt_with_grass", "default:dirt_with_grass_footsteps", "default:dry_dirt", "default:dirt_with_dry_grass"},
	interval = grow_debug and 1 or 10,
	chance = grow_debug and 1 or 30,
	catch_up = true,
	params = {
		grass_heat_max = grass_heat_max,
		grass_heat_extreme = grass_heat_max2,
		grass_humidity_min = grass_humidity_min,
		grass_humidity_dry = grass_humidity_min2,
		grass_light_min = grass_light_min,
		dirt_dry_humidity = dirt_dry_humidity,
		debug_fast = grow_debug,
		dirt_node = "default:dirt",
		grass_node = "default:dirt_with_grass",
		grass_footsteps_node = "default:dirt_with_grass_footsteps",
		dry_dirt_node = "default:dry_dirt",
		dry_grass_node = "default:dirt_with_dry_grass",
		dry_dirt_grass_node = "default:dry_dirt_with_dry_grass",
		snow_dirt_node = "default:dirt_with_snow",
		snow_node = "default:snow",
		snowblock_node = "default:snowblock",
		ice_node = "default:ice",
		grass_plant_node = "default:grass_1",
	},
})

core.register_core_abm({
	name = "weather:grass_weather",
	action = "grass_weather",
	nodenames = {"default:grass_1", "default:grass_2", "default:grass_3", "default:grass_4", "default:grass_5", "default:dry_shrub", "default:dry_grass_1", "default:dry_grass_2", "default:dry_grass_3", "default:dry_grass_4", "default:dry_grass_5"},
	neighbors = {"default:dirt_with_grass", "default:dirt_with_grass_footsteps", "default:dirt"},
	interval = grow_debug and 1 or  20,
	chance = grow_debug and 1 or  10,
	catch_up = true,
	params = {
		grass_heat_max = grass_heat_max,
		grass_humidity_min = grass_humidity_min,
		grass_light_min = grass_light_min,
		tree_light_min = tree_light_min,
		debug_fast = grow_debug,
		grass_1_node = "default:grass_1",
		grass_2_node = "default:grass_2",
		grass_3_node = "default:grass_3",
		grass_4_node = "default:grass_4",
		grass_5_node = "default:grass_5",
		dry_grass_1_node = "default:dry_grass_1",
		dry_grass_2_node = "default:dry_grass_2",
		dry_grass_3_node = "default:dry_grass_3",
		dry_grass_4_node = "default:dry_grass_4",
		dry_grass_5_node = "default:dry_grass_5",
		dry_shrub_node = "default:dry_shrub",
		jungle_sapling_node = "default:junglesapling",
		acacia_sapling_node = "default:acacia_sapling",
		pine_sapling_node = "default:pine_sapling",
		aspen_sapling_node = "default:aspen_sapling",
		sapling_node = "default:sapling",
	},
})

core.register_core_abm({
	name = "weather:soil_hydrate",
	action = "soil_hydrate",
	nodenames = {"default:sand", "default:desert_sand", "default:silver_sand",  "default:dry_dirt", "default:dirt_with_dry_grass", "default:dry_dirt_with_dry_grass"},
	neighbors = {"default:water_flowing"},
	interval = grow_debug and 1 or  20,
	chance = grow_debug and 1 or 10,
	neighbors_range = 3,
	catch_up = true,
	params = {
		heat_max = grass_heat_max,
		humidity_min = grass_humidity_min,
		light_min = grass_light_min,
		dirt_node = "default:dirt",
		grass_node = "default:dirt_with_grass",
		dry_grass_node = "default:dirt_with_dry_grass",
		dry_dirt_grass_node = "default:dry_dirt_with_dry_grass",
	},
})

--[[ now in mt

core.register_abm({
	nodenames = {"default:cobble"},
	neighbors = {"default:water_flowing"},
	interval = 20,
	neighbors_range = 2,
	chance = 50,
	action = function(pos, node)
		if ((core.get_heat(pos) < 5 or core.get_heat(pos) > 40 or core.get_humidity(pos) < 15)) then return end
		node.name = "default:mossycobble"
		core.set_node(pos, node, 2)
	end
})

]]

end
