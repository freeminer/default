-- Deep mineral trees sustained by lava. Living nodes are custom and hot, but
-- cooling and digging yield only ordinary stone or obsidian.

local root_name = "plant_lava:lava_tree_root"
local bud_name = "plant_lava:lava_tree_bud"
local trunk_name = "plant_lava:lava_tree"
local crown_name = "plant_lava:lava_tree_crown"

local root_substrates = {
    ["default:stone"] = true,
    ["default:obsidian"] = true,
}

local lava_search_radius = 1
local growth_heat_min = 80
local freeze_heat_max = 40

minetest.register_node(":" .. root_name, {
    description = "Lava Tree Root",
    tiles = {
        "default_obsidian.png^[colorize:#FF4A18:70",
        "default_obsidian.png",
        "default_obsidian.png^[colorize:#FF3010:45",
    },
    paramtype = "light",
    light_source = 4,
    is_ground_content = false,
    drop = "default:obsidian",
    freeze = "default:obsidian",
    groups = {
        cracky = 2,
        freeze = freeze_heat_max,
        hot = 300,
        igniter = 1,
        lava_tree_live = 1,
        soil = 1,
        wield_light = 3,
    },
    sounds = default.node_sound_stone_defaults(),
})

minetest.register_node(":" .. trunk_name, {
    description = "Lava Tree",
    tiles = {
        "default_obsidian.png^[colorize:#FF5A20:80",
        "default_obsidian.png^[colorize:#FF5A20:80",
        "default_obsidian.png^[colorize:#FF3010:50",
    },
    paramtype = "light",
    light_source = 4,
    is_ground_content = false,
    drop = "default:obsidian",
    freeze = "default:obsidian",
    liquid_alternative_source = crown_name,
    groups = {
        tree = 1,
        cracky = 2,
        freeze = freeze_heat_max,
        grow_tree = 1,
        hot = 250,
        igniter = 1,
        lava_tree_live = 1,
        leaves_die_from_liquid = 0,
        leaves_die_heat_max = 0,
        leaves_die_heat_min = 0,
        leaves_grow_heat_max = 0,
        leaves_grow_heat_min = growth_heat_min,
        leaves_grow_light_min = 0,
        leaves_water_max = 40,
        tree_branch_chance = 0,
        tree_get_water_from_humidity = 0,
        tree_get_water_max_from_humidity = 0,
        tree_grow_bottom = 0,
        tree_grow_chance = 20,
        tree_grow_heat_max = 0,
        tree_grow_heat_min = growth_heat_min,
        tree_grow_light_max = 15,
        tree_grow_water_min = 3,
        tree_liquid_lava = 1,
        tree_pipe_sides = 1,
        tree_water_max = 63,
        tree_water_param2 = 1,
        wield_light = 3,
    },
    sounds = default.node_sound_stone_defaults(),
})

minetest.register_node(":" .. crown_name, {
    description = "Lava Tree Crown",
    drawtype = "allfaces_optional",
    tiles = {{
        name = "default_lava_source_animated.png",
        animation = {
            type = "vertical_frames",
            aspect_w = 16,
            aspect_h = 16,
            length = 3,
        },
    }},
    paramtype = "light",
    light_source = 11,
    walkable = false,
    is_ground_content = false,
    damage_per_second = 4,
    drop = "default:obsidian",
    freeze = "default:obsidian",
    groups = {
        leaves = 1,
        cracky = 3,
        freeze = freeze_heat_max,
        grow_leaves = 1,
        hot = 700,
        igniter = 1,
        lava_tree_live = 1,
        leaves_die_from_liquid = 0,
        leaves_die_heat_max = 0,
        leaves_die_heat_min = 0,
        leaves_grow_heat_max = 0,
        leaves_grow_heat_min = growth_heat_min,
        leaves_grow_light_min = 0,
        leaves_grow_water_min_bottom = 3,
        leaves_grow_water_min_side = 2,
        leaves_grow_water_min_top = 3,
        leaves_water_max = 40,
        tree_get_water_from_humidity = 0,
        wield_light = 5,
        fall_damage_add_percent = -40,
    },
    sounds = default.node_sound_stone_defaults(),
})

