-- Growth and spreading for Marinara's rooted aquatic plants.
--
-- These plants cannot use the tree growth ABM: their param2 stores the
-- height of the plantlike extension, and copying the node upward would also
-- copy its sand, dirt, or rock base into the water.
-- marinara:reed is the above-water decorative form; reed_root represents the
-- rooted aquatic plant and is the form that spreads here.

local rules = {
    ["marinara:reed_root"] = {
        substrate = "default:dirt",
        initial_param2 = 0,
        water_depth_min = 1,
        light_min = 11,
        heat_min = 8,
        heat_max = 35,
        spread_radius = 2,
        spread_chance = 70,
        density_radius = 3,
        density_max = 4,
    },
    ["marinara:sand_with_kelp"] = {
        substrate = "default:sand",
        initial_param2 = 32,
        height_step = 8,
        height_max = 96,
        height_divisor = 8,
        water_depth_min = 4,
        light_min = 7,
        heat_min = -5,
        heat_max = 25,
        grow_chance = 10,
        spread_radius = 3,
        spread_chance = 50,
        density_radius = 3,
        density_max = 6,
    },
    ["marinara:sand_with_seagrass"] = {
        substrate = "default:sand",
        initial_param2 = 8,
        height_divisor = 8,
        water_depth_min = 1,
        light_min = 9,
        heat_min = 2,
        heat_max = 40,
        spread_radius = 2,
        spread_chance = 24,
        density_radius = 3,
        density_max = 12,
        density_nodes = {
            "marinara:sand_with_seagrass",
            "marinara:sand_with_seagrass2",
        },
        matures_to = "marinara:sand_with_seagrass2",
        mature_chance = 60,
        mature_density_radius = 3,
        mature_density_max = 6,
    },
    ["marinara:sand_with_seagrass2"] = {
        substrate = "default:sand",
        initial_param2 = 16,
        height_divisor = 8,
        water_depth_min = 2,
        light_min = 8,
        heat_min = 2,
        heat_max = 32,
        spread_radius = 2,
        spread_chance = 60,
        density_radius = 3,
        density_max = 6,
    },
    ["marinara:sand_with_alage"] = {
        substrate = "default:sand",
        initial_param2 = 16,
        height_divisor = 16,
        water_depth_min = 1,
        light_min = 11,
        heat_min = 10,
        heat_max = 38,
        spread_radius = 2,
        spread_chance = 16,
        density_radius = 3,
        density_max = 16,
    },
    ["marinara:coastrock_with_brownalage"] = {
        substrate = "marinara:coastrock",
        initial_param2 = 16,
        height_divisor = 8,
        water_depth_min = 2,
        light_min = 6,
        heat_min = -5,
        heat_max = 22,
        spread_radius = 2,
        spread_chance = 60,
        density_radius = 3,
        density_max = 6,
    },
    ["freeminer:pressure_lantern_kelp"] = {
        substrate = "default:stone",
        initial_param2 = 32,
        height_step = 8,
        height_max = 96,
        height_divisor = 8,
        water_depth_min = 4,
        water_direction = 1,
        y_min = -4000,
        y_max = -1000,
        light_min = 0,
        light_max = 6,
        heat_min = -20,
        heat_max = 100,
        grow_chance = 25,
        spread_radius = 3,
        spread_chance = 120,
        density_radius = 8,
        density_max = 4,
        seed_weight = 30,
    },
    ["freeminer:mese_root_fan"] = {
        substrate = "default:stone_with_mese",
        initial_param2 = 16,
        height_divisor = 8,
        water_depth_min = 2,
        water_direction = 1,
        y_min = -8000,
        y_max = -2500,
        light_min = 0,
        light_max = 8,
        heat_min = -20,
        heat_max = 120,
        required_neighbor = "default:stone_with_mese",
        neighbor_radius = 2,
        spread_radius = 2,
        spread_chance = 180,
        density_radius = 8,
        density_max = 3,
        seed_weight = 15,
    },
    ["freeminer:blackwater_bell"] = {
        substrate = "default:stone",
        initial_param2 = 1,
        water_depth_min = 1,
        water_direction = -1,
        y_min = -10000,
        y_max = -4000,
        light_min = 0,
        light_max = 7,
        heat_min = -20,
        heat_max = 140,
        spread_radius = 2,
        spread_chance = 200,
        density_radius = 8,
        density_max = 3,
        seed_weight = 15,
    },
    ["freeminer:obsidian_vent_grass"] = {
        substrate = "default:obsidian",
        initial_param2 = 16,
        height_divisor = 8,
        water_depth_min = 2,
        water_direction = 1,
        y_min = -14000,
        y_max = -7000,
        light_min = 0,
        light_max = 9,
        heat_min = 20,
        heat_max = 5000,
        required_neighbor = {"default:obsidian", "group:lava"},
        neighbor_radius = 2,
        spread_radius = 2,
        spread_chance = 150,
        density_radius = 7,
        density_max = 5,
        seed_weight = 10,
    },
    ["freeminer:hadal_glass_fern"] = {
        substrate = "default:obsidian",
        initial_param2 = 16,
        height_divisor = 8,
        water_depth_min = 2,
        water_direction = 1,
        y_min = -18000,
        y_max = -10000,
        light_min = 0,
        light_max = 5,
        heat_min = 20,
        heat_max = 160,
        spread_radius = 2,
        spread_chance = 240,
        density_radius = 9,
        density_max = 3,
        seed_weight = 10,
    },
    ["freeminer:core_vein_creeper"] = {
        substrate = "default:stone",
        initial_param2 = 16,
        height_divisor = 8,
        water_depth_min = 2,
        water_direction = 1,
        y_min = -24000,
        y_max = -14000,
        light_min = 0,
        light_max = 10,
        heat_min = 25,
        heat_max = 5000,
        required_neighbor = "group:lava",
        neighbor_radius = 3,
        spread_radius = 2,
        spread_chance = 220,
        density_radius = 9,
        density_max = 3,
        seed_weight = 6,
    },
    ["freeminer:void_star_bloom"] = {
        substrate = "default:stone_with_diamond",
        initial_param2 = 16,
        height_divisor = 8,
        water_depth_min = 2,
        water_direction = 1,
        y_min = -28000,
        y_max = -20000,
        light_min = 0,
        light_max = 11,
        heat_min = 40,
        heat_max = 250,
        required_neighbor = "default:stone_with_diamond",
        neighbor_radius = 3,
        spread_radius = 1,
        spread_chance = 400,
        density_radius = 12,
        density_max = 1,
        seed_weight = 2,
    },
    ["freeminer:bedrock_lantern"] = {
        substrate = "default:stone",
        initial_param2 = 16,
        height_divisor = 8,
        water_depth_min = 2,
        water_direction = 1,
        y_min = -31000,
        y_max = -27000,
        light_min = 0,
        light_max = 12,
        heat_min = 500,
        heat_max = 10000,
        required_neighbor = "default:mese",
        neighbor_radius = 4,
        spread_radius = 1,
        spread_chance = 800,
        density_radius = 20,
        density_max = 1,
        seed_weight = 1,
    },
}

