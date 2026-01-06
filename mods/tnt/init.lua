-- tnt/init.lua

tnt = {}

local S = minetest.get_translator("tnt")


-- Default to enabled in singleplayer
local enable_tnt = minetest.settings:get("enable_tnt") or "auto"
if enable_tnt == "auto" then
	enable_tnt = minetest.is_singleplayer()
else
	enable_tnt = minetest.is_yes(enable_tnt)
end

tnt.radius_max = tonumber(core.settings:get("tnt_radius_max") or 25)
tnt.time_max = tonumber(core.settings:get("tnt_time_max") or 3)
tnt.liquid_real = core.settings:get_bool("liquid_real")

local tnt_radius = tonumber(minetest.settings:get("tnt_radius") or 3)
local c_air = minetest.get_content_id("air")
local c_fire = minetest.get_content_id("fire:basic_flame")

-- Fill a table with data for all content IDs, after all nodes are registered
local cid_data = {}
minetest.register_on_mods_loaded(function()
	for name, def in pairs(minetest.registered_nodes) do
		cid_data[minetest.get_content_id(name)] = {
			name = name,
			drops = def.drops,
			flammable = def.groups and (def.groups.flammable or 0) ~= 0,
			on_blast = def.on_blast,
		}
	end
end)

local function particle_texture(name)
	local ret = {name = name}
	if minetest.features.particle_blend_clip then
		ret.blend = "clip"
	end
	return ret
end

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
		local count = math.min(item:get_count(), item:get_stack_max())
		while count > 0 do
			local take = math.max(1,math.min(radius * radius,
					count,
					item:get_stack_max()))

			if count > item:get_stack_max() then take = item:get_stack_max() end
			if count < item:get_stack_max() then take = count end

			rand_pos(pos, drop_pos, radius)
			local dropitem = ItemStack(item)
			dropitem:set_count(take)
			local obj = minetest.add_item(drop_pos, dropitem)
			if obj then
				obj:get_luaentity().collect = true
				obj:set_acceleration({x = 0, y = -10, z = 0})
				obj:set_velocity({x = math.random(-3, 3),
						y = math.random(0, 10),
						z = math.random(-3, 3)})
			end
			count = count - take
		end
	end
end

local function add_drop(drops, item)
	item = ItemStack(item)
	-- Note that this needs to be set on the dropped item, not the node.
	-- Value represents "one in X will be lost"
	local lost = item:get_definition()._tnt_loss or 0
	if lost > 0 and (lost == 1 or math.random(1, lost) == 1) then
		return
	end

	local name = item:get_name()
	local drop = drops[name]
	if drop == nil then
		drops[name] = item
	else
		drop:set_count(drop:get_count() + item:get_count())
	end
end

--[[
local basic_flame_on_construct -- cached value
local function destroy(drops, npos, cid, c_air, c_fire,
		on_blast_queue, on_construct_queue,
		ignore_protection, ignore_on_blast, owner)
	if not ignore_protection and minetest.is_protected(npos, owner) then
		return cid
	end

	local def = cid_data[cid]

	if not def then
		return c_air
	elseif not ignore_on_blast and def.on_blast then
		on_blast_queue[#on_blast_queue + 1] = {
			pos = vector.new(npos),
			on_blast = def.on_blast
		}
		return cid
	elseif def.flammable then
		on_construct_queue[#on_construct_queue + 1] = {
			fn = basic_flame_on_construct,
			pos = vector.new(npos)
		}
		return c_fire
	else
		local node_drops = minetest.get_node_drops(def.name, "")
		for _, item in pairs(node_drops) do
			add_drop(drops, item)
		end
		return c_air
	end
end
]]

local function destroy(drops, npos, cid, c_air, c_fire,
		on_blast_queue, on_construct_queue,
		ignore_protection, ignore_on_blast, owner
		, last, fast
		)

	if not ignore_protection and minetest.is_protected(npos, owner) then
		return cid
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
			core.check_for_falling(npos)
		end
		if not def or not def.groups then
			-- broken map and unknown nodes
			return
		end
		if def.groups.flammable then
			core.set_node(npos, {name="fire:basic_flame"}, (fast and 2 or 0))
			return
		end

		local node_drops = minetest.get_node_drops(def.name, "")
		for _, item in ipairs(node_drops) do
			add_drop(drops, item)
		end
end

