-- PBJ Pup reads this setting while loading; remove the temporary default again
-- once mods have loaded, without changing an explicitly configured value.
local pbj_setting = "pbj_pup_ymin"
local pbj_original, pbj_temporary
if core.get_modpath("pbj_pup") then
	pbj_original = core.settings:get(pbj_setting)
	if pbj_original == nil or pbj_original == "" then
		pbj_temporary = tostring(core.get_mapgen_edges().y)
		core.settings:set(pbj_setting, pbj_temporary)
	end
end

local original_dofile = dofile
local wrapped_dofile
local installed = false

-- Mobs Redo and the older Mobs API create their global table in api.lua.
-- Install the wrapper before mob files register their spawn callbacks.
local function install(...)
	if mobs and type(mobs.spawn_specific) == "function" then
		installed = true
		local spawn_specific = mobs.spawn_specific
		function mobs:spawn_specific(name, nodes, neighbors, min_light, max_light,
				interval, chance, active_object_count, min_height, max_height, ...)
			if min_height == -31000 or max_height == 31000 then
				local edge_min, edge_max = core.get_mapgen_edges()
				if min_height == -31000 then min_height = edge_min.y end
				if max_height == 31000 then max_height = edge_max.y end
			end
			return spawn_specific(self, name, nodes, neighbors, min_light, max_light,
				interval, chance, active_object_count, min_height, max_height, ...)
		end
	end
	if dofile == wrapped_dofile then
		dofile = original_dofile
	end
	return ...
end

wrapped_dofile = function(path, ...)
	if not installed and core.get_current_modname() == "mobs" and
			path == core.get_modpath("mobs") .. "/api.lua" then
		return install(original_dofile(path, ...))
	end
	return original_dofile(path, ...)
end
dofile = wrapped_dofile

core.register_on_mods_loaded(function()
	if pbj_temporary and core.settings:get(pbj_setting) == pbj_temporary then
		if pbj_original == nil then
			core.settings:remove(pbj_setting)
		else
			core.settings:set(pbj_setting, pbj_original)
		end
	end
	if dofile == wrapped_dofile then
		dofile = original_dofile
	end
end)