local function offset(pos, x, y, z)
    return {
        x = pos.x + (x or 0),
        y = pos.y + (y or 0),
        z = pos.z + (z or 0),
    }
end

local function climate_allows_growth(pos)
    if pos.y > -1000 or pos.y < -31000 then
        return false
    end

    local heat = core.get_heat and core.get_heat(pos) or 0
    return heat >= growth_heat_min and
        minetest.find_node_near(pos, lava_search_radius,
            {"group:lava"}) ~= nil
end

local function position_key(pos)
    return pos.x .. ":" .. pos.y .. ":" .. pos.z
end

local function plan_lava_tree(pos)
    local plan = {}

    local function add(target, name)
        plan[position_key(target)] = {
            pos = target,
            name = name,
        }
    end

    local function add_crown_cluster(center, radius)
        for x = -radius, radius do
            for y = -radius, radius do
                for z = -radius, radius do
                    local distance = math.abs(x) + math.abs(y) + math.abs(z)
                    if distance <= radius + 1 and
                            (distance <= radius or math.random(3) ~= 1) then
                        local target = offset(center, x, y, z)
                        local key = position_key(target)
                        if not plan[key] then
                            add(target, crown_name)
                        end
                    end
                end
            end
        end
    end

    local height = math.random(6, 10)
    if pos.y < -20000 then
        height = height + 2
    end

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
        if math.random(5) ~= 1 then
            local branch_y = height - 5 + ((index + math.random(0, 1)) % 3)
            local length = math.random(2, pos.y < -20000 and 5 or 4)
            local tip
            for distance = 1, length do
                local rise = math.floor(distance / 3)
                tip = offset(pos, direction.x * distance,
                    branch_y + rise, direction.z * distance)
                add(tip, trunk_name)
            end
            add_crown_cluster(tip, math.random(1, 2))
        end
    end

    add_crown_cluster(offset(pos, 0, height - 1, 0), 2)
    add(offset(pos, 0, height, 0), crown_name)
    return plan
end

local function can_replace_with_tree(pos)
    local node = minetest.get_node_or_nil(pos)
    if not node or node.name == "ignore" then
        return false
    end
    if node.name == bud_name or node.name == crown_name then
        return true
    end
    local definition = minetest.registered_nodes[node.name]
    return definition and definition.buildable_to
end

local function consume_lava(pos, amount)
    local minp = offset(pos, -lava_search_radius, -lava_search_radius,
        -lava_search_radius)
    local maxp = offset(pos, lava_search_radius, lava_search_radius,
        lava_search_radius)
    local lava_positions = minetest.find_nodes_in_area(minp, maxp,
        {"group:lava"})
    local available = 0

    for _, lava_pos in ipairs(lava_positions) do
        available = available +
            math.max(0, minetest.get_node_level(lava_pos) - 1)
    end
    if available < amount then
        return false
    end

    local remaining = amount
    for _, lava_pos in ipairs(lava_positions) do
        local level = minetest.get_node_level(lava_pos)
        local consumed = math.min(remaining, math.max(0, level - 1))
        if consumed > 0 then
            minetest.add_node_level(lava_pos, -consumed)
            remaining = remaining - consumed
            if remaining == 0 then
                break
            end
        end
    end
    return true
end

local function grow_lava_tree(pos)
    if not climate_allows_growth(pos) then
        return false
    end

    local below = minetest.get_node_or_nil(offset(pos, 0, -1, 0))
    if not below or
            (not root_substrates[below.name] and below.name ~= root_name) then
        return false
    end

    if minetest.is_area_protected(offset(pos, -7, -1, -7),
            offset(pos, 7, 14, 7), "", 2) then
        return false
    end

    local plan = plan_lava_tree(pos)
    local plan_size = 0
    for _, placement in pairs(plan) do
        plan_size = plan_size + 1
        if placement.pos.y == pos.y - 1 then
            if placement.name ~= root_name then
                return false
            end
        elseif not can_replace_with_tree(placement.pos) then
            return false
        end
    end

    local lava_cost = math.max(3, math.ceil(plan_size / 16))
    if not consume_lava(pos, lava_cost) then
        return false
    end

    for _, placement in pairs(plan) do
        minetest.set_node(placement.pos, {
            name = placement.name,
            param2 = placement.name == root_name and 0 or 1,
        })
    end
    return true
