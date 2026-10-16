-- Obsidian frame and paired-destination design inspired by PilzAdam's Nether mod.
-- Object traversal follows Meseportals' player/physical-entity approach.
local api = core
local settings = api.settings
local function setting(name, fallback, low, high)
    return math.max(low, math.min(high, math.floor(tonumber(settings:get(name)) or fallback)))
end
-- Never queue blocks beyond the configured world boundary: those may be
-- skipped without an emerge completion callback.
local map_limit = math.floor(assert(tonumber(api.get_mapgen_setting("mapgen_limit")),
    "portals requires the mapgen_limit mapgen setting") / 16) * 16
local y_offset = setting("portals_y_offset", 10000, 1, map_limit * 2)
local xz_offset = setting("portals_xz_offset", 10000, 0, map_limit)
local y_radius = setting("portals_y_radius", 500, 2, map_limit)
local radius = setting("portals_search_radius", 1000, 16, map_limit)
local max_frame_size = setting("portals_max_frame_size", 64, 3, 1024)
local attempts = setting("portals_search_attempts", 24, 1, 256)
local transfer_liquids = settings:get_bool("portals_transfer_liquids", true)
local spawn_in_liquids = settings:get_bool("portals_spawn_in_liquids", true)
local safe_destination = settings:get_bool("portals_safe_destination", false)
local function open_destination(name)
    if name == "air" then return true end
    local def = api.registered_nodes[name]
    return spawn_in_liquids and def
        and (not safe_destination or def.walkable == false and (def.damage_per_second or 0) == 0)
        and (def.liquidtype == "source" or def.liquidtype == "flowing")
end
local liquid_arrivals = {}
local timeout = setting("portals_search_timeout", 180, 10, 3600)
local function emerge_bounds(p)
    return {
        x = math.max(-map_limit, math.min(map_limit, p.x)),
        y = math.max(-map_limit, math.min(map_limit, p.y)),
        z = math.max(-map_limit, math.min(map_limit, p.z)),
    }
end
local frame, down_frame, field = "default:obsidian", "default:obsidian_block", "portals:portal"
local up_field = "portals:portal_up"
local function is_field(name)
    return name == field or name == up_field
end
local function is_frame(name)
    return name == frame or name == down_frame
end
local storage = api.get_mod_storage()
local function pair_key(p, axis)
    return "pair:" .. axis .. ":" .. api.pos_to_string(p)
end
local function remember(p, axis, target)
    local key = pair_key(p, axis)
    local value = api.pos_to_string(target)
    if storage:get_string(key) ~= value then
        storage:set_string(key, value)
    end
end
local pending = {}
local active_portals = {}

local cooldown = setmetatable({}, {
    __mode = "k",
})
local function point(p, axis, u, v, depth)
    if axis == 2 then
        return {x = p.x + u, y = p.y + (depth or 0), z = p.z + v}
    end
    return {
        x = p.x + (axis == 0 and u or depth or 0),
        y = p.y + v,
        z = p.z + (axis == 1 and u or depth or 0),
    }
end
local function width(p) return p.width or 4 end
local function height(p) return p.height or 5 end
local function sized(p, w, h)
    p.width, p.height = w, h
    return p
end
local function vertical_span(p, axis)
    return axis == 2 and 1 or height(p)
end
local function facing(axis) return axis == 2 and 4 or axis end
local function frame_min(p, axis, pad)
    if axis == 2 then pad = math.max(pad, 4) end
    return vector.offset(p, -pad, -pad, -pad)
end
local function frame_max(p, axis, dimensions, pad)
    if axis == 2 then
        pad = math.max(pad, 4)
        return vector.offset(p, width(dimensions) - 1 + pad, pad, height(dimensions) - 1 + pad)
    end
    return vector.offset(p, axis == 0 and width(dimensions) - 1 + pad or pad,
        height(dimensions) - 1 + pad, axis == 1 and width(dimensions) - 1 + pad or pad)
end
local function track(p, axis)
    active_portals[api.pos_to_string(p)] = point(p, axis, 1, 1)
