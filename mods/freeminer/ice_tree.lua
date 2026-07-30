-- A tree made entirely from ice and snow. Growth is procedural so the ice
-- trunk can retain correct transparent lighting without using param1 as the
-- water storage employed by the generic tree-growth ABM.

local trunk_name = "plant_ice:ice_tree"
local leaves_name = "plant_ice:ice_tree_snow"
local root_name = "plant_ice:ice_tree_root"
local sapling_name = "plant_ice:ice_tree_sapling"

local frozen_substrates = {
    ["default:snow"] = true,
    ["default:snowblock"] = true,
    ["default:ice"] = true,
    ["default:cave_ice"] = true,
}

minetest.register_node(":" .. root_name, {
    description = "Ice Tree Root",
    tiles = {
        "default_snow.png",
        "default_ice.png",
        "default_ice.png",
    },
    paramtype = "light",
    sunlight_propagates = true,
    is_ground_content = false,
    drop = "default:ice",
    groups = {
        cracky = 3,
        slippery = 3,
        cools_lava = 1,
        snowy = 1,
        melt = 2,
    },
    sounds = default.node_sound_ice_defaults(),
    melt = "default:water_source",
})

minetest.register_node(":" .. trunk_name, {
    description = "Ice Tree",
    drawtype = "glasslike",
    tiles = {"default_ice.png"},
    paramtype = "light",
    sunlight_propagates = true,
    use_texture_alpha = true,
    is_ground_content = false,
    drop = "default:ice",
    groups = {
        tree = 1,
        cracky = 3,
        slippery = 3,
        cools_lava = 1,
        melt = 2,
    },
    sounds = default.node_sound_ice_defaults(),
    melt = "default:water_source",
})

minetest.register_node(":" .. leaves_name, {
    description = "Ice Tree Snow",
    drawtype = "allfaces_optional",
    waving = 1,
    tiles = {"default_snow.png"},
    paramtype = "light",
    sunlight_propagates = true,
    walkable = false,
    is_ground_content = false,
    drop = "default:snow",
    groups = {
        leaves = 1,
        crumbly = 3,
        snowy = 1,
        melt = 1,
        fall_damage_add_percent = -70,
    },
    sounds = default.node_sound_snow_defaults(),
    melt = "default:water_flowing",
})

local function offset(pos, x, y, z)
    return {
        x = pos.x + (x or 0),
        y = pos.y + (y or 0),
        z = pos.z + (z or 0),
    }
end

local function climate_allows_growth(pos)
    local heat = core.get_heat and core.get_heat(pos) or 100
    if heat > -1 or heat < -100 then
        return false
    end

    local light = minetest.get_node_light(pos, 0.5) or 0
    if light < 6 then
        return false
    end

    local humidity = core.get_humidity and core.get_humidity(pos) or 0
    return humidity >= 35 or
        minetest.find_node_near(pos, 2, {"group:water"}) ~= nil
end

local function position_key(pos)
    return pos.x .. ":" .. pos.y .. ":" .. pos.z
end

local function plan_ice_tree(pos)
    local plan = {}

    local function add(target, name)
        plan[position_key(target)] = {
            pos = target,
            name = name,
        }
    end

    local function add_snow_cluster(center, radius)
        for x = -radius, radius do
            for y = -radius, radius do
                for z = -radius, radius do
                    local distance = math.abs(x) + math.abs(y) + math.abs(z)
                    if distance <= radius + 1 and
                            (distance <= radius or math.random(3) ~= 1) then
                        local target = offset(center, x, y, z)
                        local key = position_key(target)
                        if not plan[key] then
                            add(target, leaves_name)
                        end
                    end
                end
            end
        end
    end

    local height = math.random(7, 12)
    add(offset(pos, 0, -1, 0), root_name)

    for y = 0, height - 1 do
        add(offset(pos, 0, y, 0), trunk_name)
    end

    local directions = {
        {x = 1, z = 0},
        {x = -1, z = 0},
        {x = 0, z = 1},
        {x = 0, z = -1},
    }

    for index, direction in ipairs(directions) do
        if math.random(4) ~= 1 then
            local branch_y = height - 5 + ((index + math.random(0, 1)) % 3)
            local length = math.random(2, 4)
            local tip
            for distance = 1, length do
                local rise = distance == length and math.random(0, 1) or 0
                tip = offset(pos, direction.x * distance,
                    branch_y + rise, direction.z * distance)
                add(tip, trunk_name)
            end
            add_snow_cluster(tip, math.random(1, 2))
        end
    end

    add_snow_cluster(offset(pos, 0, height - 1, 0), 2)
    add(offset(pos, 0, height, 0), leaves_name)

    return plan
end

local function can_replace_with_tree(pos)
    local node = minetest.get_node_or_nil(pos)
    if not node or node.name == "ignore" then
        return false
    end
    if node.name == sapling_name or node.name == leaves_name then
        return true
    end
    local definition = minetest.registered_nodes[node.name]
    return definition and definition.buildable_to