local function calc_velocity(pos1, pos2, old_vel, power)
	-- Avoid errors caused by a vector of zero length
	if vector.equals(pos1, pos2) then
		return old_vel
	end

	local vel = vector.direction(pos1, pos2)
	vel = vector.normalize(vel)
	vel = vector.multiply(vel, power)

	-- Divide by distance
	local dist = vector.distance(pos1, pos2)
	dist = math.max(dist, 1)
	vel = vector.divide(vel, dist)

	-- Add old velocity
	vel = vector.add(vel, old_vel)

	-- randomize it a bit
	vel = vector.add(vel, {
		x = math.random() - 0.5,
		y = math.random() - 0.5,
		z = math.random() - 0.5,
	})

	-- Limit to terminal velocity
	dist = vector.length(vel)
--print("cacl velocity=" .. dist .. " power=" .. power)
	if dist > 250 then
		vel = vector.divide(vel, dist / 250)
	end
	return vel
end

local function entity_physics(pos, radius, drops)
	local objs = minetest.get_objects_inside_radius(pos, radius)
	for _, obj in pairs(objs) do
		local obj_pos = obj:get_pos()
		if obj_pos then
		local dist = math.max(1, vector.distance(pos, obj_pos))

		local damage = (4 / dist) * radius
--[[
		if obj:is_player() then
			local dir = vector.normalize(vector.subtract(obj_pos, pos))
			local moveoff = vector.multiply(dir, 2 / dist * radius)
			obj:add_velocity(moveoff)

			obj:set_hp(obj:get_hp() - damage)
		else
]]
		if true then
			local luaobj = obj:get_luaentity()

			-- object might have disappeared somehow
			if luaobj then
				local do_damage = true
				local do_knockback = true
				local entity_drops = {}
				local objdef = minetest.registered_entities[luaobj.name]

				damage = ((radius*20)/dist)
				local vec = {x=obj_pos.x-pos.x, y=obj_pos.y-pos.y, z=obj_pos.z-pos.z}
				--print("DMG dist="..dist.." damage="..damage .. " damage_mt=" .. damage_mt)
				--if obj:is_player() or (obj:get_luaentity() and obj:get_luaentity().name ~= "__builtin:item") then

				if objdef and objdef.on_blast then
					do_damage, do_knockback, entity_drops = objdef.on_blast(luaobj, damage)
				end

				if do_knockback then
					local obj_vel = obj:get_velocity()
					obj:set_velocity(calc_velocity(pos, obj_pos,
							obj_vel, radius * 10))
				end
				if do_damage then
					if not obj:get_armor_groups().immortal then
						obj:punch(obj, 1.0, {
							full_punch_interval = 1.0,
							damage_groups = {fleshy = damage},
						}, vec)
					end
				end
				for _, item in pairs(entity_drops) do
					add_drop(drops, item)
				end
			end
		end
		end
	end
end

local function add_effects(pos, radius, drops)
	minetest.add_particle({
		pos = pos,
		velocity = vector.new(),
		acceleration = vector.new(),
		expirationtime = 0.4,
		size = radius * 10,
		collisiondetection = false,
		vertical = false,
		texture = particle_texture("tnt_boom.png"),
		glow = 15,
	})
	minetest.add_particlespawner({
		amount = 64,
		time = 0.5,
		minpos = vector.subtract(pos, radius / 2),
		maxpos = vector.add(pos, radius / 2),
		minvel = {x = -10, y = -10, z = -10},
		maxvel = {x = 10, y = 10, z = 10},
		minacc = vector.new(),
		maxacc = vector.new(),
		minexptime = 1,
		maxexptime = 2.5,
		minsize = radius * 3,
		maxsize = radius * 5,
		texture = particle_texture("tnt_smoke.png"),
	})

	-- we just dropped some items. Look at the items and pick
	-- one of them to use as texture.
	local texture = "tnt_blast.png" -- fallback
	local node
	local most = 0
	for name, stack in pairs(drops) do
		local count = stack:get_count()
		if count > most then
			most = count
			local def = minetest.registered_nodes[name]
			if def then
				node = { name = name }
				if def.tiles and type(def.tiles[1]) == "string" then
					texture = def.tiles[1]
				end
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
		minsize = radius * 0.33,
		maxsize = radius,
		texture = texture,
		-- ^ only as fallback for clients without support for `node` parameter
		node = node,
		collisiondetection = true,
	})
end

function tnt.burn(pos, nodename)
	local name = nodename or minetest.get_node(pos).name
	local def = minetest.registered_nodes[name]
	if not def then
		return
	elseif def.on_ignite then
		def.on_ignite(pos)
	elseif minetest.get_item_group(name, "tnt") > 0 then
		minetest.swap_node(pos, {name = name .. "_burning"})
		minetest.sound_play("tnt_ignite", {pos = pos, gain = 1.0}, true)
		minetest.get_node_timer(pos):start(1)
	end