end
local function each(p, axis, fn)
    for u = 0, width(p) - 1 do
        for v = 0, height(p) - 1 do
            local edge = u == 0 or u == width(p) - 1 or v == 0 or v == height(p) - 1
            if fn(point(p, axis, u, v), edge) == false then
                return false
            end
        end
    end
    return true
end
local function valid(p, axis, lit)
    return each(p, axis, function(q, edge)
        local node = api.get_node_or_nil(q)
        return node ~= nil and
                   (edge and is_frame(node.name) or not edge and
                       (lit and is_field(node.name) or not lit and node.name == "air"))
    end)
end
local function allowed(p, axis, owner)
    return each(p, axis, function(q)
        return not api.is_protected(q, owner)
    end)
end
local function metadata(p)
    local meta = api.get_meta(p)
    local origin = api.string_to_pos(meta:get_string("origin"))
    local target = api.string_to_pos(meta:get_string("target"))
    local w, h = meta:get_int("width"), meta:get_int("height")
    w, h = w >= 3 and w or 4, h >= 3 and h or 5
    if origin then sized(origin, w, h) end
    if target then sized(target, w, h) end
    return origin, meta:get_int("axis"), target, meta:get_string("owner")
end
local function reusable_frame(p, axis, source)
    return each(p, axis, function(q, edge)
        local name = api.get_node(q).name
        if edge then
            return is_frame(name)
        end
        if name == "air" then
            return true
        end
        if not is_field(name) then
            return false
        end
        local origin, other_axis, back = metadata(q)
        return origin ~= nil and back ~= nil and other_axis == axis and vector.equals(origin, p) and
                   vector.equals(back, source)
    end)
end
local function frame_accessible(p, axis, owner)
    for u = 0, width(p) - 1 do
        for v = axis == 2 and 0 or -1, height(p) - 1 do
            for d = axis == 2 and -4 or -1, axis == 2 and 3 or 1 do
                if api.is_protected(point(p, axis, u, v, d), owner) then
                    return false
                end
            end
        end
    end
    return true
end
local function extinguish(p, axis)
    active_portals[api.pos_to_string(p)] = nil
    each(p, axis, function(q, edge)
        if not edge and is_field(api.get_node(q).name) then
            local origin = metadata(q)
            if origin and vector.equals(origin, p) then
                local _, _, target = metadata(q)
                if target then
                    remember(p, axis, target)
                end
                api.remove_node(q)
            end
        end
    end)
end
local function build(p, axis, target, owner, material)
    local surface = (material or api.get_node(p).name) == down_frame and up_field or field
    each(p, axis, function(q, edge)
        if not edge or not is_frame(api.get_node(q).name) then
            api.set_node(q, {
                name = edge and (material or frame) or surface,
                param2 = facing(axis),
            })
        end
        if not edge then
            local meta = api.get_meta(q)
            meta:set_string("origin", api.pos_to_string(p))
            meta:set_int("axis", axis)
            meta:set_int("width", width(p))
            meta:set_int("height", height(p))
            meta:set_string("target", api.pos_to_string(target))
            meta:set_string("owner", owner)
            meta:set_string("infotext", "Deep cave portal")
        end
    end)
    remember(p, axis, target)
    track(p, axis)
end
-- Require natural solid footing and air or safe liquids in the volume, including
-- both exits. Never excavate, overwrite a build, or place in a protected volume.
local function cave_site(p, axis, owner, upward)
    for u = 0, width(p) - 1 do
        for v = axis == 2 and 0 or -1, height(p) - 1 do
            for d = axis == 2 and -4 or -1, axis == 2 and 3 or 1 do
                local q = point(p, axis, u, v, d)
                if api.is_protected(q, owner) then return false end
                local node = api.get_node_or_nil(q)
                local def = node and api.registered_nodes[node.name]
                if not def then return false end
                local footing = axis == 2 and d == -4 or axis ~= 2 and v == -1
                if footing then
                    local liquid_footing = not safe_destination and node.name ~= "air" and open_destination(node.name)
                    if not liquid_footing and (not def.walkable
                        or safe_destination and (def.damage_per_second or 0) > 0
                        or not upward and api.get_item_group(node.name, "stone") == 0) then return false end
                elseif not open_destination(node.name) then
                    return false
                end
            end
        end
    end
    return true
