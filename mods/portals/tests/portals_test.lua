local root = 'games/default/mods/portals/'
local nodes, metas, callbacks, messages = {}, {}, {}, {}
local timers = {}
local function copy(value)
    if type(value) ~= 'table' then
        return value
    end
    local result = {}
    for k, v in pairs(value) do
        result[k] = copy(v)
    end
    return result
end
local function key(p)
    return p.x .. ',' .. p.y .. ',' .. p.z
end
vector = {
    offset = function(p, x, y, z)
        return {
            x = p.x + x,
            y = p.y + y,
            z = p.z + z,
        }
    end,
    equals = function(a, b)
        return key(a) == key(b)
    end,
}
local protected = false
local objects = {}
local clock = 10000000
local mapgen_limit = 31000
local jobs = {}
local saved_pairs = {}
local persist_pairs = false
local storage = {
    get_string = function(_, key)
        return persist_pairs and saved_pairs[key] or ''
    end,
    set_string = function(_, key, value)
        if persist_pairs then
            saved_pairs[key] = value
        end
    end,
}
-- A deterministic stand-in for the engine RNG, exercising seed isolation.
PcgRandom = function(seed)
    local state = seed % 2147483646 + 1
    return {
        next = function(_, low, high)
            state = state * 48271 % 2147483647
            return low + state % (high - low + 1)
        end,
    }