end

--[[
local function tnt_explode(pos, radius, ignore_protection, ignore_on_blast, owner, explode_center)
	pos = vector.round(pos)
	-- scan for adjacent TNT nodes first, and enlarge the explosion
	local vm1 = VoxelManip()
	local p1 = vector.subtract(pos, 2)
	local p2 = vector.add(pos, 2)
	local minp, maxp = vm1:read_from_map(p1, p2)
	local a = VoxelArea:new({MinEdge = minp, MaxEdge = maxp})
	local data = vm1:get_data()
	local count = 0
	local c_tnt
	local c_tnt_burning = minetest.get_content_id("tnt:tnt_burning")
	local c_tnt_boom = minetest.get_content_id("tnt:boom")
	local c_air = minetest.CONTENT_AIR
	local c_ignore = minetest.CONTENT_IGNORE
	if enable_tnt then
		c_tnt = minetest.get_content_id("tnt:tnt")
	else
		c_tnt = c_tnt_burning -- tnt is not registered if disabled
	end
	-- make sure we still have explosion even when centre node isnt tnt related
	if explode_center then
		count = 1
	end

	for z = pos.z - 2, pos.z + 2 do
	for y = pos.y - 2, pos.y + 2 do
		local vi = a:index(pos.x - 2, y, z)
		for x = pos.x - 2, pos.x + 2 do
			local cid = data[vi]
			if cid == c_tnt or cid == c_tnt_boom or cid == c_tnt_burning then
				count = count + 1
				data[vi] = c_air
			end
			vi = vi + 1
		end
	end
	end

	vm1:set_data(data)
	vm1:write_to_map()
	if vm1.close ~= nil then
		vm1:close()
	end

	-- recalculate new radius
	radius = math.floor(radius * math.pow(count, 1/3))

	-- perform the explosion
	local vm = VoxelManip()
	local pr = PseudoRandom(os.time())
	p1 = vector.subtract(pos, radius)
	p2 = vector.add(pos, radius)
	minp, maxp = vm:read_from_map(p1, p2)
	a = VoxelArea:new({MinEdge = minp, MaxEdge = maxp})
	data = vm:get_data()

	local drops = {}
	local on_blast_queue = {}
	local on_construct_queue = {}
	basic_flame_on_construct = minetest.registered_nodes["fire:basic_flame"].on_construct

	-- Used to efficiently remove metadata of nodes that were destroyed.
	-- Metadata is probably sparse, so this may save us some work.
	local has_meta = {}
	for _, p in ipairs(minetest.find_nodes_with_meta(p1, p2)) do
		has_meta[a:indexp(p)] = true
	end

	local c_fire = minetest.get_content_id("fire:basic_flame")
	for z = -radius, radius do
	for y = -radius, radius do
	local vi = a:index(pos.x + (-radius), pos.y + y, pos.z + z)
	for x = -radius, radius do
		local r = vector.length(vector.new(x, y, z))
		if (radius * radius) / (r * r) >= (pr:next(80, 125) / 100) then
			local cid = data[vi]
			local p = {x = pos.x + x, y = pos.y + y, z = pos.z + z}
			if cid ~= c_air and cid ~= c_ignore then
				local new_cid = destroy(drops, p, cid, c_air, c_fire,
					on_blast_queue, on_construct_queue,
					ignore_protection, ignore_on_blast, owner)

				if new_cid ~= data[vi] then
					data[vi] = new_cid
					if has_meta[vi] then
						minetest.get_meta(p):from_table(nil)
					end
				end
			end
		end
		vi = vi + 1
	end
	end
	end

	vm:set_data(data)
	vm:write_to_map()
	vm:update_liquids()
	if vm.close ~= nil then
		vm:close()
	end

	-- call check_single_for_falling for everything within 1.5x blast radius
	for y = -radius * 1.5, radius * 1.5 do
	for z = -radius * 1.5, radius * 1.5 do
	for x = -radius * 1.5, radius * 1.5 do
		local rad = {x = x, y = y, z = z}
		local s = vector.add(pos, rad)
		local r = vector.length(rad)
		if r / radius < 1.4 then
			minetest.check_single_for_falling(s)
		end
	end
	end
	end

	for _, queued_data in pairs(on_blast_queue) do
		local dist = math.max(1, vector.distance(queued_data.pos, pos))
		local intensity = (radius * radius) / (dist * dist)
		local node_drops = queued_data.on_blast(queued_data.pos, intensity)
		if node_drops then
			for _, item in pairs(node_drops) do
				add_drop(drops, item)
			end
		end
	end

	for _, queued_data in pairs(on_construct_queue) do
		queued_data.fn(queued_data.pos)
	end

	minetest.log("action", "TNT owned by " .. owner .. " detonated at " ..
		minetest.pos_to_string(pos) .. " with radius " .. radius)

	return drops, radius
end
]]

