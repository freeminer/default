tnt = {}
--[[
-- Default to enabled in singleplayer and disabled in multiplayer
local singleplayer = minetest.is_singleplayer()
local setting = minetest.setting_getbool("enable_tnt")
if (not singleplayer and setting ~= true) or
		(singleplayer and setting == false) then
	return
end
]]

tnt.radius_max = tonumber(core.setting_get("tnt_radius_max") or 25)
tnt.time_max = tonumber(core.setting_get("tnt_time_max") or 3)
tnt.liquid_real = core.setting_getbool("liquid_real")

-- loss probabilities array (one in X will be lost)
local loss_prob = {}

loss_prob["default:cobble"] = 3
loss_prob["default:dirt"] = 4

local radius = tonumber(minetest.setting_get("tnt_radius") or 3)

-- Fill a list with data for content IDs, after all nodes are registered
local cid_data = {}
minetest.after(0, function()
	for name, def in pairs(minetest.registered_nodes) do
		cid_data[minetest.get_content_id(name)] = {
			name = name,
			drops = def.drops,
			flammable = def.groups.flammable,
			on_blast = def.on_blast,
		}
	end
end)

local function rand_pos(center, pos, radius)
	local def
	local reg_nodes = minetest.registered_nodes
	local i = 0
	repeat
		-- Give up and use the center if this takes too long
		if i > 4 then
			pos.x, pos.z = center.x, center.z
			break
		end
		pos.x = center.x + math.random(-radius, radius)
		pos.z = center.z + math.random(-radius, radius)
		def = reg_nodes[minetest.get_node(pos).name]
		i = i + 1
	until def and not def.walkable
end

local function eject_drops(drops, pos, radius)
	local drop_pos = vector.new(pos)
	for _, item in pairs(drops) do
		local count = item:get_count()
		local take_est = math.log(count * count) + math.random(0,4) - 2
		while count > 0 do
			local take = math.max(1,math.min(take_est,
					item:get_count(),
					item:get_stack_max()))

			if count > item:get_stack_max() then take = item:get_stack_max() end
			if count < item:get_stack_max() then take = count end

			rand_pos(pos, drop_pos, radius)
			local obj = minetest.add_item(drop_pos, item:get_name() .. " " .. take)
			if obj then
				obj:get_luaentity().collect = true
				obj:setacceleration({x = 0, y = -10, z = 0})
				obj:setvelocity({x = math.random(-3, 3),
						y = math.random(0, 10),
						z = math.random(-3, 3)})
			end
			count = count - take
		end
	end
end

local function add_drop(drops, item)
	item = ItemStack(item)
	local name = item:get_name()
	if loss_prob[name] ~= nil and math.random(1, loss_prob[name]) == 1 then
		return
	end

	local drop = drops[name]
	if drop == nil then
		drops[name] = item
	else
		drop:set_count(drop:get_count() + item:get_count())
	end
end

