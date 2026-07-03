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
	humidity = humidity or core.get_humidity(pos, 0) or 50
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
	local heat = core.get_heat(p, 0)
	if heat > 2 then return 0 end
	local humidity = core.get_humidity(p, 0)
	if humidity < snow_humidity then return 0 end
	local phase = 1 - precipitation_phase(heat, -2, 2)
	local precip = weather.precipitation_factor(p, humidity)
	return ((humidity-snow_humidity)/(100-snow_humidity)) * phase * precip
end

get_rain = function (p, visible)
	if not p then return 0 end
	if visible and p.y > cloud_height then return 0 end
	local heat = core.get_heat(p, 0)
	if heat < -2 then return 0 end
	if heat > 50 then return 0 end
	local humidity = core.get_humidity(p, 0)
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
local grow_debug = core.settings:get("grow_debug_fast") or 0

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

core.register_abm({
	nodenames = {"default:dirt", "default:dirt_with_grass", "default:dirt_with_grass_footsteps", "default:dry_dirt", "default:dirt_with_dry_grass"},
	interval = grow_debug and 1 or 10,
	chance = grow_debug and 1 or 30,
	action = function(pos, node, active_object_count, active_object_count_wider, neighbor, activate)
		local top_pos = {x=pos.x, y=pos.y+1, z=pos.z}
		local top_name = core.get_node(top_pos).name
		local top_nodedef = core.registered_nodes[top_name]
		if top_name == "ignore" or not top_nodedef then return end

		local bottom_pos = {x=pos.x, y=pos.y-1, z=pos.z}
		local bottom_name = core.get_node(bottom_pos).name
		local bottom_air = (bottom_name == "air" or bottom_name == "ignore")

		local light_day = core.get_node_light(top_pos, 0.5) or 0
		local light = core.get_node_light(top_pos) or 0
		local heat = core.get_heat(pos)
		local humidity = core.get_humidity(pos)
		local new_name

		if not ((top_nodedef.sunlight_propagates or top_nodedef.paramtype == "light") and top_nodedef.liquidtype == "none") then
			if not bottom_air and (node.name == "default:dirt_with_dry_grass" or node.name == "default:dry_dirt_with_dry_grass") then
				new_name = "default:dry_dirt"
			elseif node.name == "default:dirt_with_grass" then
				new_name = "default:dirt"
			end
		elseif not bottom_air then
			if top_name == "default:snow" or top_name == "default:snowblock" or top_name == "default:ice" then
					new_name = "default:dirt_with_snow"
			elseif top_name == "air" then
				if (node.name == "default:dirt_with_grass" or node.name == "default:dirt_with_grass_footsteps") and (light_day < grass_light_min or (heat > grass_heat_max and humidity < grass_humidity_min2) or humidity < 1 or heat > grass_heat_max2) then
					if humidity < dirt_dry_humidity then
						new_name = "default:dry_dirt_with_dry_grass"
					else
						new_name = "default:dirt_with_dry_grass"
					end
				elseif node.name == "default:dirt" and (light_day < grass_light_min or (heat > grass_heat_max and humidity < grass_humidity_min2) or humidity < grass_humidity_min or heat > grass_heat_max2) then
					new_name = "default:dry_dirt"
				end

				-- dont freeze falling blocks
				if node.name == "default:dirt" then
					if (default.weather and heat < -5 and humidity > 5) then
						new_name = "default:dirt_with_snow"
					elseif (not default.weather or (heat > 5 and heat < grass_heat_max and humidity > grass_humidity_min)) and light >= grass_light_min then
						new_name = "default:dirt_with_grass"
					end
				end
			end
		end

		local air_sides = 0
		if core.get_node({x=pos.x-1, y=pos.y, z=pos.z}).name == "air" then air_sides = air_sides + 1 end
		if core.get_node({x=pos.x+1, y=pos.y, z=pos.z}).name == "air" then air_sides = air_sides + 1 end
		if core.get_node({x=pos.x, y=pos.y, z=pos.z-1}).name == "air" then air_sides = air_sides + 1 end
		if core.get_node({x=pos.x, y=pos.y, z=pos.z+1}).name == "air" then air_sides = air_sides + 1 end

		local fall = 0
--[[
		if bottom_name == "air"
			and top_name == "air"
			air_sides >= 4
			then
			fall = 1
			top_pos = pos
			pos = bottom_pos
			core.set_node(top_pos, {name = "air"}, 2)
		end
]]

		local rnd1000 = math.random(grow_debug and 1 or 1000)

		if rnd1000 < 10
			and node.name ~= "default:dirt"
			and bottom_name == "air"
			and top_name == "air"
			and air_sides >= 2
			then
			new_name = "default:dirt"
		end

		if new_name and new_name ~= node.name then
			node.name = new_name
			core.set_node(pos, node, 2)
		elseif fall == 1 then
			core.set_node(pos, node, 2)
		else
			if (node.name == "default:dirt_with_grass" or node.name == "default:dirt_with_grass_footsteps") and top_name == "air" and (default.weather and heat > 5 and heat < grass_heat_max and humidity > grass_humidity_min)
				and (activate == 1 or math.random(1, 40) == 1) and light >= grass_light_min then

				if core.find_node_near(pos, (6-5*humidity/100), {"group:flower", "group:tree", "group:sapling"}) then return end

				if rnd1000 <= 10 then
					set_moonflower(top_pos, "flowers:moonflower_closed")
				elseif rnd1000 <= 100 then
					local num = math.random(#flowers.datas)
					if not flowers.datas[num][1] then return end -- why?
					flowers.flower_spread(top_pos, {name = "flowers:" .. flowers.datas[num][1]})
				else
					core.set_node(top_pos, {name = "default:grass_1"}, 2)
				end
			end
		end
	end
})

core.register_abm({
	nodenames = {"default:grass_1", "default:grass_2", "default:grass_3", "default:grass_4", "default:grass_5", "default:dry_shrub", "default:dry_grass_1", "default:dry_grass_2", "default:dry_grass_3", "default:dry_grass_4", "default:dry_grass_5"},
	neighbors = {"default:dirt_with_grass", "default:dirt_with_grass_footsteps", "default:dirt"},
	interval = grow_debug and 1 or  20,
	chance = grow_debug and 1 or  10,
	action = function(pos, node, active_object_count, active_object_count_wider, neighbor, activate)
		local humidity = core.get_humidity(pos)
		local heat = core.get_heat(pos)
		--local node = core.get_node(pos)
		local name = node.name
		if (heat < -5 or heat > grass_heat_max or humidity < 3) and (name == "default:grass_4" or name == "default:grass_5") then
			node.name = "default:dry_shrub"
			core.set_node(pos, node, 2)
			return
		end
		local light = core.get_node_light(pos) or 0
		if heat < 5 or heat > grass_heat_max or light < grass_light_min then return end
		local rnd = (activate or grow_debug) and 1 or math.random(1, 110-humidity)
		if name == "default:grass_5" then
			    if activate > 1 then return end
				if rnd >= 3 then return end
				if     humidity > 70 and heat > 25 then node.name = "default:junglesapling"
				elseif humidity >= 20 and humidity < 35 and heat > 25 then node.name = "default:acacia_sapling"
				elseif humidity > 20 and heat < 10 then node.name = "default:pine_sapling"
				elseif humidity > 45 and heat < 25 then node.name = "default:aspen_sapling"
				elseif humidity > 30 and heat < 40 then node.name = "default:sapling"
				else return end
				if light < tree_light_min or core.find_node_near(pos, (7-5*humidity/100), {"group:tree", "group:sapling"}) then return end
				core.set_node(pos, node, 2)
		elseif name == "default:dry_shrub" then
			node.name = "default:grass_" .. 1
			core.set_node(pos, node, 2)
		else
			for i=1,4 do
				if rnd >= i+5 then return end
				if name == "default:grass_" .. i then
					node.name = "default:grass_" .. (i+1)
					core.set_node(pos, node, 2)
				end
				if name == "default:dry_grass_" .. i then
					node.name = "default:grass_" .. i
					core.set_node(pos, node, 2)
				end
			end
		end
	end
})

core.register_abm({
	nodenames = {"default:sand", "default:desert_sand", "default:silver_sand",  "default:dry_dirt", "default:dirt_with_dry_grass", "default:dry_dirt_with_dry_grass"},
	neighbors = {"default:water_flowing"},
	interval = grow_debug and 1 or  20,
	chance = grow_debug and 1 or 10,
	neighbors_range = 3,
	action = function(pos, node)
		if ((core.get_heat(pos) > grass_heat_max or core.get_humidity(pos) < grass_humidity_min)) then return end
		if node.name == "default:dirt_with_dry_grass" or node.name == "default:dry_dirt_with_dry_grass" then
			local top_pos = {x=pos.x, y=pos.y+1, z=pos.z}
			local light_day = core.get_node_light(top_pos, 0.5) or 0
			if light_day < grass_light_min then
				return
			end
			node.name = "default:dirt_with_grass"
		else
			node.name = "default:dirt"
		end
		core.set_node(pos, node, 2)
	end
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