local active_names = {}
for name in pairs(rules) do
    if minetest.registered_nodes[name] then
        active_names[#active_names + 1] = name
    end
end

-- Marinara is optional. Avoid registering an ABM with unknown trigger nodes.
if #active_names == 0 then
    return
end

local function offset(pos, x, y, z)
    return {
        x = pos.x + (x or 0),
        y = pos.y + (y or 0),
        z = pos.z + (z or 0),
    }
end

local function is_source_water(pos)
    local node = minetest.get_node_or_nil(pos)
    if not node or node.name == "ignore" then
        return nil
    end

    local def = minetest.registered_nodes[node.name]
    return def and def.liquidtype == "source" and
        minetest.get_item_group(node.name, "water") > 0
end

local function visible_height(rule, param2)
    if not rule.height_divisor then
        return rule.water_depth_min
    end
    return math.max(rule.water_depth_min,
        math.ceil(param2 / rule.height_divisor))
end

local function water_column_is_clear(pos, height, water_direction)
    water_direction = water_direction or 1
    for y = 1, height do
        local water = is_source_water(offset(pos, 0,
            water_direction * y, 0))
        if water == nil then
            return nil
        end
        if not water then
            return false
        end
    end
    return true
end

local function climate_allows(pos, rule)
    if (rule.y_min and pos.y < rule.y_min) or
            (rule.y_max and pos.y > rule.y_max) then
        return false
    end

    local water_direction = rule.water_direction or 1
    local light = minetest.get_node_light(
        offset(pos, 0, water_direction, 0), 0.5) or 0
    if light < rule.light_min then
        return false
    end
    if rule.light_max and light > rule.light_max then
        return false
    end

    if core.get_heat then
        local heat = core.get_heat(pos)
        if heat and (heat < rule.heat_min or heat > rule.heat_max) then
            return false
        end
    end

    return true
end

local function neighbor_allows(pos, rule)
    if not rule.required_neighbor then
        return true
    end
    return minetest.find_node_near(pos, rule.neighbor_radius or 1,
        rule.required_neighbor) ~= nil
end

local function habitat_allows(pos, rule, param2)
    return climate_allows(pos, rule) and neighbor_allows(pos, rule) and
        water_column_is_clear(pos, visible_height(rule, param2),
            rule.water_direction) == true
end

local function count_near(pos, names, radius)
    local minp = offset(pos, -radius, -2, -radius)
    local maxp = offset(pos, radius, 2, radius)
    return #minetest.find_nodes_in_area(minp, maxp, names)
end

local function density_allows(pos, rule)
    return count_near(pos, rule.density_nodes or {rule.name},
        rule.density_radius) < rule.density_max
end

local function try_grow_taller(pos, node, rule)
    if not rule.height_step or node.param2 >= rule.height_max or
            math.random(rule.grow_chance) ~= 1 then
        return false
    end

    local new_param2 = math.min(rule.height_max,
        node.param2 + rule.height_step)
    if water_column_is_clear(pos, visible_height(rule, new_param2),
            rule.water_direction) ~= true then
        return false
    end

    node.param2 = new_param2
    minetest.swap_node(pos, node)
    return true
end

local function try_mature(pos, rule)
    if not rule.matures_to or math.random(rule.mature_chance) ~= 1 then
        return false
    end

    local mature_rule = rules[rule.matures_to]
    if not mature_rule or
            not habitat_allows(pos, mature_rule, mature_rule.initial_param2) or
            count_near(pos, {rule.matures_to},
                rule.mature_density_radius) >= rule.mature_density_max then
        return false
    end

    minetest.swap_node(pos, {
        name = rule.matures_to,
        param2 = mature_rule.initial_param2,
    })
    return true
end

local function shuffled_candidates(pos, rule)
    local minp = offset(pos, -rule.spread_radius, -1, -rule.spread_radius)
    local maxp = offset(pos, rule.spread_radius, 1, rule.spread_radius)
    local candidates = minetest.find_nodes_in_area(minp, maxp,
        rule.substrates or {rule.substrate})

    -- A complete shuffle is unnecessary; trying a few random candidates keeps
    -- the cost bounded while still allowing growth over uneven seabeds.
    for i = #candidates, 2, -1 do
        local j = math.random(i)
        candidates[i], candidates[j] = candidates[j], candidates[i]
    end
    return candidates
end

local function try_spread(pos, rule)
    if math.random(rule.spread_chance) ~= 1 or
            not density_allows(pos, rule) then
        return false
    end

    local candidates = shuffled_candidates(pos, rule)
    for i = 1, math.min(#candidates, 8) do
        local target = candidates[i]
        if not minetest.is_protected(target, "") and
                habitat_allows(target, rule, rule.initial_param2) then
            minetest.set_node(target, {
                name = rule.name,
                param2 = rule.initial_param2,
            })
            return true
        end
    end

    return false
end

for name, rule in pairs(rules) do
    rule.name = name
end

minetest.register_abm({
    label = "Freeminer aquatic plant growth",
    nodenames = active_names,
    interval = 10,
    chance = 3,
    catch_up = false,
    action = function(pos, node)
        local rule = rules[node.name]
        if not rule or minetest.is_protected(pos, "") then
            return
        end

        local current_height = visible_height(rule, node.param2)
        local water_state = water_column_is_clear(pos, current_height,
            rule.water_direction)
        if water_state == nil then
            return
        end
        if not water_state then
            minetest.set_node(pos, {name = rule.substrate})
            return
        end

        if not climate_allows(pos, rule) then
            return
        end

        if try_grow_taller(pos, node, rule) then
            return
        end
        if try_mature(pos, rule) then
            return
        end
        try_spread(pos, rule)
    end,
})

local function substrate_allows(node_name, rule)
    if node_name == rule.substrate then
        return true
    end
    for _, substrate in ipairs(rule.substrates or {}) do
        if node_name == substrate then
            return true
        end
    end
    return false
end

-- Deep water is uncommon and normal decorations do not reliably see flooded
-- cave floors. Very occasionally turn a suitable floor or ceiling adjoining a
-- loaded source-water node into the first plant of a colony.
minetest.register_abm({
    label = "Freeminer deep aquatic plant seeding",
    nodenames = {"group:water"},
    interval = 30,
    chance = 3000,
    catch_up = false,
    action = function(pos, node)
        local node_def = minetest.registered_nodes[node.name]
        if not node_def or node_def.liquidtype ~= "source" then
            return
        end

        local eligible = {}
        local total_weight = 0
        for _, name in ipairs(active_names) do
            local rule = rules[name]
            if rule.seed_weight then
                local water_direction = rule.water_direction or 1
                local target = offset(pos, 0, -water_direction, 0)
                local target_node = minetest.get_node_or_nil(target)
                if target_node and target_node.name ~= "ignore" and
                        substrate_allows(target_node.name, rule) and
                        not minetest.is_protected(target, "") and
                        habitat_allows(target, rule,
                            rule.initial_param2) and
                        density_allows(target, rule) then
                    total_weight = total_weight + rule.seed_weight
                    eligible[#eligible + 1] = {
                        name = name,
                        pos = target,
                        weight = rule.seed_weight,
                    }
                end
            end
        end

        if total_weight == 0 then
            return
        end

        local roll = math.random(total_weight)
        for _, seed in ipairs(eligible) do
            roll = roll - seed.weight
            if roll <= 0 then
                local rule = rules[seed.name]
                minetest.set_node(seed.pos, {
                    name = seed.name,
                    param2 = rule.initial_param2,
                })
                return
            end
        end
    end,
})

-- Marinara's original placement callback checks for sand even though brown
-- algae has a coast-rock base. Override it here so the item and natural growth
-- obey the same substrate and water-depth rules.
local brown_name = "marinara:coastrock_with_brownalage"
local brown_rule = rules[brown_name]
if minetest.registered_nodes[brown_name] then
    minetest.override_item(brown_name, {
        on_place = function(itemstack, placer, pointed_thing)
            if pointed_thing.type ~= "node" then
                return itemstack
            end

            if placer and not placer:get_player_control().sneak then
                local pointed_node = minetest.get_node(pointed_thing.under)
                local pointed_def = minetest.registered_nodes[pointed_node.name]
                if pointed_def and pointed_def.on_rightclick then
                    return pointed_def.on_rightclick(pointed_thing.under,
                        pointed_node, placer, itemstack, pointed_thing)
                end
            end

            local pos = pointed_thing.under
            if minetest.get_node(pos).name ~= brown_rule.substrate or
                    water_column_is_clear(pos,
                        visible_height(brown_rule,
                            brown_rule.initial_param2),
                        brown_rule.water_direction) ~= true then
                return itemstack
            end

            local player_name = placer and placer:get_player_name() or ""
            if minetest.is_protected(pos, player_name) then
                minetest.record_protection_violation(pos, player_name)
                return itemstack
            end

            minetest.set_node(pos, {
                name = brown_name,
                param2 = brown_rule.initial_param2,
            })
            if not minetest.is_creative_enabled(player_name) then
                itemstack:take_item()
            end
            return itemstack
        end,
    })
end