local function tnt_explode(pos, def, radius, ignore_protection, ignore_on_blast, owner)
	local pos = vector.round(pos)
	local pr = PseudoRandom(os.time())
	local p1 = vector.subtract(pos, radius)
	local p2 = vector.add(pos, radius)

	local drops = {}
	local on_blast_queue = {}
	-- TODO: not implemented!
	local on_construct_queue = {}

		local radius = 2
		local dr = 0
		local tnts = 1
		local destroyed = 0
		local melted = 0
		local end_ms = os.clock() + tnt.time_max
		local last = nil;
		while dr<radius do
			local list = {}
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
						local cid = minetest.get_content_id(node.name)

						if (math.abs(p.x)<2 and math.abs(p.y)<2 and math.abs(p.z)<2) or dr < radius then
							--destroy(drops, np, dr == radius, radius > 7)
							destroy(drops, np, cid, c_air, c_fire, on_blast_queue, on_construct_queue, ignore_protection, ignore_on_blast, owner, last, fast)
							destroyed = destroyed + 1
						else
							if math.random(1,5) <= 4 then
								--destroy(drops, np, dr == radius, radius > 7)
								destroy(drops, np, cid, c_air, c_fire, on_blast_queue, on_construct_queue, ignore_protection, ignore_on_blast, owner, last, fast)
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

	core.log("action", tnts .. " TNTs owned by " .. owner .. " detonated at " .. 
	    minetest.pos_to_string(pos) .. " with radius=".. dr .." radius_want=" .. radius .. " destroyed="..destroyed .. " melted="..melted)

	return drops, radius

end


function tnt.boom(pos, def)
	def = def or {}
	def.radius = def.radius or 1
	def.damage_radius = def.damage_radius or def.radius * 2
	local meta = minetest.get_meta(pos)
	local owner = meta:get_string("owner")
	if not def.explode_center and def.ignore_protection ~= true then
		minetest.set_node(pos, {name = "tnt:boom"})
	end
	local sound = def.sound or "tnt_explode"
	minetest.sound_play(sound, {pos = pos, gain = 2.5,
			max_hear_distance = math.min(def.radius * 20, 128)}, true)
	local drops, radius = tnt_explode(pos, def, def.radius, def.ignore_protection,
			def.ignore_on_blast, owner, def.explode_center)
	-- append entity drops
	local damage_radius = (radius / math.max(1, def.radius)) * def.damage_radius
	damage_radius = radius * 3
	entity_physics(pos, damage_radius, drops)
	if not def.disable_drops then
		eject_drops(drops, pos, radius)
	end
	add_effects(pos, radius, drops)
	minetest.log("action", "A TNT explosion occurred at " .. minetest.pos_to_string(pos) ..
		" with radius " .. radius)
end

minetest.register_node("tnt:boom", {
	drawtype = "airlike",
	inventory_image = "tnt_boom.png",
	wield_image = "tnt_boom.png",
	light_source = default.LIGHT_MAX,
	walkable = false,
	drop = "",
	groups = {dig_immediate = 3, not_in_creative_inventory = 1},
	-- unaffected by explosions
	on_blast = function() end,
})