--[[

local function destroy(drops, npos, cid, c_air, c_fire, on_blast_queue, ignore_protection, ignore_on_blast)
	if not ignore_protection and minetest.is_protected(npos, "") then
		return cid
	end
	
	local def = cid_data[cid]

	if not def then
		return c_air
	elseif not ignore_on_blast and def.on_blast then
		on_blast_queue[#on_blast_queue + 1] = {pos = vector.new(npos), on_blast = def.on_blast}
		return cid
	elseif def.flammable then
		return c_fire
	else
		local node_drops = minetest.get_node_drops(def.name, "")
		for _, item in ipairs(node_drops) do
			add_drop(drops, item)
		end
		return c_air
	end
end
]]

local function destroy(drops, npos, on_blast_queue, ignore_protection, ignore_on_blast, last, fast)
	if not ignore_protection and minetest.is_protected(npos, "") then
		return
	end

	local nodename = core.get_node(npos).name

	if nodename == "air" then return end

		local def = core.registered_nodes[nodename]
		if def and not ignore_on_blast and def.on_blast then
			on_blast_queue[#on_blast_queue + 1] = {pos = vector.new(npos), on_blast = def.on_blast}
			return
		end

		core.remove_node(npos, (fast and 1 or 0))
		if last then
			nodeupdate(npos)
		end
		if not def or not def.groups then
			-- broken map and unknown nodes
			return
		end
		if def.flammable then
			core.set_node(pos, {name="fire:basic_flame"}, (fast and 2 or 0))
			return
		end

		local node_drops = minetest.get_node_drops(def.name, "")
		for _, item in ipairs(node_drops) do
			add_drop(drops, item)
		end
end


local function calc_velocity(pos1, pos2, old_vel, power)
	local vel = vector.direction(pos1, pos2)
	vel = vector.normalize(vel)
	vel = vector.multiply(vel, power)

	-- Divide by distance
	local dist = vector.distance(pos1, pos2)
	dist = math.max(dist, 1)
	vel = vector.divide(vel, dist)

	-- Add old velocity
	vel = vector.add(vel, old_vel)

	-- Limit to terminal velocity
	dist = vector.length(vel)
--print("cacl velocity=" .. dist .. " power=" .. power)
	if dist > 250 then
		vel = vector.divide(vel, dist / 250)
	end
	return vel
end

local function entity_physics(pos, radius)
	local objs = minetest.get_objects_inside_radius(pos, radius)
	for _, obj in pairs(objs) do
		local obj_pos = obj:getpos()
		local obj_vel = obj:getvelocity()
		local dist = math.max(1, vector.distance(pos, obj_pos))

		if obj_vel ~= nil then
			obj:setvelocity(calc_velocity(pos, obj_pos,
					obj_vel, radius * 10))
		end

--[[
		local damage = (4 / dist) * radius
		obj:set_hp(obj:get_hp() - damage)
]]

		local vec = {x=obj_pos.x-pos.x, y=obj_pos.y-pos.y, z=obj_pos.z-pos.z}
		--local damage_mt = (4 / dist) * radius
		local damage = ((radius*20)/dist)
		--print("DMG dist="..dist.." damage="..damage .. " damage_mt=" .. damage_mt)
		if obj:is_player() or (obj:get_luaentity() and obj:get_luaentity().name ~= "__builtin:item") then
			obj:punch(obj, 1.0, { full_punch_interval=1.0, damage_groups={fleshy=damage}, }, vec)
		end
		--if v ~= nil then
		--	--obj:setvelocity({x=(p.x - pos.x) + (radius / 4) + v.x, y=(p.y - pos.y) + (radius / 2) + v.y, z=(p.z - pos.z) + (radius / 4) + v.z})
		--	obj:setvelocity({x=(p.x - pos.x) + (radius / 2) + v.x, y=(p.y - pos.y) + radius + v.y,       z=(p.z - pos.z) + (radius / 2) + v.z})
		--end

	end
end

local function add_effects(pos, radius, drops)
	minetest.add_particlespawner({
		amount = 128,
		time = 1,
		minpos = vector.subtract(pos, radius / 2),
		maxpos = vector.add(pos, radius / 2),
		minvel = {x = -20, y = -20, z = -20},
		maxvel = {x = 20, y = 20, z = 20},
		minacc = vector.new(),
		maxacc = vector.new(),
		minexptime = 1,
		maxexptime = 3,
		minsize = 8,
		maxsize = 16,
		texture = "tnt_smoke.png",
	})

	-- we just dropped some items. Look at the items entities and pick
	-- one of them to use as texture
	local texture = "tnt_blast.png" --fallback texture
	local most = 0
	for name, stack in pairs(drops) do
		local count = stack:get_count()
		if count > most then
			most = count
			local def = minetest.registered_nodes[name]
			if def and def.tiles and def.tiles[1] then
				texture = def.tiles[1]
			end
		end
	end

	minetest.add_particlespawner({
		amount = 64,
		time = 0.1,
		minpos = vector.subtract(pos, radius / 2),
		maxpos = vector.add(pos, radius / 2),
		minvel = {x = -3, y = 0, z = -3},
		maxvel = {x = 3, y = 5,  z = 3},
		minacc = {x = 0, y = -10, z = 0},
		maxacc = {x = 0, y = -10, z = 0},
		minexptime = 0.8,
		maxexptime = 2.0,
		minsize = 2,
		maxsize = 6,
		texture = texture,
		collisiondetection = true,
	})
end

function tnt.burn(pos)
	local name = minetest.get_node(pos).name
	local group = minetest.get_item_group(name, "tnt")
	if group > 0 then
		minetest.sound_play("tnt_ignite", {pos = pos})
		minetest.set_node(pos, {name = name .. "_burning"})
		minetest.get_node_timer(pos):start(1)
	elseif name == "tnt:gunpowder" then
		minetest.set_node(pos, {name = "tnt:gunpowder_burning"})
	end
end

--[[
local function tnt_explode(pos, radius, ignore_protection, ignore_on_blast)
	local pos = vector.round(pos)
	local vm = VoxelManip()
	local pr = PseudoRandom(os.time())
	local p1 = vector.subtract(pos, radius)
	local p2 = vector.add(pos, radius)
	local minp, maxp = vm:read_from_map(p1, p2)
	local a = VoxelArea:new({MinEdge = minp, MaxEdge = maxp})
	local data = vm:get_data()

	local drops = {}
	local on_blast_queue = {}

	local c_air = minetest.get_content_id("air")
	local c_fire = minetest.get_content_id("fire:basic_flame")
	for z = -radius, radius do
	for y = -radius, radius do
	local vi = a:index(pos.x + (-radius), pos.y + y, pos.z + z)
	for x = -radius, radius do
		local r = vector.length(vector.new(x, y, z))
		if (radius * radius) / (r * r) >= (pr:next(80, 125) / 100) then
			local cid = data[vi]
			local p = {x = pos.x + x, y = pos.y + y, z = pos.z + z}
			if cid ~= c_air then
				data[vi] = destroy(drops, p, cid, c_air, c_fire,
					on_blast_queue, ignore_protection,
					ignore_on_blast)
			end
		end
		vi = vi + 1
	end
	end
	end

	vm:set_data(data)
	vm:write_to_map()
	vm:update_map()
	vm:update_liquids()

	-- call nodeupdate for everything within 1.5x blast radius
	for z = -radius * 1.5, radius * 1.5 do
	for x = -radius * 1.5, radius * 1.5 do
	for y = -radius * 1.5, radius * 1.5 do
		local s = vector.add(pos, {x = x, y = y, z = z})
		local r = vector.distance(pos, s)
		if r / radius < 1.4 then
			nodeupdate(s)
		end
	end
	end
	end

	for _, data in ipairs(on_blast_queue) do
		local dist = math.max(1, vector.distance(data.pos, pos))
		local intensity = (radius * radius) / (dist * dist)
		local node_drops = data.on_blast(data.pos, intensity)
		if node_drops then
			for _, item in ipairs(node_drops) do
				add_drop(drops, item)
			end
		end
	end

	return drops
end
]]

local function tnt_explode(pos, def, radius, ignore_protection, ignore_on_blast)
	local pos = vector.round(pos)
	local pr = PseudoRandom(os.time())
	local p1 = vector.subtract(pos, radius)
	local p2 = vector.add(pos, radius)

	local drops = {}
	local on_blast_queue = {}

		local radius = 2
		local list = {}
		local dr = 0
		local tnts = 1
		local destroyed = 0
		local melted = 0
		local end_ms = os.clock() + tnt.time_max
		local last = nil;
		while dr<radius do
			dr=dr+1
			if os.clock() > end_ms or dr>=radius then last=1 end
			for dx=-dr,dr,dr*2 do
				for dy=-dr,dr,1 do
					for dz=-dr,dr,1 do
						table.insert(list, {x=dx, y=dy, z=dz})
					end
				end
			end
			for dy=-dr,dr,dr*2 do
				for dx=-dr+1,dr-1,1 do
					for dz=-dr,dr,1 do
						table.insert(list, {x=dx, y=dy, z=dz})
					end
				end
			end
			for dz=-dr,dr,dr*2 do
				for dx=-dr+1,dr-1,1 do
					for dy=-dr+1,dr-1,1 do
						table.insert(list, {x=dx, y=dy, z=dz})
					end
				end
			end
				for _,p in ipairs(list) do
					local np = {x=pos.x+p.x, y=pos.y+p.y, z=pos.z+p.z}
					
					local node =  core.get_node(np)
					if node.name == "air" then
					elseif node.name == "tnt:tnt" or node.name == "tnt:tnt_burning" then
						if radius < tnt.radius_max and not last and dr < radius then
							if radius <= 5 then
								radius = radius + 1
							elseif radius <= 10 then
								radius = radius + 0.5
							elseif radius <= 20 then
								radius = radius + 0.3
							else
								radius = radius + 0.2
							end
							core.remove_node(np, 2)
						tnts = tnts + 1
						else
						core.set_node(np, {name="tnt:tnt_burning"}, 2)
						tnt.boom(np, def)
						end
					elseif node.name == "fire:basic_flame"
						--or string.find(node.name, "default:water_") 
						--or string.find(node.name, "default:lava_") 
						or node.name == "tnt:boom"
						then
						
					elseif tnt.liquid_real and last and radius > 10 and math.random(1,15) <= 1 then
						melted = melted + core.freeze_melt(np, 1)
					else
						local last = dr == radius
						local fast = radius > 6
						if math.abs(p.x)<2 and math.abs(p.y)<2 and math.abs(p.z)<2 then
							--destroy(drops, np, dr == radius, radius > 7)
							destroy(drops, np, on_blast_queue, ignore_protection, ignore_on_blast, last, fast)
							destroyed = destroyed + 1
						else
							if math.random(1,5) <= 4 then
								--destroy(drops, np, dr == radius, radius > 7)
								destroy(drops, np, on_blast_queue, ignore_protection, ignore_on_blast, last, fast)
								destroyed = destroyed + 1
							end
						end
					end
				end
			if last then break end
		end

	for _, data in ipairs(on_blast_queue) do
		local dist = math.max(1, vector.distance(data.pos, pos))
		local intensity = (radius * radius) / (dist * dist)
		local node_drops = data.on_blast(data.pos, intensity)
		if node_drops then
			for _, item in ipairs(node_drops) do
				add_drop(drops, item)
			end
		end
	end

	core.log("action", "tnt:tnt : exploded=" .. tnts .. " radius=".. dr .." radius_want=" .. radius .. " destroyed="..destroyed .. " melted="..melted)

	return drops, radius

end


function tnt.boom(pos, def)
	minetest.sound_play("tnt_explode", {pos = pos, gain = 1.5, max_hear_distance = 2*64})
	minetest.set_node(pos, {name = "tnt:boom"})
	minetest.get_node_timer(pos):start(0.5)
	local drops, radius = tnt_explode(pos, def, def.radius, def.ignore_protection,
			def.ignore_on_blast)
	local damage_radius = radius * 3
	entity_physics(pos, damage_radius)
	if not def.disable_drops then
		eject_drops(drops, pos, radius)
	end
	add_effects(pos, radius, drops)
end

minetest.register_node("tnt:boom", {
	drawtype = "plantlike",
	tiles = {"tnt_boom.png"},
	light_source = default.LIGHT_MAX,
	walkable = false,
	drop = "",
	groups = {dig_immediate = 3},
	on_timer = function(pos, elapsed)
		minetest.remove_node(pos)
	end,
	-- unaffected by explosions
	on_blast = function() end,
})

minetest.register_node("tnt:gunpowder", {
	description = "Gun Powder",
	drawtype = "raillike",
	paramtype = "light",
	is_ground_content = false,
	sunlight_propagates = true,
	walkable = false,
	tiles = {"tnt_gunpowder_straight.png", "tnt_gunpowder_curved.png", "tnt_gunpowder_t_junction.png", "tnt_gunpowder_crossing.png"},
	inventory_image = "tnt_gunpowder_inventory.png",
	wield_image = "tnt_gunpowder_inventory.png",
	selection_box = {
		type = "fixed",
		fixed = {-1/2, -1/2, -1/2, 1/2, -1/2+1/16, 1/2},
	},
	groups = {dig_immediate = 2, attached_node = 1, connect_to_raillike = minetest.raillike_group("gunpowder")},
	sounds = default.node_sound_leaves_defaults(),
	
	on_punch = function(pos, node, puncher)
		if puncher:get_wielded_item():get_name() == "default:torch" then
			tnt.burn(pos)
		end
	end,
	on_blast = function(pos, intensity)
		tnt.burn(pos)
	end,
})

minetest.register_node("tnt:gunpowder_burning", {
	drawtype = "raillike",
	paramtype = "light",
	sunlight_propagates = true,
	walkable = false,
	light_source = 5,
	tiles = {{
		name = "tnt_gunpowder_burning_straight_animated.png",
		animation = {
			type = "vertical_frames",
			aspect_w = 16,
			aspect_h = 16,
			length = 1,
		}
	},
	{
		name = "tnt_gunpowder_burning_curved_animated.png",
		animation = {
			type = "vertical_frames",
			aspect_w = 16,
			aspect_h = 16,
			length = 1,
		}
	},
	{
		name = "tnt_gunpowder_burning_t_junction_animated.png",
		animation = {
			type = "vertical_frames",
			aspect_w = 16,
			aspect_h = 16,
			length = 1,
		}
	},
	{
		name = "tnt_gunpowder_burning_crossing_animated.png",
		animation = {
			type = "vertical_frames",
			aspect_w = 16,
			aspect_h = 16,
			length = 1,
		}
	}},
	selection_box = {
		type = "fixed",
		fixed = {-1/2, -1/2, -1/2, 1/2, -1/2+1/16, 1/2},
	},
	drop = "",
	groups = {dig_immediate = 2, attached_node = 1, connect_to_raillike = minetest.raillike_group("gunpowder")},
	sounds = default.node_sound_leaves_defaults(),
	on_timer = function(pos, elapsed)
		for dx = -1, 1 do
		for dz = -1, 1 do
		for dy = -1, 1 do
			if not (dx == 0 and dz == 0) then
				tnt.burn({
					x = pos.x + dx,
					y = pos.y + dy,
					z = pos.z + dz,
				})
			end
		end
		end
		end
		minetest.remove_node(pos)
	end,
	-- unaffected by explosions
	on_blast = function() end,
	on_construct = function(pos)
		minetest.sound_play("tnt_gunpowder_burning", {pos = pos, gain = 2})
		minetest.get_node_timer(pos):start(1)
	end,
})

minetest.register_abm({
	nodenames = {"group:tnt", "tnt:gunpowder"},
	neighbors = {"fire:basic_flame", "default:lava_source", "default:lava_flowing"},
	interval = 4,
	chance = 1,
	action = tnt.burn,
})

minetest.register_craft({
	output = "tnt:gunpowder",
	type = "shapeless",
	recipe = {"default:coal_lump", "default:gravel"}
})

minetest.register_craft({
	output = "tnt:tnt",
	recipe = {
		{"",           "group:wood",    ""},
		{"group:wood", "tnt:gunpowder", "group:wood"},
		{"",           "group:wood",    ""}
	}
})

function tnt.register_tnt(def)
	local name = ""
	if not def.name:find(':') then
		name = "tnt:" .. def.name
	else
		name = def.name
		def.name = def.name:match(":([%w_]+)")
	end
	if not def.tiles then def.tiles = {} end
	local tnt_top = def.tiles.top or def.name .. "_top.png"
	local tnt_bottom = def.tiles.bottom or def.name .. "_bottom.png"
	local tnt_side = def.tiles.side or def.name .. "_side.png"
	local tnt_burning = def.tiles.burning or def.name .. "_top_burning_animated.png"
	if not def.damage_radius then def.damage_radius = def.radius * 2 end
	
	minetest.register_node(":" .. name, {
		description = def.description,
		tiles = {tnt_top, tnt_bottom, tnt_side},
		is_ground_content = false,
		groups = {dig_immediate = 2, mesecon = 2, tnt = 1},
		sounds = default.node_sound_wood_defaults(),
		on_punch = function(pos, node, puncher)
			if puncher:get_wielded_item():get_name() == "default:torch" then
				minetest.set_node(pos, {name = name .. "_burning"})
			elseif math.random(1, 200) <= 1 then
				tnt.boom(pos, def)
			end
		end,
		on_dig = function(pos, node, puncher)
			if math.random(1,10) <= 1 then
				tnt.boom(pos, def)
			else
				return core.node_dig(pos, node, puncher)
			end
		end,
		on_blast = function(pos, intensity)
			minetest.after(0.1, function()
				tnt.boom(pos, def)
			end)
		end,
		mesecons = {effector = 
			{action_on = 
				function(pos)
					tnt.boom(pos, def)
				end
			}
		},
	})
	
	minetest.register_node(":" .. name .. "_burning", {
		tiles = {
			{
				name = tnt_burning,
				animation = {
					type = "vertical_frames",
					aspect_w = 16,
					aspect_h = 16,
					length = 1,
				}
			},
			tnt_bottom, tnt_side
			},
		light_source = 5,
		drop = "",
		sounds = default.node_sound_wood_defaults(),
		on_timer = function(pos, elapsed)
			tnt.boom(pos, def)
		end,
		-- unaffected by explosions
		on_blast = function() end,
		on_construct = function(pos)
			minetest.sound_play("tnt_ignite", {pos = pos})
			minetest.get_node_timer(pos):start(4)
		end,
	})
end

tnt.register_tnt({
	name = "tnt:tnt",
	description = "TNT",
	radius = radius,
})

