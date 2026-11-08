-- The default mod is loaded before this mod, so its definitions are already
-- registered with the engine. Capture its definitions without registering them
-- again, then update matching live definitions in place.
if not default or not core.set_mapgen_y_bounds then
	return
end

local captured = {biome = {}, ore = {}, decoration = {}}
local original = {}
for kind, definitions in pairs(captured) do
	local name = "register_" .. kind
	original[name] = core[name]
	core[name] = function(def)
		definitions[#definitions + 1] = def
	end
end

local ok, err = pcall(function()
	local mg_name = core.get_mapgen_setting("mg_name")
	if mg_name == "v6" or mg_name == "indev" then
		default.register_mgv6_ores()
		default.register_mgv6_decorations()
	else
		default.register_biomes()
		default.register_ores()
		default.register_decorations()
	end
end)
for name, fn in pairs(original) do
	core[name] = fn
end
if not ok then
	error(err)
end

local function equal(a, b)
	if type(a) ~= type(b) then
		return false
	end
	if type(a) ~= "table" then
		return a == b
	end
	for key, value in pairs(a) do
		if not equal(value, b[key]) then
			return false
		end
	end
	for key in pairs(b) do
		if a[key] == nil then
			return false
		end
	end
	return true
end

local edge_min, edge_max = core.get_mapgen_edges()
for kind, definitions in pairs(captured) do
	local registered = core["registered_" .. kind .. "s"]
	for key, def in pairs(registered) do
		if def.y_min == -31000 or def.y_max == 31000 then
			for _, source in ipairs(definitions) do
				if equal(def, source) then
					local y_min = def.y_min == -31000 and edge_min.y or nil
					local y_max = def.y_max == 31000 and edge_max.y or nil
					core.set_mapgen_y_bounds(kind, key, y_min, y_max)
					if y_min then def.y_min = y_min end
					if y_max then def.y_max = y_max end
					break
				end
			end
		end
	end
end