end

local function grow_ice_tree(pos)
    if not climate_allows_growth(pos) then
        return false
    end

    local below = minetest.get_node_or_nil(offset(pos, 0, -1, 0))
    if not below or
            (not frozen_substrates[below.name] and below.name ~= root_name) then
        return false
    end

    if minetest.is_area_protected(offset(pos, -6, -1, -6),
            offset(pos, 6, 13, 6), "", 2) then
        return false
    end

    local plan = plan_ice_tree(pos)
    for _, placement in pairs(plan) do
        if placement.pos.y == pos.y - 1 then
            if placement.name ~= root_name then
                return false
            end
        elseif not can_replace_with_tree(placement.pos) then
            return false
        end
    end

    for _, placement in pairs(plan) do
        minetest.set_node(placement.pos, {name = placement.name})
    end
    return true
end

local function start_sapling_timer(pos)
    minetest.get_node_timer(pos):start(math.random(300, 900))
end

minetest.register_node(":" .. sapling_name, {
    description = "Ice Tree Crystal",
    drawtype = "plantlike",
    waving = 1,
    visual_scale = 0.75,
    tiles = {
        "default_mese_crystal.png^[colorize:#BDEEFF:190",
    },
    inventory_image =
        "default_mese_crystal.png^[colorize:#BDEEFF:190",
    wield_image =
        "default_mese_crystal.png^[colorize:#BDEEFF:190",
    paramtype = "light",
    sunlight_propagates = true,
    walkable = false,
    buildable_to = true,
    is_ground_content = false,
    drop = "default:ice",
    selection_box = {
        type = "fixed",
        fixed = {-3 / 16, -0.5, -3 / 16, 3 / 16, 3 / 16, 3 / 16},
    },
    groups = {
        snappy = 3,
        attached_node = 1,
        sapling = 1,
        melt = 1,
    },
    sounds = default.node_sound_ice_defaults(),
    melt = "default:water_flowing",

    on_construct = start_sapling_timer,

    on_timer = function(pos)
        if not grow_ice_tree(pos) then
            start_sapling_timer(pos)
        end
        return false
    end,

    on_place = function(itemstack, placer, pointed_thing)
        if pointed_thing.type ~= "node" then
            return itemstack
        end

        local ground_pos = pointed_thing.under
        local ground = minetest.get_node_or_nil(ground_pos)
        if not ground or not frozen_substrates[ground.name] then
            return itemstack
        end

        local pos = pointed_thing.above
        local target = minetest.get_node_or_nil(pos)
        local target_def = target and minetest.registered_nodes[target.name]
        if not target_def or not target_def.buildable_to then
            return itemstack
        end

        local player_name = placer and placer:get_player_name() or ""
        if minetest.is_area_protected(offset(pos, -6, -1, -6),
                offset(pos, 6, 13, 6), player_name, 2) then
            minetest.record_protection_violation(pos, player_name)
            return itemstack
        end

        minetest.set_node(pos, {name = sapling_name})
        if not minetest.is_creative_enabled(player_name) then
            itemstack:take_item()
        end
        return itemstack
    end,
})

-- Keep ice trees placed by older versions usable after the namespace change.
minetest.register_alias("freeminer:ice_tree", trunk_name)
minetest.register_alias("freeminer:ice_tree_snow", leaves_name)
minetest.register_alias("freeminer:ice_tree_root", root_name)
minetest.register_alias("freeminer:ice_tree_sapling", sapling_name)

default.register_leafdecay({
    trunks = {trunk_name},
    leaves = {leaves_name},
    radius = 4,
})

-- Populate cold snowy regions without modifying ordinary snow or ice nodes.
minetest.register_abm({
    label = "Freeminer ice tree crystal seeding",
    nodenames = {
        "default:snow",
        "default:snowblock",
        "default:ice",
        "default:cave_ice",
    },
    interval = 60,
    chance = 5000,
    catch_up = false,
    action = function(pos)
        local crystal_pos = offset(pos, 0, 1, 0)
        local target = minetest.get_node_or_nil(crystal_pos)
        local target_def = target and minetest.registered_nodes[target.name]
        if not target_def or not target_def.buildable_to or
                minetest.is_protected(crystal_pos, "") then
            return
        end

        local heat = core.get_heat and core.get_heat(crystal_pos) or 100
        local humidity = core.get_humidity and
            core.get_humidity(crystal_pos) or 0
        local light = minetest.get_node_light(crystal_pos, 0.5) or 0
        if heat > -8 or humidity < 35 or light < 8 then
            return
        end

        if minetest.find_node_near(crystal_pos, 12,
                {trunk_name, sapling_name}) then
            return
        end

        minetest.set_node(crystal_pos, {name = sapling_name})
    end,
})