end
core = {
    get_mod_storage = function()
        return storage
    end,
    settings = {
        get_bool = function(_, _, fallback)
            return fallback
        end,
        get = function(_, n)
            if n == 'portals_search_attempts' then
                return '1'
            end
            if n == 'portals_y_offset' then
                return '30750'
            end
            return nil
        end,
    },
    find_nodes_in_area = function()
        return {}
    end,
    get_mapgen_setting = function(name)
        if name == "mapgen_limit" then
            return tostring(mapgen_limit)
        end
    end,
    registered_nodes = {
        air = {
            walkable = false,
        },
        ['default:stone'] = {
            walkable = true,
        },
        ['default:obsidian'] = {
            walkable = true,
        },
        ['default:obsidian_block'] = {
            walkable = true,
        },
    },
    get_node = function(p)
        return nodes[key(p)] or {
            name = 'air',
        }
    end,
    get_node_or_nil = function(p)
        return core.get_node(p)
    end,
    set_node = function(p, n)
        nodes[key(p)] = n;
        metas[key(p)] = nil;
        return true
    end,
    swap_node = function(p, n)
        nodes[key(p)] = n;
        return true
    end,
    remove_node = function(p)
        nodes[key(p)] = nil;
        metas[key(p)] = nil;
        return true
    end,
    get_meta = function(p)
        local k = key(p);
        metas[k] = metas[k] or {};
        local m = metas[k]
        return {
            set_string = function(_, k, v)
                m[k] = v
            end,
            get_string = function(_, k)
                return m[k] or ''
            end,
            set_int = function(_, k, v)
                m[k] = v
            end,
            get_int = function(_, k)
                return m[k] or 0
            end,
            to_table = function()
                local fields = {}
                for key, value in pairs(m) do
                    if key:sub(1, 1) ~= '_' then
                        fields[key] = copy(value)
                    end
                end
                return {
                    fields = fields,
                    inventory = copy(m._inventory or {}),
                    private_fields = copy(m._private or {}),
                    inventory_widths = copy(m._widths or {}),
                }
            end,
            from_table = function(_, data)
                local restored = copy(data and data.fields or {})
                restored._inventory = copy(data and data.inventory or {})
                restored._private = copy(data and data.private_fields or {})
                restored._widths = copy(data and data.inventory_widths or {})
                metas[k] = restored
                return true
            end,
        }
    end,
    get_node_timer = function(p)
        local k = key(p)
        return {
            is_started = function()
                return (timers[k] and timers[k].timeout or 0) > 0
            end,
            get_timeout = function()
                return timers[k] and timers[k].timeout or 0
            end,
            get_elapsed = function()
                return timers[k] and timers[k].elapsed or 0
            end,
            set = function(_, timeout, elapsed)
                timers[k] = {
                    timeout = timeout,
                    elapsed = elapsed,
                }
            end,
            stop = function()
                timers[k] = nil
            end,
        }
    end,
    log = function()
    end,
    pos_to_string = key,
    string_to_pos = function(s)
        local x, y, z = s:match('^([%d.-]+),([%d.-]+),([%d.-]+)$');
        if x then
            return {
                x = tonumber(x),
                y = tonumber(y),
                z = tonumber(z),
            }
        end
    end,
    is_protected = function()
        return protected
    end,
    get_item_group = function(n)
        return n == 'default:stone' and 1 or 0
    end,
    chat_send_player = function(_, s)
        messages[#messages + 1] = s
    end,
    register_node = function(n, d)
        core.registered_nodes[n] = d
    end,
    register_on_placenode = function(f)
        callbacks.place = f
    end,
    register_abm = function(d)
        callbacks.abm = d.action
    end,
    register_lbm = function(d)
        callbacks.lbm = d.action
    end,
    register_globalstep = function(f)
        callbacks.step = f
    end,
    after = function(delay, f)
        if delay == 0 then
            f()
        else
            jobs[#jobs + 1] = {
                at = clock / 1000000 + delay,
                run = f,
            }
        end
    end,
    emerge_area = function(a, b, f)
        f(a, 0, 0)
    end,
    get_us_time = function()
        return clock
    end,
    get_objects_inside_radius = function()
        return objects
    end,
}
local dest = {
    x = 20,
    y = -30900,
    z = 20,
}
core.find_nodes_in_area_under_air = function()
    return {dest}
end
for x = 20, 23 do
    for z = 19, 21 do
        for y = -30901, -30900 do
            nodes[key({
                x = x,
                y = y,
                z = z,
            })] = {
                name = 'default:stone',
            }
        end
    end
end
local function frame()
    for x = 0, 3 do
        for y = 0, 4 do
            nodes[key({
                x = x,
                y = y,
                z = 0,
            })] = {
                name = (x == 0 or x == 3 or y == 0 or y == 4) and 'default:obsidian' or 'air',
            }
        end
    end
end
local player = {
    is_player = function()
        return true
    end,
    get_player_name = function()
        return 'builder'
    end,
}
dofile(root .. 'init.lua')
frame();
protected = true
callbacks.place({
    x = 0,
    y = 0,
    z = 0,
}, {
    name = 'default:obsidian',
}, player)
assert(#messages == 0, 'protected frame activated')
protected = false
callbacks.place({
    x = 0,
    y = 0,
    z = 0,
}, {
    name = 'default:obsidian',
}, player)
assert(core.get_node({
    x = 1,
    y = 1,
    z = 0,
}).name == 'portals:portal', 'source not lit')
assert(core.get_node({
    x = 21,
    y = -30898,
    z = 20,
}).name == 'portals:portal_up', 'destination not lit')
assert(core.get_node({
    x = 21,
    y = -30899,
    z = 20,
}).name == 'default:obsidian_block', 'destination frame not raised above floor')
for x = 20, 23 do
    for z = 19, 21 do
        assert(core.get_node({
            x = x,
            y = -30900,
            z = z,
        }).name == 'default:stone', 'cave floor was replaced')
    end
end
local itempos = {
    x = 1,
    y = 1,
    z = 0,
}
local velocity = {
    x = 1,
    y = 0,
    z = 2,
}
local item_physical = true
local item = {
    is_player = function()
        return false
    end,
    get_luaentity = function()
        return {
            name = '__builtin:item',
        }
    end,
    get_properties = function()
        return {
            physical = item_physical,
        }
    end,
    get_pos = function()
        return itempos
    end,
    get_attach = function()
    end,
    get_velocity = function()
        return velocity
    end,
    set_pos = function(_, p)
        itempos = p
    end,
    set_velocity = function(_, v)
        assert(v == velocity)
    end,
}
objects = {item}
callbacks.abm({
    x = 1,
    y = 1,
    z = 0,
})
assert(itempos.y == -30898, 'item not teleported')
callbacks.abm({
    x = 21,
    y = -30898,
    z = 20,
})
assert(itempos.y == -30898, 'cooldown failed')
core.remove_node({
    x = 0,
    y = 2,
    z = 0,
})
callbacks.abm({
    x = 1,
    y = 1,
    z = 0,
})
assert(core.get_node({
    x = 1,
    y = 1,
    z = 0,
}).name == 'air', 'broken frame stays active')
callbacks.abm({
    x = 21,
    y = -30898,
    z = 20,
})
assert(core.get_node({
    x = 21,
    y = -30898,
    z = 20,
}).name == 'air', 'broken link stays active')
frame();
protected = false
core.find_nodes_in_area_under_air = function()
    return {}
end
callbacks.place({
    x = 0,
    y = 0,
    z = 0,
}, {
    name = 'default:obsidian',
}, player)
assert(messages[#messages]:find('no safe'), 'missing search failure')
assert(core.get_node({
    x = 1,
    y = 1,
    z = 0,
}).name == 'air', 'failed search changed source')
print('PASS: protection, paired activation, dropped item traversal, cooldown, broken links, bounded failure')
-- Destination protection must reject the whole build, even with an open source.
nodes, metas = {}, {}
frame()
core.find_nodes_in_area_under_air = function()
    return {dest}
end
core.is_protected = function(p)
    return p.y < -10000
end
callbacks.place({
    x = 0,
    y = 0,
    z = 0,
}, {
    name = 'default:obsidian',
}, player)
assert(core.get_node({
    x = 1,
    y = 1,
    z = 0,
}).name == 'air', 'protected destination activated')
-- Exercise the perpendicular frame and the player-specific traversal path.
core.is_protected = function()
    return false
end
nodes, metas = {}, {}
for z = 0, 3 do
    for y = 0, 4 do
        nodes[key({
            x = 0,
            y = y,
            z = z,
        })] = {
            name = (z == 0 or z == 3 or y == 0 or y == 4) and 'default:obsidian' or 'air',
        }
    end
end
for x = 19, 21 do
    for z = 20, 23 do
        for y = -30901, -30900 do
            nodes[key({
                x = x,
                y = y,
                z = z,
            })] = {
                name = 'default:stone',
            }
        end
    end
end
callbacks.place({
    x = 0,
    y = 0,
    z = 0,
}, {
    name = 'default:obsidian',
}, player)
assert(core.get_node({
    x = 0,
    y = 1,
    z = 1,
}).name == 'portals:portal', 'perpendicular frame not lit')
local travellerpos = {
    x = 0,
    y = 1,
    z = 1,
}
local traveller = {
    is_player = function()
        return true
    end,
    get_player_name = function()
        return 'visitor'
    end,
    get_properties = function()
        return {
            physical = true,
        }
    end,
    get_pos = function()
        return travellerpos
    end,
    get_attach = function()
    end,
    get_velocity = function()
        return velocity
    end,
    set_pos = function(_, p)
        travellerpos = p
    end,
}
objects = {traveller}
core.is_protected = function(p, name)
    return p.y < -10000 and name == 'visitor'
end
callbacks.abm({
    x = 0,
    y = 1,
    z = 1,
})
assert(travellerpos.y == 1, 'player entered private destination')
core.is_protected = function()
    return false
end
callbacks.abm({
    x = 0,
    y = 1,
    z = 1,
})
assert(travellerpos.y == -30898, 'player did not teleport')
print('PASS: protected destinations, perpendicular frame, player access checks and traversal')

-- Resting dropped items disable physics; they still need to cross portals.
item_physical = false
itempos = {
    x = 0,
    y = 1,
    z = 1,
}
local sleeping = {}
for k, v in pairs(item) do
    sleeping[k] = v
end
objects = {sleeping}
callbacks.abm({
    x = 0,
    y = 1,
    z = 1,
})
assert(itempos.y == -30898, 'sleeping dropped item did not teleport')
print('PASS: sleeping dropped items')
-- Missing mapblocks must not be interpreted as a broken frame.
local get_node_or_nil = core.get_node_or_nil
core.get_node_or_nil = function(p)
    if p.x == 0 and p.y == 4 and p.z == 0 then
        return nil
    end
    return get_node_or_nil(p)
end
callbacks.abm({
    x = 0,
    y = 1,
    z = 1,
})
assert(core.get_node({
    x = 0,
    y = 1,
    z = 1,
}).name == 'portals:portal', 'unloaded frame extinguished')
core.get_node_or_nil = get_node_or_nil
print('PASS: unloaded frame defers validation')
-- A partially emerged region can contain a usable cave despite cancellations.
nodes, metas = {}, {}
frame()
for x = 20, 23 do
    for z = 19, 21 do
        for y = -30901, -30900 do
            nodes[key({
                x = x,
                y = y,
                z = z,
            })] = {
                name = 'default:stone',
            }
        end
    end
end
core.EMERGE_CANCELLED = 0
core.EMERGE_ERRORED = 1
core.emerge_area = function(a, b, f)
    f(a, core.EMERGE_CANCELLED, 5)
end
callbacks.place({
    x = 0,
    y = 0,
    z = 0,
}, {
    name = 'default:obsidian',
}, player)
assert(core.get_node({
    x = 1,
    y = 1,
    z = 0,
}).name == 'portals:portal', 'partial region cave was discarded')
print('PASS: cancelled/missing completion callbacks do not discard a safe loaded cave')
-- No completion callback and no cave must report progress and eventually stop.
nodes, metas = {}, {}
frame()
core.find_nodes_in_area_under_air = function()
    return {}
end
local requests = 0
local late_callback
core.emerge_area = function(a, b, f)
    requests = requests + 1
    assert(a.y >= -30992 and b.y <= 30992, 'out-of-bounds emerge request')
    late_callback = f
end
local random = PcgRandom
PcgRandom = function()
    return {
        next = function(_, low)
            return low
        end,
    }
end
callbacks.place({
    x = 0,
    y = 0,
    z = 0,
}, {
    name = 'default:obsidian',
}, player)
PcgRandom = random
for step = 1, 91 do
    clock = clock + 2000000
    local ready = jobs
    jobs = {}
    for _, job in ipairs(ready) do
        if job.at <= clock / 1000000 then
            job.run()
        else
            jobs[#jobs + 1] = job
        end
    end
end
assert(messages[#messages]:find('timed out'), 'stalled search did not time out')
local progress = false
for _, message in ipairs(messages) do
    if message:find('still searching') then
        progress = true
    end
end
assert(progress, 'missing progress report')
late_callback({
    x = 0,
    y = 0,
    z = 0,
}, 4, 0)
callbacks.place({
    x = 0,
    y = 0,
    z = 0,
}, {
    name = 'default:obsidian',
}, player)
assert(requests == 2, 'timeout did not release pending frame')
print('PASS: map boundary clamping, progress, timeout, late callback and retry')
-- Traversal must work on server steps without waiting for an ABM.
nodes, metas = {}, {}
frame()
for x = 20, 23 do
    for z = 19, 21 do
        for y = -30901, -30900 do
            nodes[key({
                x = x,
                y = y,
                z = z,
            })] = {
                name = 'default:stone',
            }
        end
    end
end
core.emerge_area = function(a, b, f)
    f(a, 4, 0)
end
core.find_nodes_in_area_under_air = function()
    return {dest}
end
dofile(root .. 'init.lua')
callbacks.place({
    x = 0,
    y = 0,
    z = 0,
}, {
    name = 'default:obsidian',
}, player)
travellerpos = {
    x = 1,
    y = 1,
    z = 0.55,
}
objects = {traveller}
callbacks.step(0.1)
assert(travellerpos.y == -30898, 'server-step player traversal failed')
callbacks.step(0.1)
assert(travellerpos.y == -30898, 'server-step cooldown failed')
clock = clock + 4100000
callbacks.step(0.1)
assert(travellerpos.y == 1, 'server-step return trip failed')
-- Unload just the destination; dropped callbacks must not suppress later loads.
local normal_node = core.get_node_or_nil
core.get_node_or_nil = function(p)
    if p.y < -10000 then
        return nil
    end
    return normal_node(p)
end
requests = 0
core.emerge_area = function()
    requests = requests + 1
end
callbacks.step(0.1)
assert(requests == 1, 'unloaded target was not requested')
clock = clock + 11000000
callbacks.step(0.1)
assert(requests == 2, 'missing load callback prevented retry')
core.get_node_or_nil = normal_node
callbacks.step(0.1)
assert(travellerpos.y == -30898, 'reloaded destination did not teleport')
clock = clock + 4100000
callbacks.step(0.1)
assert(travellerpos.y == 1, 'reloaded destination was not tracked for return')
-- Remove tracking as an unload would, then restore from persisted metadata.
core.get_node_or_nil = function()
    return nil
end
callbacks.step(0.1)
core.get_node_or_nil = normal_node
clock = clock + 4100000
callbacks.lbm({
    x = 1,
    y = 1,
    z = 0,
})
callbacks.step(0.1)
assert(travellerpos.y == -30898, 'LBM did not restore traversal')
print('PASS: server-step round trip, cooldown, destination load retry and LBM restoration')

-- Region sequences depend only on frame coordinates and the search settings.
local function regions(origin)
    nodes, metas = {}, {}
    for u = 0, 3 do
        for v = 0, 4 do
            nodes[key(vector.offset(origin, u, v, 0))] = {
                name = (u == 0 or u == 3 or v == 0 or v == 4) and 'default:obsidian' or 'air',
            }
        end
    end
    local sampled = {}
    core.settings.get = function(_, name)
        if name == 'portals_search_attempts' then
            return '3'
        end
        if name == 'portals_y_offset' then
            return '30750'
        end
        return nil
    end
    core.find_nodes_in_area_under_air = function()
        return {}
    end
    core.emerge_area = function(a, b, f)
        sampled[#sampled + 1] = key(a) .. ':' .. key(b)
        f(a, 4, 0)
    end
    dofile(root .. 'init.lua')
    callbacks.place(origin, {
        name = 'default:obsidian',
    }, player)
    assert(#sampled == 3, 'wrong number of deterministic attempts')
    return table.concat(sampled, ';')
end
local math_random = math.random
math.random = function()
    error('portal used shared random state')
end
local first = regions({
    x = 0,
    y = 0,
    z = 0,
})
assert(first == regions({
    x = 0,
    y = 0,
    z = 0,
}), 'same frame changed search sequence')
for _, axis in ipairs({'x', 'y', 'z'}) do
    local origin = {
        x = 0,
        y = 0,
        z = 0,
    }
    origin[axis] = 16
    assert(first ~= regions(origin), 'coordinate axis did not influence search: ' .. axis)
end
math.random = math_random
print('PASS: repeatable region sequences, all coordinate axes, isolated random state')

-- Pair history survives broken openings and a reload of the mod.
persist_pairs = true
nodes, metas = {}, {}
frame()
for x = 20, 23 do
    for z = 19, 21 do
        for y = -30901, -30900 do
            nodes[key({
                x = x,
                y = y,
                z = z,
            })] = {
                name = 'default:stone',
            }
        end
    end
end
core.settings.get = function(_, name)
    if name == 'portals_search_attempts' then
        return '1'
    end
    if name == 'portals_y_offset' then
        return '30750'
    end
    return nil
end
core.find_nodes_in_area_under_air = function()
    return {dest}
end
core.emerge_area = function(a, b, f)
    f(a, 4, 0)
end
core.is_protected = function()
    return false
end
dofile(root .. 'init.lua')
callbacks.place({
    x = 0,
    y = 0,
    z = 0,
}, {
    name = 'default:obsidian',
}, player)
local original_target = core.get_meta({
    x = 1,
    y = 1,
    z = 0,
}):get_string('target')
assert(original_target ~= '', 'initial pair missing')
-- Mimic old portals without pair records: surviving metadata must migrate.
saved_pairs = {}
callbacks.lbm({
    x = 21,
    y = -30898,
    z = 20,
})
assert(saved_pairs['pair:0:0,0,0'] == original_target, 'old pair did not migrate')
core.remove_node({
    x = 0,
    y = 2,
    z = 0,
})
callbacks.abm({
    x = 1,
    y = 1,
    z = 0,
})
callbacks.abm({
    x = 21,
    y = -30898,
    z = 20,
})
assert(core.get_node({
    x = 21,
    y = -30898,
    z = 20,
}).name == 'air', 'remote opening not extinguished')
frame()
dofile(root .. 'init.lua')
core.find_nodes_in_area_under_air = function()
    error('reconnection searched for a new cave')
end
callbacks.place({
    x = 0,
    y = 0,
    z = 0,
}, {
    name = 'default:obsidian',
}, player)
assert(core.get_meta({
    x = 1,
    y = 1,
    z = 0,
}):get_string('target') == original_target, 'rebuilt frame changed target')
assert(core.get_node({
    x = 21,
    y = -30898,
    z = 20,
}).name == 'portals:portal_up', 'remote frame not relit')
assert(messages[#messages]:find('reconnected'), 'missing reconnection report')
-- The old target must still respect the rebuilding player's protection rights.
core.remove_node({
    x = 0,
    y = 2,
    z = 0,
})
callbacks.abm({
    x = 1,
    y = 1,
    z = 0,
})
callbacks.abm({
    x = 21,
    y = -30898,
    z = 20,
})
frame()
core.is_protected = function(p)
    return p.y < -10000
end
dofile(root .. 'init.lua')
callbacks.place({
    x = 0,
    y = 0,
    z = 0,
}, {
    name = 'default:obsidian',
}, player)
assert(messages[#messages]:find('previous portal is protected'), 'protected old frame was reused')
assert(core.get_node({
    x = 1,
    y = 1,
    z = 0,
}).name == 'air', 'protected reconnection lit source')
-- An old frame that has been dismantled must not be rebuilt over new nodes.
core.is_protected = function()
    return false
end
core.remove_node({
    x = 20,
    y = -30897,
    z = 20,
})
core.find_nodes_in_area_under_air = function()
    return {}
end
dofile(root .. 'init.lua')
callbacks.place({
    x = 0,
    y = 0,
    z = 0,
}, {
    name = 'default:obsidian',
}, player)
assert(messages[#messages]:find('no safe'), 'broken old frame did not fall back to search')
assert(core.get_node({
    x = 20,
    y = -30897,
    z = 20,
}).name == 'air', 'old frame was overwritten')
print('PASS: persistent reconnection, old metadata migration, remote protection and invalid frame fallback')

-- Recover a pre-update inactive cave frame with no surviving metadata/history.
nodes, metas, saved_pairs = {}, {}, {}
frame()
local old = {
    x = 20,
    y = -30899,
    z = 20,
}
for u = 0, 3 do
    for v = 0, 4 do
        nodes[key(vector.offset(old, u, v, 0))] = {
            name = (u == 0 or u == 3 or v == 0 or v == 4) and 'default:obsidian' or 'air',
        }
    end
end
core.find_nodes_in_area = function()
    return {old}
end
core.find_nodes_in_area_under_air = function()
    error('existing old frame was not found')
end
dofile(root .. 'init.lua')
callbacks.place({
    x = 0,
    y = 0,
    z = 0,
}, {
    name = 'default:obsidian',
}, player)
assert(core.get_meta({
    x = 1,
    y = 1,
    z = 0,
}):get_string('target') == key(old), 'old frame not reused')
assert(messages[#messages]:find('existing frame'), 'missing old frame recovery report')
print('PASS: inactive legacy frame recovery without pair records')

-- Default destinations are relative to source Y, not a fixed deep band.
persist_pairs = false
core.find_nodes_in_area = function()
    return {}
end
core.find_nodes_in_area_under_air = function()
    return {}
end
local function relative_range(source_y, extra, source_x, axis)
    nodes, metas = {}, {}
    local origin = {
        x = source_x or 0,
        y = source_y,
        z = 0,
    }
    axis = axis or 0
    for u = 0, 3 do
        for v = 0, 4 do
            nodes[key(vector.offset(origin, axis == 0 and u or 0, v, axis == 1 and u or 0))] = {
                name = (u == 0 or u == 3 or v == 0 or v == 4) and 'default:obsidian' or 'air',
            }
        end
    end
    core.settings.get = function(_, name)
        if name == 'portals_search_attempts' then
            return '1'
        end
        if extra and extra[name] then
            return extra[name]
        end
        if name == 'portals_y_offset' then
            return '30000'
        end
        return nil
    end
    local range
    core.emerge_area = function(a, b, f)
        range = {
            a = a,
            b = b,
        };
        f(a, 4, 0)
    end
    dofile(root .. 'init.lua')
    callbacks.place(origin, {
        name = 'default:obsidian',
    }, player)
    return range
end
for _, y in ipairs({0, 1000, -900}) do
    local range = assert(relative_range(y))
    assert(range.a.y >= math.max(-30992, y - 30252), 'search too low for source')
    assert(range.b.y <= math.min(30992, y - 29745), 'search too high for source')
end
assert(not relative_range(-2000), 'out-of-world target was silently moved to boundary')
assert(messages[#messages]:find('outside the world Y limits'), 'missing depth limit feedback')
local range = assert(relative_range(1000, {
    portals_y_offset = '10000',
    portals_y_radius = '100',
}))
assert(range.a.y >= -9102 and range.b.y <= -8895, 'custom relative offset/radius ignored')
print('PASS: relative default depth, source elevation, configurable offset/radius and world limits')

-- Newly generated lower frames use obsidian blocks; source materials survive.
persist_pairs = true
saved_pairs, nodes, metas = {}, {}, {}
frame()
for x = 20, 23 do
    for z = 19, 21 do
        for y = -30901, -30900 do
            nodes[key({
                x = x,
                y = y,
                z = z,
            })] = {
                name = 'default:stone',
            }
        end
    end
end
core.settings.get = function(_, name)
    if name == 'portals_search_attempts' then
        return '1'
    end
    if name == 'portals_y_offset' then
        return '30750'
    end
    return nil
end
core.find_nodes_in_area = function()
    return {}
end
core.find_nodes_in_area_under_air = function()
    return {dest}
end
core.emerge_area = function(a, b, f)
    f(a, 4, 0)
end
dofile(root .. 'init.lua')
callbacks.place({
    x = 0,
    y = 0,
    z = 0,
}, {
    name = 'default:obsidian',
}, player)
for u = 0, 3 do
    for v = 0, 4 do
        if u == 0 or u == 3 or v == 0 or v == 4 then
            assert(core.get_node({
                x = u,
                y = v,
                z = 0,
            }).name == 'default:obsidian', 'source frame material changed')
            assert(core.get_node({
                x = 20 + u,
                y = -30899 + v,
                z = 20,
            }).name == 'default:obsidian_block', 'lower frame material incorrect')
        end
    end
end
-- Replacing a lower frame block must reconnect the saved pair in reverse.
local repaired = {
    x = 20,
    y = -30897,
    z = 20,
}
core.remove_node(repaired)
callbacks.abm({
    x = 21,
    y = -30898,
    z = 20,
})
callbacks.abm({
    x = 1,
    y = 1,
    z = 0,
})
core.set_node(repaired, {
    name = 'default:obsidian_block',
})
core.find_nodes_in_area_under_air = function()
    error('lower repair started a new cave search')
end
callbacks.place(repaired, {
    name = 'default:obsidian_block',
}, player)
assert(core.get_node({
    x = 1,
    y = 1,
    z = 0,
}).name == 'portals:portal', 'lower repair did not relight source')
assert(core.get_node({
    x = 21,
    y = -30898,
    z = 20,
}).name == 'portals:portal_up', 'lower repair did not relight destination')
assert(core.get_node(repaired).name == 'default:obsidian_block', 'repair material changed')
print('PASS: generated obsidian-block lower frame, preserved source and lower frame reconnection')

-- An unpaired obsidian-block frame searches upward and builds obsidian above.
persist_pairs = false
nodes, metas = {}, {}
core.registered_nodes['default:dirt_with_grass'] = {
    walkable = true,
}
local low = {
    x = 0,
    y = -30000,
    z = 0,
}
for u = 0, 3 do
    for v = 0, 4 do
        nodes[key(vector.offset(low, u, v, 0))] = {
            name = (u == 0 or u == 3 or v == 0 or v == 4) and 'default:obsidian_block' or 'air',
        }
    end
end
local upper_floor = {
    x = 20,
    y = 0,
    z = 20,
}
for x = 20, 23 do
    for z = 19, 21 do
        nodes[key({
            x = x,
            y = 0,
            z = z,
        })] = {
            name = 'default:dirt_with_grass',
        }
    end
end
core.settings.get = function(_, name)
    if name == 'portals_search_attempts' then
        return '1'
    end
    if name == 'portals_y_offset' then
        return '30000'
    end
    return nil
end
core.find_nodes_in_area = function()
    return {}
end
core.find_nodes_in_area_under_air = function(_, _, names)
    local soil = false
    for _, name in ipairs(names) do
        if name == 'default:dirt_with_grass' then
            soil = true
        end
    end
    assert(soil, 'upward search excluded safe soil surfaces')
    return {upper_floor}
end
core.emerge_area = function(a, b, f)
    assert(a.y >= -252 and b.y <= 255, 'obsidian-block frame did not search 30000 upward')
    f(a, 4, 0)
end
dofile(root .. 'init.lua')
callbacks.place(low, {
    name = 'default:obsidian_block',
}, player)
assert(core.get_node({
    x = 21,
    y = 2,
    z = 20,
}).name == 'portals:portal', 'upper portal not lit')
assert(core.get_node({
    x = 21,
    y = 1,
    z = 20,
}).name == 'default:obsidian', 'upper frame was not obsidian')
assert(core.get_node({
    x = 0,
    y = -30000,
    z = 0,
}).name == 'default:obsidian_block', 'lower source material changed')
assert(core.get_meta({
    x = 1,
    y = -29999,
    z = 0,
}):get_string('target') == key({
    x = 20,
    y = 1,
    z = 20,
}), 'upward link target wrong')
print('PASS: obsidian-block upward search, safe soil footing and obsidian upper destination')

assert(core.get_node({
    x = 1,
    y = -29999,
    z = 0,
}).name == 'portals:portal_up', 'upward source tint missing')
assert(core.get_node({
    x = 21,
    y = 2,
    z = 20,
}).name == 'portals:portal', 'downward source tint changed')
assert(core.registered_nodes['portals:portal_up'].tiles[1] ~= core.registered_nodes['portals:portal'].tiles[1],
    'portal tints are identical')
-- Old upward surfaces change color without losing their link or orientation.
local old_cell = {
    x = 1,
    y = -29999,
    z = 0,
}
local old_target = core.get_meta(old_cell):get_string('target')
core.swap_node(old_cell, {
    name = 'portals:portal',
    param2 = 0,
})
objects = {}
callbacks.abm(old_cell)
assert(core.get_node(old_cell).name == 'portals:portal_up', 'legacy surface was not recolored')
assert(core.get_meta(old_cell):get_string('target') == old_target, 'recoloring lost link metadata')
print('PASS: distinct directional tints and legacy recoloring with preserved metadata')

-- Large worlds use mapgen_limit, including positions and settings beyond 31000.
core.find_nodes_in_area_under_air = function()
    return {}
end
mapgen_limit = 100000
local high = assert(relative_range(90000, nil, 90000))
assert(high.a.y >= 59748 and high.b.y <= 60255, 'large-world downward target clipped')
assert(high.a.x > 79800, 'large-world X coordinate clipped')
local deep = assert(relative_range(-50000))
assert(deep.a.y >= -80252 and deep.b.y <= -79745, 'large-world deep target clipped')
local far = assert(relative_range(90000, {
    portals_y_offset = '150000',
}))
assert(far.a.y >= -60252 and far.b.y <= -59745, 'offset retained old 62000 cap')
local rng = PcgRandom
PcgRandom = function()
    return {
        next = function(_, low)
            return low
        end,
    }
end
local wide = assert(relative_range(90000, {
    portals_y_radius = '40000',
}))
assert(wide.a.y == 19998, 'vertical radius retained old 31000 cap')
PcgRandom = rng
assert(not relative_range(-71000), 'configured large-world boundary ignored')
mapgen_limit = 31000
print('PASS: configured mapgen_limit only, large X/Y coordinates, large offset/radius and boundary rejection')

-- Frame direction chooses the normal axis; coordinates choose its sign.
local original_rng = PcgRandom
for axis = 0, 1 do
    for sign = 0, 1 do
        PcgRandom = function()
            return {
                next = function(_, lo, hi)
                    if lo == 0 and hi == 1 then
                        return sign
                    end
                    if lo < 0 and hi == -lo then
                        return 0
                    end
                    return lo
                end,
            }
        end
        local region = assert(relative_range(0, nil, nil, axis))
        local offset = sign == 0 and -10000 or 10000
        assert(region.a.x + 10 == (axis == 1 and offset or 0), 'wrong X offset for frame orientation')
        assert(region.a.z + 10 == (axis == 0 and offset or 0), 'wrong Z offset for frame orientation')
    end
end
PcgRandom = function()
    return {
        next = function(_, lo, hi)
            if lo == 0 and hi == 1 then
                return 1
            end
            if lo < 0 and hi == -lo then
                return 0
            end
            return lo
        end,
    }
end
local edge = assert(relative_range(0, nil, 30000, 1))
assert(edge.a.x + 10 == 20000, 'out-of-bounds horizontal offset did not reverse')
for axis = 0, 1 do
    local disabled = assert(relative_range(0, {
        portals_xz_offset = '0',
    }, nil, axis))
    assert(disabled.a.x + 10 == 0 and disabled.a.z + 10 == 0, 'horizontal offset could not be disabled')
end
PcgRandom = original_rng
print('PASS: frame-normal X/Z offsets, both signs, world-edge reversal and disabled offset')

core.registered_nodes['test:water'] = {
    liquidtype = 'source',
    walkable = false,
}
core.registered_nodes['test:flow'] = {
    liquidtype = 'flowing',
    walkable = false,
}
core.registered_nodes['test:lava'] = {
    liquidtype = 'source',
    walkable = false,
    damage_per_second = 8,
}
local function liquid_pair(axis, enabled)
    nodes, metas = {}, {}
    objects = {}
    core.is_protected = function()
        return false
    end
    core.settings.get_bool = function(_, name, fallback)
        if name == 'portals_transfer_liquids' and enabled ~= nil then
            return enabled
        end
        return fallback
    end
    dofile(root .. 'init.lua')
    local a, b = {
        x = 0,
        y = 0,
        z = 0,
    }, {
        x = 100,
        y = -100,
        z = 100,
    }
    local function at(p, u, v, d)
        return vector.offset(p, axis == 0 and u or d, v, axis == 1 and u or d)
    end
    for _, pair in ipairs({{a, b, 'default:obsidian', 'portals:portal'},
                           {b, a, 'default:obsidian_block', 'portals:portal_up'}}) do
        for u = 0, 3 do
            for v = 0, 4 do
                local edge = u == 0 or u == 3 or v == 0 or v == 4
                local q = at(pair[1], u, v, 0)
                core.set_node(q, {
                    name = edge and pair[3] or pair[4],
                    param2 = axis,
                })
                if not edge then
                    local meta = core.get_meta(q)
                    meta:set_string('origin', key(pair[1]));
                    meta:set_int('axis', axis)
                    meta:set_string('target', key(pair[2]));
                    meta:set_string('owner', 'builder')
                end
            end
        end
        callbacks.lbm(at(pair[1], 1, 1, 0))
    end
    return a, b, at
end
for axis = 0, 1 do
    for _, side in ipairs({-1, 1}) do
        for _, liquid in ipairs({'test:water', 'test:flow', 'test:lava'}) do
            local a, b, at = liquid_pair(axis)
            local source, dest = at(a, 1, 2, side), at(b, 1, 1, -side)
            core.set_node(source, {
                name = liquid,
                param1 = 10,
                param2 = 7,
            })
            callbacks.step(0.1)
            assert(core.get_node(source).name == 'air', 'liquid source was duplicated')
            local moved = core.get_node(dest)
            assert(moved.name == liquid and moved.param2 == 7 and moved.param1 == 10, 'liquid state or position changed')
            assert(core.get_node(at(a, 1, 0, side)).name == 'air', 'liquid immediately bounced back')
        end
    end
end
local a, b, at = liquid_pair(0)
local source, dest = at(a, 1, 2, 1), at(b, 1, 1, -1)
core.set_node(source, {
    name = 'test:water',
})
core.set_node(dest, {
    name = 'default:stone',
})
callbacks.step(0.1)
assert(core.get_node(source).name == 'test:water' and core.get_node(dest).name == 'default:stone',
    'blocked target overwritten')
core.remove_node(dest)
for _, blocked in ipairs({source, dest}) do
    core.is_protected = function(p)
        return key(p) == key(blocked)
    end
    callbacks.step(0.1)
    assert(core.get_node(source).name == 'test:water' and core.get_node(dest).name == 'air',
        'protected liquid was moved')
end
core.is_protected = function()
    return false
end
local get_node = core.get_node_or_nil
core.get_node_or_nil = function(p)
    if key(p) == key(dest) then
        return nil
    end
    return get_node(p)
end
callbacks.step(0.1)
assert(core.get_node(source).name == 'test:water', 'liquid moved into unloaded target')
core.get_node_or_nil = get_node
local set_node = core.swap_node
core.swap_node = function(p, n)
    if key(p) == key(dest) then
        return false
    end
    return set_node(p, n)
end
callbacks.step(0.1)
assert(core.get_node(source).name == 'test:water', 'failed placement removed liquid source')
core.swap_node = set_node
local remove_node = core.swap_node
core.swap_node = function(p, n)
    if key(p) == key(source) then
        return false
    end
    return remove_node(p, n)
end
callbacks.step(0.1)
assert(core.get_node(source).name == 'test:water' and core.get_node(dest).name == 'air',
    'failed removal duplicated liquid')
core.swap_node = remove_node
local a, b, at = liquid_pair(1, false)
source, dest = at(a, 1, 2, 1), at(b, 1, 1, -1)
core.set_node(source, {
    name = 'test:water',
})
callbacks.step(0.1)
assert(core.get_node(source).name == 'test:water' and core.get_node(dest).name == 'air',
    'disabled liquid transfer still ran')
-- A lower portal transfers liquids upward as well, still one cell lower at exit.
local a, b, at = liquid_pair(1)
source, dest = at(b, 2, 3, -1), at(a, 2, 2, 1)
core.set_node(source, {
    name = 'test:flow',
    param2 = 3,
})
callbacks.step(0.1)
assert(core.get_node(source).name == 'air' and core.get_node(dest).name == 'test:flow', 'reverse transfer failed')
print(
    'PASS: liquid transfer, both axes/faces/directions, state preservation, air-only destinations, protection, failed writes, cooldown and disable setting')

-- Move rich node state, including inventory stack data, widths and private flags.
local a, b, at = liquid_pair(0)
source, dest = at(a, 1, 2, 1), at(b, 1, 1, -1)
core.set_node(source, {
    name = 'test:flow',
    param1 = 8,
    param2 = 5,
})
local rich = {
    fields = {
        owner = 'builder',
        secret = 'private value',
        infotext = 'Custom liquid',
    },
    inventory = {
        main = {{
            name = 'default:stone',
            count = 23,
            wear = 120,
            metadata = {
                label = 'saved stack',
            },
        }, ''},
    },
    private_fields = {'secret'},
    inventory_widths = {
        main = 2,
    },
}
core.get_meta(source):from_table(rich)
core.get_node_timer(source):set(12.5, 3.25)
core.get_meta(dest):from_table({
    fields = {
        old = 'air metadata',
    },
})
core.get_node_timer(dest):set(99, 20)
callbacks.step(0.1)
local moved = core.get_meta(dest):to_table()
assert(moved.fields.secret == 'private value' and moved.fields.old == nil, 'metadata not replaced')
assert(moved.private_fields[1] == 'secret', 'private flags lost')
assert(moved.inventory_widths.main == 2, 'inventory width lost')
assert(moved.inventory.main[1].count == 23 and moved.inventory.main[1].metadata.label == 'saved stack',
    'inventory stack data lost')
assert(core.get_node_timer(dest):get_timeout() == 12.5 and core.get_node_timer(dest):get_elapsed() == 3.25,
    'timer state lost')
assert(next(core.get_meta(source):to_table().fields) == nil, 'source metadata not cleared')
assert(not core.get_node_timer(source):is_started(), 'source timer not stopped')
-- Metadata restore failures roll back the destination and leave source intact.
local a, b, at = liquid_pair(0)
source, dest = at(a, 1, 2, 1), at(b, 1, 1, -1)
core.set_node(source, {
    name = 'test:water',
})
core.get_meta(source):from_table(rich)
core.get_meta(dest):from_table({
    fields = {
        old = 'preserve',
    },
})
core.get_node_timer(dest):set(10, 2)
local get_meta = core.get_meta
local fail_once = true
core.get_meta = function(p)
    local meta = get_meta(p)
    if key(p) == key(dest) and fail_once then
        meta.from_table = function()
            fail_once = false;
            return false
        end
    end
    return meta
end
callbacks.step(0.1)
core.get_meta = get_meta
assert(core.get_node(source).name == 'test:water' and core.get_meta(source):get_string('secret') == 'private value',
    'failed move altered source')
assert(core.get_node(dest).name == 'air' and core.get_meta(dest):get_string('old') == 'preserve',
    'failed move did not restore target')
assert(core.get_node_timer(dest):get_timeout() == 10 and core.get_node_timer(dest):get_elapsed() == 2,
    'rollback lost destination timer')
-- Source cleanup failure restores both endpoints, including their metadata.
core.get_node_timer(source):set(12.5, 3.25)
fail_once = true
core.get_meta = function(p)
    local meta = get_meta(p)
    if key(p) == key(source) then
        local from = meta.from_table
        meta.from_table = function(self, data)
            if data == nil and fail_once then
                fail_once = false;
                return false
            end
            return from(self, data)
        end
    end
    return meta
end
callbacks.step(0.1)
core.get_meta = get_meta
assert(core.get_node(source).name == 'test:water' and core.get_meta(source):get_string('secret') == 'private value',
    'cleanup failure lost source')
assert(core.get_node_timer(source):get_elapsed() == 3.25, 'cleanup rollback lost timer')
assert(core.get_node(dest).name == 'air' and core.get_meta(dest):get_string('old') == 'preserve',
    'cleanup rollback left duplicate')
print('PASS: rich metadata, inventory stack data and widths, privacy, timers, metadata failure and cleanup rollback')