end
local function notify(owner, text)
    api.chat_send_player(owner, "Portal: " .. text)
end
local function ignite(p, axis, owner)
    local key = api.pos_to_string(p)
    if pending[key] then
        return
    end
    -- Hash the full coordinate string so all axes influence a private RNG.
    -- Multiplication stays below Lua's exact-integer limit.
    local seed = 0
    for i = 1, #key do
        seed = (seed * 131 + key:byte(i)) % 2147483647
    end
    local random = PcgRandom(seed)
    -- Offset along the portal face normal: XY frames use Z, ZY frames use X.
    local distance = axis == 2 and 0 or math.min(map_limit, math.floor(xz_offset * (width(p) - 2) + 0.5))
    local offset = random:next(0, 1) == 0 and -distance or distance
    local dx = axis == 1 and offset or 0
    local dz = axis == 0 and offset or 0
    -- Prefer the opposite direction if the selected offset crosses the world edge.
    if math.abs(p.x + dx) > map_limit then
        dx = -dx
    end
    if math.abs(p.z + dz) > map_limit then
        dz = -dz
    end
    local target_x, target_z = p.x + dx, p.z + dz
    local upward = api.get_node(p).name == down_frame
    local direction = upward and "above" or "below"
    local destination_material = upward and frame or down_frame
    -- Flat frames scale by opening area, standing frames by opening height.
    local y_multiplier = axis == 2 and (width(p) - 2) * (height(p) - 2) or (height(p) - 2)
    local vertical_distance = math.floor(y_offset * y_multiplier + 0.5)
    local target_y = p.y + (upward and vertical_distance or -vertical_distance)
    local floor_names = {"group:stone"}
    if upward then
        -- Return portals can stand on soil and other safe solid surfaces too.
        floor_names = {}
        for name, def in pairs(api.registered_nodes) do
            if def.walkable ~= false and (not safe_destination or (def.damage_per_second or 0) == 0) and
                (not def.liquidtype or def.liquidtype == "none") then
                floor_names[#floor_names + 1] = name
            end
        end
    end
    if spawn_in_liquids and not safe_destination then
        for name, def in pairs(api.registered_nodes) do
            if def.liquidtype == "source" or def.liquidtype == "flowing" then
                floor_names[#floor_names + 1] = name
            end
        end
    end
    local ymin = math.max(-map_limit + (axis == 2 and 4 or 1), target_y - y_radius)
    local ymax = math.min(map_limit - (axis == 2 and 3 or 0), target_y + y_radius)
    local job = {}
    pending[key] = job
    local trial = 0
    local started = api.get_us_time() / 1000000
    local last_report = started
    local function active()
        return pending[key] == job
    end
    local function finish(message)
        if not active() then
            return
        end
        pending[key] = nil
        if message then
            notify(owner, message)
        end
    end
    local function source_ready()
        if not valid(p, axis, false) then
            finish("search cancelled: the source frame changed or unloaded; replace a frame block to retry.")
            return false
        end
        if not allowed(p, axis, owner) then
            finish("search cancelled: the source frame is protected.")
            return false
        end
        return true
    end
    local search
    search = function()
        if not active() or not source_ready() then
            return
        end
        if ymax - ymin < vertical_span(p, axis) - 1 then
            finish("cannot search " .. vertical_distance .. " nodes " .. direction ..
                       " this frame: the target range is outside the world Y limits.")
            return
        end
        trial = trial + 1
        if trial > attempts then
            finish("no safe, unprotected cave found after " .. attempts .. " regions; replace a frame block to retry.")
            return
        end
        local center = {
            x = target_x + random:next(-radius, radius),
            y = random:next(ymin, ymax - vertical_span(p, axis) + 1),
            z = target_z + random:next(-radius, radius),
        }
        local spread = 8
        local minp = emerge_bounds(vector.offset(center, -spread, 0, -spread))
        local maxp = emerge_bounds(vector.offset(center, spread, math.min(31, ymax - center.y), spread))
        minp.x, minp.z = math.max(minp.x, target_x - radius), math.max(minp.z, target_z - radius)
        maxp.x, maxp.z = math.min(maxp.x, target_x + radius), math.min(maxp.z, target_z + radius)
        local function in_window(q)
            return q.y >= ymin and q.y + vertical_span(p, axis) - 1 <= ymax
        end
        local complete = false
        local region_trial = trial
        local function inspect()
            if not active() or region_trial ~= trial or not source_ready() then
                return
            end
            -- A cancelled block does not invalidate the loaded part of a region.
            -- cave_site checks every node of each candidate before any changes.
            -- Recover inactive frames from before pair records existed. The bottom
            -- left frame node is itself obsidian, so test each found node as an origin.
            for _, old in ipairs(api.find_nodes_in_area(minp, maxp, {frame, down_frame})) do
                sized(old, width(p), height(p))
                if not vector.equals(old, p) and in_window(old) and reusable_frame(old, axis, p) and
                    frame_accessible(old, axis, owner) then
                    build(old, axis, p, owner)
                    build(p, axis, old, owner)
                    finish("reconnected to existing frame at " .. api.pos_to_string(old))
                    return
                end
            end
            local floor_min, floor_max = minp, maxp
            if axis == 2 then
                floor_min, floor_max = vector.offset(minp, 0, -4, 0), vector.offset(maxp, 0, -4, 0)
            end
            local floors = api.find_nodes_in_area_under_air(floor_min, floor_max, floor_names)
            if spawn_in_liquids then
                -- under_air omits submerged floors; include floors under safe liquids too.
                for _, floor in ipairs(api.find_nodes_in_area(floor_min, floor_max, floor_names)) do
                    local above = api.get_node_or_nil(vector.offset(floor, 0, 1, 0))
                    if above and above.name ~= "air" and open_destination(above.name) then
                        floors[#floors + 1] = floor
                    end
                end
            end
            for _, floor in ipairs(floors) do
                local dest = sized(vector.offset(floor, 0, axis == 2 and 4 or 1, 0), width(p), height(p))
                if in_window(dest) and cave_site(dest, axis, owner, upward) then
                    build(dest, axis, p, owner, destination_material)
                    build(p, axis, dest, owner)
                    finish((upward and "linked to upper portal at " or "linked to cave at ") .. api.pos_to_string(dest))
                    return
                end
            end
            if complete then
                api.after(0, search)
            else
                api.after(2, inspect)
            end
        end
        api.emerge_area(emerge_bounds(frame_min(minp, axis, 2)), emerge_bounds(frame_max(maxp, axis, p, 1)),
            function(_, _, remaining)
                if remaining == 0 then
                    complete = true
                end
            end)
        -- Inspect on the server step, including partially emerged regions.
        api.after(0, inspect)
    end
    local function reconnect()
        local target = api.string_to_pos(storage:get_string(pair_key(p, axis)))
        if not target or vector.equals(target, p) then
            search();
            return
        end
        sized(target, width(p), height(p))
        notify(owner, "checking the previous portal at " .. api.pos_to_string(target) .. "…")
        local complete = false
        local function inspect()
            if not active() or not source_ready() then
                return
            end
            local loaded = each(target, axis, function(q)
                local node = api.get_node_or_nil(q)
                return node ~= nil and node.name ~= "ignore"
            end)
            if not loaded then
                if complete then
                    search()
                else
                    api.after(2, inspect)
                end
                return
            end
            if not reusable_frame(target, axis, p) then
                search();
                return
            end
            if not frame_accessible(target, axis, owner) then
                finish("cannot reconnect: the previous portal is protected.")
                return
            end
            build(target, axis, p, owner)
            build(p, axis, target, owner)
            finish("reconnected to portal at " .. api.pos_to_string(target))
        end
        api.emerge_area(emerge_bounds(frame_min(target, axis, 2)), emerge_bounds(frame_max(target, axis, target, 2)),
            function(_, _, remaining)
                if remaining == 0 then
                    complete = true
                end
            end)
        api.after(0, inspect)
    end
    local function watch()
        if not active() then
            return
        end
        local now = api.get_us_time() / 1000000
        if now - started >= timeout then
            finish("search timed out after " .. timeout .. " seconds in region " .. trial ..
                       "; replace a frame block to retry, or increase portals_search_timeout.")
            return
        end
        if now - last_report >= 10 then
            last_report = now
            notify(owner, "still searching: region " .. trial .. "/" .. attempts .. ", " .. math.floor(now - started) ..
                " seconds elapsed.")
        end
        api.after(2, watch)
    end
    notify(owner, upward and "searching for free space above…" or "searching for a deep cave…")
    api.after(2, watch)
    reconnect()
end
local function register_surface(name, tint)
    api.register_node(name, {
        description = "Deep cave portal",
        drawtype = "nodebox",
        tiles = {"default_obsidian.png^[colorize:" .. tint .. ":180"},
        use_texture_alpha = "blend",
        paramtype = "light",
        paramtype2 = "facedir",
        light_source = 12,
        walkable = false,
        pointable = false,
        diggable = false,
        buildable_to = false,
        drop = "",
        groups = {
            not_in_creative_inventory = 1,
        },
        node_box = {
            type = "fixed",
            fixed = {-0.5, -0.5, -0.08, 0.5, 0.5, 0.08},
        },
        on_blast = function()
        end,
    })
end
register_surface(field, "#9933ff")
register_surface(up_field, "#7755ff")
-- Locate a rectangular air opening beside a newly placed frame node. Starting
-- from nearby air also recognizes a corner placed last, without scanning an
-- unbounded connected air region outside the frame.
local function detect_frame(pos, axis, du, dv)
    local function name(u, v)
        local node = api.get_node_or_nil(point(pos, axis, u, v))
        return node and node.name
    end
    if name(du, dv) ~= "air" then return nil end
    local left, bottom = du, dv
    for _ = 1, max_frame_size - 2 do
        if name(left - 1, dv) ~= "air" then break end
        left = left - 1
    end
    for _ = 1, max_frame_size - 2 do
        if name(du, bottom - 1) ~= "air" then break end
        bottom = bottom - 1
    end
    if not is_frame(name(left - 1, dv)) or not is_frame(name(du, bottom - 1)) then return nil end
    local w, h = 0, 0
    for count = 1, max_frame_size - 2 do
        if name(left + count - 1, bottom) ~= "air" then break end
        w = count
    end
    for count = 1, max_frame_size - 2 do
        if name(left, bottom + count - 1) ~= "air" then break end
        h = count
    end
    if w == 0 or h == 0 then return nil end
    local p = sized(point(pos, axis, left - 1, bottom - 1), w + 2, h + 2)
    if valid(p, axis, false) then return p end
end
api.register_on_placenode(function(pos, node, placer)
    if not is_frame(node.name) or not placer or not placer:is_player() then return end
    local owner = placer:get_player_name()
    for axis = 0, 2 do
        for du = -1, 1 do
            for dv = -1, 1 do
                if du ~= 0 or dv ~= 0 then
                    local p = detect_frame(pos, axis, du, dv)
                    if p and allowed(p, axis, owner) then
                        ignite(p, axis, owner)
                        return
                    end
                end
            end
        end
    end
end)

local function node_state(pos)
    local meta = api.get_meta(pos):to_table()
    if not meta then
        return nil
    end
    local timer = api.get_node_timer(pos)
    return {
        meta = meta,
        started = timer:is_started(),
        timeout = timer:get_timeout(),
        elapsed = timer:get_elapsed(),
    }
end
local function apply_state(pos, state)
    if not api.get_meta(pos):from_table(state.meta) then
        return false
    end
    local timer = api.get_node_timer(pos)
    if state.started then
        timer:set(state.timeout, state.elapsed)
    else
        timer:stop()
    end
    return true
end
local function transfer_node(source, dest, node, dest_node)
    local source_state, dest_state = node_state(source), node_state(dest)
    if not source_state or not dest_state then
        return false
    end
    local placed, removed = false, false
    local ok = pcall(function()
        -- Swapping avoids construction/destruction callbacks overwriting copied
        -- data, restarting timers, or dropping inventory contents during a move.
        placed = api.swap_node(dest, node)
        assert(placed and apply_state(dest, source_state))
        removed = api.swap_node(source, {
            name = "air",
        })
        assert(removed)
        assert(api.get_meta(source):from_table(nil))
        api.get_node_timer(source):stop()
    end)
    if ok then
        return true
    end
    local restored = pcall(function()
        if removed then
            assert(api.swap_node(source, node) and apply_state(source, source_state))
        end
        if placed then
            assert(api.swap_node(dest, dest_node) and apply_state(dest, dest_state))
        end
    end)
    if not restored then
        api.log("error", "[portals] Failed to roll back node transfer at " .. api.pos_to_string(source) .. " -> " ..
            api.pos_to_string(dest))
    end
    return false
end

local function move_liquids(p, axis, target, owner, now)
    if not transfer_liquids then
        return
    end
    for u = 1, width(p) - 2 do
        for v = 1, height(p) - 2 do
            for _, side in ipairs({-1, 1}) do
                local source = point(p, axis, u, v, side)
                local node = api.get_node_or_nil(source)
                local def = node and api.registered_nodes[node.name]
                if def and (def.liquidtype == "source" or def.liquidtype == "flowing") and
                    (liquid_arrivals[api.pos_to_string(source)] or 0) <= now then
                    local dest = axis == 2 and point(target, axis, u, v, -side - 1)
                        or point(target, axis, u, v - 1, -side)
                    local dest_node = api.get_node_or_nil(dest)
                    if dest_node and dest_node.name == "air" and not api.is_protected(source, owner) and
                        not api.is_protected(dest, owner) then
                        if transfer_node(source, dest, node, dest_node) then
                            liquid_arrivals[api.pos_to_string(dest)] = now + 0.5
                        end
                    end
                end
            end
        end
    end
end

local function horizontal_exit_clear(pos, props, player)
    local box = props and props.collisionbox or (player and {-0.3, 0, -0.3, 0.3, 1.75, 0.3}
        or {-0.3, -0.3, -0.3, 0.3, 0.3, 0.3})
    for x = math.floor(pos.x + box[1] + 0.500001), math.floor(pos.x + box[4] + 0.499999) do
        for y = math.floor(pos.y + box[2] + 0.500001), math.floor(pos.y + box[5] + 0.499999) do
            for z = math.floor(pos.z + box[3] + 0.500001), math.floor(pos.z + box[6] + 0.499999) do
                local node = api.get_node_or_nil({x = x, y = y, z = z})
                if not node or not open_destination(node.name) and not is_field(node.name) then return false end
            end
        end
    end
    return true
end

local loading = {}
local function process_portal(pos)
    local p, axis, target, owner = metadata(pos)
    if not p or not target then
        api.remove_node(pos);
        return
    end
    local loaded = each(p, axis, function(q)
        local n = api.get_node_or_nil(q)
        return n ~= nil and n.name ~= "ignore"
    end)
    if not loaded then
        return
    end
    if not valid(p, axis, true) then
        extinguish(p, axis);
        return
    end
    -- Upgrade existing surfaces while retaining their link metadata and facing.
    local surface = api.get_node(p).name == down_frame and up_field or field
    each(p, axis, function(q, edge)
        if not edge then
            local node = api.get_node(q)
            if node.name ~= surface then
                api.swap_node(q, {
                    name = surface,
                    param2 = node.param2,
                })
            end
        end
    end)
    if not vector.equals(pos, point(p, axis, 1, 1)) then
        return
    end
    local target_cell = point(target, axis, 1, 1)
    local node = api.get_node_or_nil(target_cell)
    if not node or node.name == "ignore" or not each(target, axis, function(q)
        local n = api.get_node_or_nil(q)
        return n ~= nil and n.name ~= "ignore"
    end) then
        local key = api.pos_to_string(target)
        local requested = api.get_us_time()
        if not loading[key] or requested - loading[key] > 10000000 then
            loading[key] = requested
            api.emerge_area(emerge_bounds(frame_min(target, axis, 2)),
                emerge_bounds(frame_max(target, axis, target, 2)), function(_, _, remaining)
                    if remaining == 0 and loading[key] == requested then
                        loading[key] = nil
                    end
                end)
        end
        return
    end
    local other, other_axis, back = metadata(target_cell)
    if not other or not back or other_axis ~= axis or not vector.equals(other, target) or not vector.equals(back, p) or
        width(other) ~= width(p) or height(other) ~= height(p) or not valid(target, axis, true) then
        extinguish(p, axis)
        return
    end
    track(target, axis)
    local now = api.get_us_time() / 1000000
    move_liquids(p, axis, target, owner, now)
    local half_w, half_h = (width(p) - 1) / 2, (height(p) - 1) / 2
    local center = point(p, axis, half_w, half_h)
    local object_radius = math.sqrt(half_w * half_w + half_h * half_h) + 0.6
    for _, object in ipairs(api.get_objects_inside_radius(center, object_radius)) do
        local player = object:is_player()
        local entity = not player and object:get_luaentity()
        local props = object:get_properties()
        local q = object:get_pos()
        local u = q and (axis == 1 and q.z - p.z or q.x - p.x)
        local v = q and (axis == 2 and q.z - p.z or q.y - p.y)
        local d = q and (axis == 2 and q.y - p.y or axis == 0 and q.z - p.z or q.x - p.x)
        if q and (player or entity and (entity.name == "__builtin:item" or props and props.physical)) and
            not object:get_attach() and (cooldown[object] or 0) < now and u >= 0.5 and u <= width(p) - 1.5 and v >= 0.5 and
            v <= height(p) - 1.5 and math.abs(d) <= 0.6 then
            local name = player and object:get_player_name() or owner
            local velocity = object:get_velocity()
            local exit_depth = 0
            if axis == 2 then
                local from_above = d > 0 or d == 0 and (velocity and velocity.y or 0) <= 0
                local top = props and props.collisionbox and props.collisionbox[5] or (player and 1.75 or 0.3)
                exit_depth = from_above and -(math.max(0, top) + 0.6) or 0.75
            end
            local arrival = point(target, axis, u, v, exit_depth)
            if not api.is_protected(q, name) and not api.is_protected(arrival, name)
                and (axis ~= 2 or horizontal_exit_clear(arrival, props, player)) then
                cooldown[object] = now + 4
                object:set_pos(arrival)
                if not player and velocity then
                    object:set_velocity(velocity)
                end
            end
        end
    end
end

-- ABMs also discover portals in blocks that were already active when linked.
api.register_abm({
    label = "Deep cave portal frame validation",
    nodenames = {field, up_field},
    interval = 1,
    chance = 1,
    action = function(pos)
        local p, axis, target = metadata(pos)
        if p then
            if target then
                remember(p, axis, target);
                remember(target, axis, p)
            end
            track(p, axis)
        end
        process_portal(pos)
    end,
})
api.register_lbm({
    name = "portals:restore_tracking",
    label = "Restore deep cave portal traversal",
    nodenames = {field, up_field},
    run_at_every_load = true,
    action = function(pos)
        local p, axis, target = metadata(pos)
        if p then
            if target then
                remember(p, axis, target);
                remember(target, axis, p)
            end
            track(p, axis)
        end
    end,
})
local elapsed = 0
api.register_globalstep(function(dtime)
    elapsed = elapsed + dtime
    if elapsed < 0.1 then
        return
    end
    elapsed = 0
    local now = api.get_us_time() / 1000000
    for key, expiry in pairs(liquid_arrivals) do
        if expiry <= now then
            liquid_arrivals[key] = nil
        end
    end
    for key, pos in pairs(active_portals) do
        local node = api.get_node_or_nil(pos)
        if not node or not is_field(node.name) then
            active_portals[key] = nil
        else
            process_portal(pos)
        end
    end
end)
