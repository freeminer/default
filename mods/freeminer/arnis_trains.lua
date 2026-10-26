-- Mapgen writes markers; Advtrains state is created on the server thread.
local marker = "freeminer:arnis_train_spawn"
local advtrains = rawget(_G, "advtrains")
local mode = minetest.settings:get("arnis_train_mode") or "auto"
local wagon_setting = minetest.settings:get("arnis_train_wagon") or ""
local owner = minetest.settings:get("arnis_train_owner") or ""
local storage = minetest.get_mod_storage()

minetest.register_node(marker, {
    description = "Arnis train spawn marker",
    drawtype = "airlike",
    paramtype = "light",
    sunlight_propagates = true,
    walkable = false,
    pointable = false,
    diggable = false,
    drop = "",
    groups = {
        not_in_creative_inventory = 1,
    },
})

local function wagon_for_rail(pos)
    local node = minetest.get_node_or_nil(pos)
    local def = node and minetest.registered_nodes[node.name]
    if not def or not def.groups then
        return
    end
    local function compatible(name, wagon)
        if name == "advtrains:wagon_placeholder" or not wagon.drives_on then
            return false
        end
        for tracktype, enabled in pairs(wagon.drives_on) do
            if enabled and (def.groups["advtrains_track_" .. tracktype] or 0) > 0 then
                return true
            end
        end
        return false
    end
    if wagon_setting ~= "" then
        local wagon = advtrains.wagon_prototypes[wagon_setting]
        if wagon and compatible(wagon_setting, wagon) then
            return wagon_setting, wagon
        end
        return
    end
    -- Select from registered capabilities, independently of installed wagon packs.
    local names = {}
    for name, wagon in pairs(advtrains.wagon_prototypes) do
        if wagon.is_locomotive and compatible(name, wagon) then
            names[#names + 1] = name
        end
    end
    table.sort(names)
    if #names > 0 then
        local name = names[(minetest.hash_node_position(pos) % #names) + 1]
        return name, advtrains.wagon_prototypes[name]
    end
end

local function clear_above(pos)
    for dy = 1, 3 do
        local node = minetest.get_node_or_nil({
            x = pos.x,
            y = pos.y + dy,
            z = pos.z,
        })
        local def = node and minetest.registered_nodes[node.name]
        if not def or def.walkable then
            return false
        end
    end
    return true
end

-- Require loaded, connected, unoccupied track for the entire wagon. Pending
-- markers are retried when adjacent mapblocks become available.
local function track_ready(pos, span)
    local ok, conns = advtrains.get_rail_info_at(pos)
    if not ok or #conns ~= 2 or not clear_above(pos) then
        return
    end
    if advtrains.occ.check_collision(pos) then
        return
    end
    for first = 1, 2 do
        local cursor, connections, outgoing = pos, conns, first
        local distance, visited = 0, {}
        while distance < span + 1 do
            local nextpos, incoming, _, _, nextconns, connmap =
                advtrains.get_adjacent_rail(cursor, connections, outgoing)
            if not nextpos or not minetest.get_node_or_nil(nextpos) then
                return
            end
            local key = minetest.pos_to_string(nextpos)
            if visited[key] or advtrains.occ.check_collision(nextpos) or not clear_above(nextpos) then
                return
            end
            visited[key] = true
            distance = distance + vector.distance(cursor, nextpos)
            cursor, connections = nextpos, nextconns
            outgoing = advtrains.get_matching_conn(incoming, connmap)
        end
    end
    return true
end

local function spawn(pos)
    if mode ~= "auto" or not advtrains or not advtrains.wagon_prototypes or (advtrains.mainloop_runcnt or 0) == 0 or
        advtrains.is_no_action() then
        return
    end
    if minetest.get_node(pos).name ~= marker then
        return
    end
    local key = "arnis_train:" .. minetest.pos_to_string(pos)
    if storage:get_string(key) ~= "" then
        minetest.remove_node(pos)
        return
    end
    -- staticdata is persisted by Advtrains. Recover a stale marker without
    -- duplicating its train when the map and train saves occur at different times.
    for id, train in pairs(advtrains.trains) do
        if train.staticdata and train.staticdata.arnis_spawn == key then
            storage:set_string(key, id)
            minetest.remove_node(pos)
            return
        end
    end
    local railpos = {
        x = pos.x,
        y = pos.y - 1,
        z = pos.z,
    }
    local name, wagon = wagon_for_rail(railpos)
    if not name or not track_ready(railpos, wagon.wagon_span or 1) then
        return
    end
    local wid = advtrains.create_wagon(name, owner)
    local ok, id = pcall(advtrains.create_new_train_at, railpos, 1, 0, {wid})
    if not ok or not id then
        -- The API leaves an entry behind when initialization fails.
        for tid, train in pairs(advtrains.trains) do
            if train.trainparts and train.trainparts[1] == wid then
                if train.path then
                    advtrains.path_invalidate(train, true)
                end
                advtrains.trains[tid] = nil
            end
        end
        advtrains.wagons[wid] = nil
        if minetest.get_meta(pos):get_int("warned") == 0 then
            minetest.log("warning", "[freeminer] Arnis train creation failed at " .. minetest.pos_to_string(railpos) ..
                ": " .. tostring(id))
            minetest.get_meta(pos):set_int("warned", 1)
        end
        return
    end
    local train = advtrains.trains[id]
    train.staticdata = train.staticdata or {}
    train.staticdata.arnis_spawn = key
    train.velocity, train.tarvelocity = 0, 0
    storage:set_string(key, id)
    minetest.remove_node(pos)
end

minetest.register_lbm({
    label = "Spawn generated Arnis trains",
    name = "freeminer:arnis_trains",
    nodenames = {marker},
    run_at_every_load = true,
    action = function(pos)
        -- The first Advtrains globalstep loads its save data.
        minetest.after(0, spawn, vector.new(pos))
        minetest.after(1, spawn, vector.new(pos))
    end,
})

-- New blocks do not run load-time LBMs. Do not wait for an active-block ABM:
-- a flying player can leave the area before its first ten-second scan.
minetest.register_on_generated(function(minp, maxp)
    if mode ~= "auto" or not advtrains then
        return
    end
    local positions = minetest.find_nodes_in_area(minp, maxp, {marker})
    if #positions == 0 then
        return
    end
    local function complete()
        for _, pos in ipairs(positions) do
            spawn(pos)
        end
    end
    -- Generation callbacks precede map activation; defer Advtrains path setup.
    minetest.after(0, complete)
    minetest.after(1, complete)
end)

-- Covers newly generated blocks as well as pending markers near unloaded rails.
minetest.register_abm({
    label = "Complete generated Arnis trains",
    nodenames = {marker},
    interval = 10,
    chance = 1,
    catch_up = false,
    action = spawn,
})

--[[
minetest.register_chatcommand("arnis_trains", {
	description = "Show generated Arnis trains and nearby pending spawn markers",
	privs = {server=true},
	func = function(name)
		if not advtrains then return true, "Arnis trains: Advtrains is not loaded." end
		local player = minetest.get_player_by_name(name)
		if not player then return false, "Run this command in game." end
		local pos = player:get_pos()
		local count, loaded, nearest, distance = 0, 0, nil, math.huge
		for _, train in pairs(advtrains.trains) do
			if train.staticdata and train.staticdata.arnis_spawn then
				count = count + 1
				for _, wid in ipairs(train.trainparts or {}) do
					local object = advtrains.wagon_objects[wid]
					if object and object:get_pos() then loaded = loaded + 1 end
				end
				if train.last_pos then
					local d = vector.distance(pos, train.last_pos)
					if d < distance then nearest, distance = train.last_pos, d end
				end
			end
		end
		local radius = {x=64, y=64, z=64}
		local pending = minetest.find_nodes_in_area(vector.subtract(pos, radius),
			vector.add(pos, radius), {marker})
		return true, ("Arnis trains: mode=%s, generated=%d, loaded wagons=%d, pending within 64 nodes=%d, wagon loading range=%g. %s"):format(
			mode, count, loaded, #pending, advtrains.wagon_load_range,
			nearest and ("Nearest: " .. minetest.pos_to_string(nearest) ..
				(" (%.0f nodes away)."):format(distance)) or "No generated trains yet.")
	end,
})
]]
