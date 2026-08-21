local entity_name = "default:arnis_decal_display"

local function rotation_for(facing, turn)
	local r = (turn % 8) * math.pi / 4
	if facing == 0 then
		return {x = math.pi / 2, y = r, z = 0}
	elseif facing == 1 then
		return {x = -math.pi / 2, y = -r, z = 0}
	elseif facing == 3 then
		return {x = 0, y = math.pi, z = r}
	elseif facing == 4 then
		return {x = -r, y = math.pi / 2, z = 0}
	elseif facing == 5 then
		return {x = r, y = -math.pi / 2, z = 0}
	end
	return {x = 0, y = 0, z = -r}
end

minetest.register_node("default:arnis_decal_frame", {
	description = "Arnis decal frame",
	drawtype = "airlike",
	paramtype = "light",
	sunlight_propagates = true,
	walkable = false,
	pointable = false,
	diggable = false,
	drop = "",
	groups = {not_in_creative_inventory = 1},
})

minetest.register_entity(entity_name, {
	initial_properties = {
		visual = "cube",
		visual_size = {x = 1, y = 1, z = 0.025},
		textures = {"default_cloud.png", "default_cloud.png", "default_cloud.png",
			"default_cloud.png", "default_cloud.png", "default_cloud.png"},
		physical = false,
		pointable = false,
		static_save = true,
	},
	on_activate = function(self, staticdata)
		local data = minetest.deserialize(staticdata)
		if type(data) ~= "table" or not data.texture then
			self.object:remove()
			return
		end
		self.data = data
		self.object:set_properties({
			textures = {data.texture, data.texture, data.texture,
				data.texture, data.texture, data.texture},
			glow = data.glow and minetest.LIGHT_MAX or 0,
		})
		self.object:set_rotation(rotation_for(data.facing or 2, data.rotation or 0))
	end,
	get_staticdata = function(self)
		return minetest.serialize(self.data or {})
	end,
})

local function spawn_display(pos, node)
	for _, object in ipairs(minetest.get_objects_inside_radius(pos, 0.2)) do
		local entity = object:get_luaentity()
		if entity and entity.name == entity_name then
			return
		end
	end
	local meta = minetest.get_meta(pos)
	local texture = meta:get_string("texture")
	if texture == "" then
		return
	end
	local data = {
		texture = texture,
		map_id = meta:get_int("map_id"),
		facing = meta:get_int("facing"),
		rotation = meta:get_int("rotation"),
		glow = meta:get_int("glow") ~= 0,
	}
	minetest.add_entity(pos, entity_name, minetest.serialize(data))
end

minetest.register_lbm({
	label = "Restore Arnis decal displays",
	name = "default:restore_arnis_decal_displays",
	nodenames = {"default:arnis_decal_frame"},
	run_at_every_load = true,
	action = spawn_display,
})