end

local function start_bud_timer(pos)
    minetest.get_node_timer(pos):start(math.random(600, 1800))
end

minetest.register_node(":" .. bud_name, {
    description = "Lava Tree Bud",
    drawtype = "plantlike",
    visual_scale = 0.8,
    tiles = {
        "default_mese_crystal.png^[colorize:#FF4A10:210",
    },
    inventory_image =
        "default_mese_crystal.png^[colorize:#FF4A10:210",
    wield_image =
        "default_mese_crystal.png^[colorize:#FF4A10:210",
    paramtype = "light",
    light_source = 7,
    sunlight_propagates = true,
    walkable = false,
    buildable_to = true,
    is_ground_content = false,
    damage_per_second = 2,
    drop = "default:stone",
    freeze = "default:stone",
    selection_box = {
        type = "fixed",
        fixed = {-3 / 16, -0.5, -3 / 16, 3 / 16, 4 / 16, 3 / 16},
    },
    groups = {
        cracky = 3,
        attached_node = 1,
        sapling = 1,
        freeze = freeze_heat_max,
        hot = 400,
        igniter = 1,
        lava_tree_live = 1,
        wield_light = 4,
    },
    sounds = default.node_sound_stone_defaults(),

    on_construct = start_bud_timer,

    on_timer = function(pos)
        if not grow_lava_tree(pos) then
            start_bud_timer(pos)
        end
        return false
    end,

    on_place = function(itemstack, placer, pointed_thing)
        if pointed_thing.type ~= "node" then
            return itemstack
        end

        local ground_pos = pointed_thing.under
        local ground = minetest.get_node_or_nil(ground_pos)
        if not ground or not root_substrates[ground.name] then
            return itemstack
        end

        local pos = pointed_thing.above
        local target = minetest.get_node_or_nil(pos)
        local target_def = target and minetest.registered_nodes[target.name]
        if not target_def or not target_def.buildable_to or
                not minetest.find_node_near(pos, lava_search_radius,
                    {"group:lava"}) then
            return itemstack
        end

        local player_name = placer and placer:get_player_name() or ""
        if minetest.is_area_protected(offset(pos, -7, -1, -7),
                offset(pos, 7, 14, 7), player_name, 2) then
            minetest.record_protection_violation(pos, player_name)
            return itemstack
        end

        minetest.set_node(pos, {name = bud_name})
        if not minetest.is_creative_enabled(player_name) then
            itemstack:take_item()
        end
        return itemstack
    end,
})

default.register_leafdecay({
    trunks = {trunk_name},
    leaves = {crown_name},
    radius = 4,
})

-- Rare buds establish on stone or obsidian beside deep lava.
minetest.register_abm({
    label = "Freeminer lava tree bud seeding",
    nodenames = {"default:stone", "default:obsidian"},
    neighbors = {"group:lava"},
    interval = 60,
    chance = 5000,
    catch_up = false,
    action = function(pos)
        local bud_pos = offset(pos, 0, 1, 0)
        local target = minetest.get_node_or_nil(bud_pos)
        local target_def = target and minetest.registered_nodes[target.name]
        if not target_def or not target_def.buildable_to or
                minetest.is_protected(bud_pos, "") or
                not climate_allows_growth(bud_pos) then
            return
        end

        if minetest.find_node_near(bud_pos, 16,
                {root_name, bud_name, trunk_name}) then
            return
        end

        minetest.set_node(bud_pos, {name = bud_name})
    end,
})