minetest.register_node("tnt:gunpowder", {
	description = S("Gun Powder"),
	drawtype = "raillike",
	paramtype = "light",
	is_ground_content = false,
	sunlight_propagates = true,
	walkable = false,
	tiles = {
		"tnt_gunpowder_straight.png",
		"tnt_gunpowder_curved.png",
		"tnt_gunpowder_t_junction.png",
		"tnt_gunpowder_crossing.png"
	},
	inventory_image = "tnt_gunpowder_inventory.png",
	wield_image = "tnt_gunpowder_inventory.png",
	selection_box = {
		type = "fixed",
		fixed = {-1/2, -1/2, -1/2, 1/2, -1/2+1/16, 1/2},
	},
	groups = {dig_immediate = 2, attached_node = 1, flammable = 5,
		connect_to_raillike = minetest.raillike_group("gunpowder")},
	sounds = default.node_sound_leaves_defaults(),

	on_punch = function(pos, node, puncher)
		if puncher:get_wielded_item():get_name() == "default:torch" then
			minetest.set_node(pos, {name = "tnt:gunpowder_burning"})
			default.log_player_action(puncher, "ignites tnt:gunpowder at", pos)
		end
	end,
	on_blast = function(pos, intensity)
		minetest.set_node(pos, {name = "tnt:gunpowder_burning"})
	end,
	on_burn = function(pos)
		minetest.set_node(pos, {name = "tnt:gunpowder_burning"})
	end,
	on_ignite = function(pos, igniter)
		minetest.set_node(pos, {name = "tnt:gunpowder_burning"})
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
	groups = {
		dig_immediate = 2,
		attached_node = 1,
		connect_to_raillike = minetest.raillike_group("gunpowder"),
		not_in_creative_inventory = 1
	},
	sounds = default.node_sound_leaves_defaults(),
	on_timer = function(pos, elapsed)
		for dx = -1, 1 do
		for dz = -1, 1 do
			if math.abs(dx) + math.abs(dz) == 1 then
				for dy = -1, 1 do
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
		minetest.sound_play("tnt_gunpowder_burning", {pos = pos,
			gain = 1.0}, true)
		minetest.get_node_timer(pos):start(1)
	end,
})

minetest.register_craft({
	output = "tnt:gunpowder 5",
	type = "shapeless",
	recipe = {"default:coal_lump", "default:gravel"}
})

minetest.register_craftitem("tnt:tnt_stick", {
	description = S("TNT Stick"),
	inventory_image = "tnt_tnt_stick.png",
	groups = {flammable = 5},
})

if enable_tnt then
	minetest.register_craft({
		output = "tnt:tnt_stick 2",
		recipe = {
			{"tnt:gunpowder", "", "tnt:gunpowder"},
			{"tnt:gunpowder", "default:paper", "tnt:gunpowder"},
			{"tnt:gunpowder", "", "tnt:gunpowder"},
		}
	})

	minetest.register_craft({
		output = "tnt:tnt",
		recipe = {
			{"tnt:tnt_stick", "tnt:tnt_stick", "tnt:tnt_stick"},
			{"tnt:tnt_stick", "tnt:tnt_stick", "tnt:tnt_stick"},
			{"tnt:tnt_stick", "tnt:tnt_stick", "tnt:tnt_stick"}
		}
	})

	minetest.register_abm({
		label = "TNT ignition",
		nodenames = {"group:tnt", "tnt:gunpowder"},
		neighbors = {"fire:basic_flame", "default:lava_source", "default:lava_flowing"},
		interval = 4,
		chance = 1,
		action = function(pos, node)
			tnt.burn(pos, node.name)
		end,
	})
end

function tnt.register_tnt(def)
	local name
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

	if enable_tnt then
		minetest.register_node(":" .. name, {
			description = def.description,
			tiles = {tnt_top, tnt_bottom, tnt_side},
			is_ground_content = false,
			groups = {dig_immediate = 2, mesecon = 2, tnt = 1, flammable = 5},
			sounds = default.node_sound_wood_defaults(),
			after_place_node = function(pos, placer)
				if placer and placer:is_player() then
					local meta = minetest.get_meta(pos)
					meta:set_string("owner", placer:get_player_name())
				end
			end,
			on_punch = function(pos, node, puncher)
				if puncher:get_wielded_item():get_name() == "default:torch" then
					minetest.swap_node(pos, {name = name .. "_burning"})
					minetest.registered_nodes[name .. "_burning"].on_construct(pos)
					default.log_player_action(puncher, "ignites", node.name, "at", pos)
					-- Yeah, tnt is very dangerous ;)
			elseif math.random(1, 150) <= 1 then
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
			on_burn = function(pos)
				minetest.swap_node(pos, {name = name .. "_burning"})
				minetest.registered_nodes[name .. "_burning"].on_construct(pos)
			end,
			on_ignite = function(pos, igniter)
				minetest.swap_node(pos, {name = name .. "_burning"})
				minetest.registered_nodes[name .. "_burning"].on_construct(pos)
			end,
		})
	end

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
		groups = {falling_node = 1, not_in_creative_inventory = 1},
		on_timer = function(pos, elapsed)
			tnt.boom(pos, def)
		end,
		-- unaffected by explosions
		on_blast = function() end,
		on_construct = function(pos)
			minetest.sound_play("tnt_ignite", {pos = pos}, true)
			minetest.get_node_timer(pos):start(4)
			minetest.check_for_falling(pos)
		end,
	})
end

tnt.register_tnt({
	name = "tnt:tnt",
	description = S("TNT"),
	radius = tnt_radius,
})
