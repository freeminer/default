-- Glowing life for flooded caverns between y = -1000 and the bottom of the
-- conventional 31000-node map. Marinara supplies the animated plant textures;
-- the nodes and their behavior belong to Freeminer.

if not minetest.registered_nodes["marinara:sand_with_kelp"] then
    return
end

local function is_source_water(pos)
    local node = minetest.get_node_or_nil(pos)
    if not node then
        return false
    end
    local def = minetest.registered_nodes[node.name]
    return def and def.liquidtype == "source" and
        minetest.get_item_group(node.name, "water") > 0
end

local function rooted_on_place(name, substrate, initial_param2, water_direction,
        water_depth)
    return function(itemstack, placer, pointed_thing)
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
        if minetest.get_node(pos).name ~= substrate then
            return itemstack
        end

        for distance = 1, water_depth do
            local water_pos = {
                x = pos.x,
                y = pos.y + water_direction * distance,
                z = pos.z,
            }
            if not is_source_water(water_pos) then
                return itemstack
            end
        end

        local player_name = placer and placer:get_player_name() or ""
        if minetest.is_protected(pos, player_name) then
            minetest.record_protection_violation(pos, player_name)
            return itemstack
        end

        minetest.set_node(pos, {
            name = name,
            param2 = initial_param2,
        })
        if not minetest.is_creative_enabled(player_name) then
            itemstack:take_item()
        end
        return itemstack
    end
end

local function register_deep_plant(name, definition)
    local texture = definition.texture ..
        "^[colorize:" .. definition.color .. ":" ..
        (definition.color_strength or 110)
    local inventory_texture = (definition.inventory_texture or
        definition.texture) .. "^[colorize:" .. definition.color .. ":" ..
        (definition.color_strength or 110)

    local extension_box = definition.wallmounted and
        {-4 / 16, -1.5, -4 / 16, 4 / 16, -0.5, 4 / 16} or
        {-4 / 16, 0.5, -4 / 16, 4 / 16, 1.5, 4 / 16}

    local node_definition = {
        description = definition.description,
        drawtype = "plantlike_rooted",
        waving = 1,
        visual_scale = definition.visual_scale or 1,
        tiles = {definition.base_texture},
        special_tiles = {{
            name = texture,
            tileable_vertical = true,
            waving = 1,
            animation = definition.animation,
        }},
        inventory_image = inventory_texture,
        wield_image = inventory_texture,
        paramtype = "light",
        paramtype2 = definition.wallmounted and "wallmounted" or "leveled",
        light_source = definition.light_source,
        groups = {
            snappy = 3,
            aquatic_plant = 1,
            wield_light = definition.light_source,
        },
        selection_box = {
            type = "fixed",
            fixed = {
                {-0.5, -0.5, -0.5, 0.5, 0.5, 0.5},
                extension_box,
            },
        },
        node_dig_prediction = definition.substrate,
        node_placement_prediction = "",
        sounds = default.node_sound_stone_defaults({
            dig = {name = "default_dig_snappy", gain = 0.2},
            dug = {name = "default_grass_footstep", gain = 0.25},
        }),
        on_place = rooted_on_place(name, definition.substrate,
            definition.initial_param2, definition.water_direction or 1,
            definition.water_depth or 1),
        after_destruct = function(pos)
            minetest.set_node(pos, {name = definition.substrate})
        end,
    }

    minetest.register_node(name, node_definition)
end

register_deep_plant("freeminer:pressure_lantern_kelp", {
    description = "Pressure Lantern Kelp",
    substrate = "default:stone",
    base_texture = "default_stone.png",
    texture = "marinara_kelp.png",
    inventory_texture = "marinara_kelp_inv.png",
    color = "#24D8FF",
    color_strength = 125,
    visual_scale = 2,
    initial_param2 = 32,
    water_depth = 4,
    light_source = 4,
    animation = {type = "vertical_frames", length = 3},
})

register_deep_plant("freeminer:mese_root_fan", {
    description = "Mese Root Fan",
    substrate = "default:stone_with_mese",
    base_texture = "default_stone.png^default_mineral_mese.png",
    texture = "marinara_softcoral_yellow.png",
    inventory_texture = "marinara_softcoral_yellow_inv.png",
    color = "#FFD83D",
    color_strength = 90,
    visual_scale = 1.5,
    initial_param2 = 16,
    water_depth = 2,
    light_source = 6,
    animation = {type = "vertical_frames", length = 3},
})

register_deep_plant("freeminer:blackwater_bell", {
    description = "Blackwater Bell",
    substrate = "default:stone",
    base_texture = "default_stone.png",
    texture = "marinara_seaanemone_tentacle4.png",
    inventory_texture = "marinara_seaanemone_tentacle4_inv.png",
    color = "#A344FF",
    color_strength = 130,
    initial_param2 = 1,
    water_direction = -1,
    wallmounted = true,
    light_source = 5,
    animation = {type = "vertical_frames", length = 4},
})

register_deep_plant("freeminer:obsidian_vent_grass", {
    description = "Obsidian Vent Grass",
    substrate = "default:obsidian",
    base_texture = "default_obsidian.png",
    texture = "marinara_brownalage.png",
    inventory_texture = "marinara_brownalage_inv.png",
    color = "#FF641F",
    color_strength = 145,
    visual_scale = 1.5,
    initial_param2 = 16,
    water_depth = 2,
    light_source = 7,
    animation = {type = "vertical_frames", length = 2},
})

register_deep_plant("freeminer:hadal_glass_fern", {
    description = "Hadal Glass Fern",
    substrate = "default:obsidian",
    base_texture = "default_obsidian.png",
    texture = "marinara_softcoral_white.png",
    inventory_texture = "marinara_softcoral_white_inv.png",
    color = "#BDEEFF",
    color_strength = 75,
    visual_scale = 1.5,
    initial_param2 = 16,
    water_depth = 2,
    light_source = 3,
    animation = {type = "vertical_frames", length = 4},
})

register_deep_plant("freeminer:core_vein_creeper", {
    description = "Core-Vein Creeper",
    substrate = "default:stone",
    base_texture = "default_stone.png",
    texture = "marinara_softcoral_red.png",
    color = "#FF182C",
    color_strength = 120,
    visual_scale = 1.5,
    initial_param2 = 16,
    water_depth = 2,
    light_source = 8,
})

register_deep_plant("freeminer:void_star_bloom", {
    description = "Void Star Bloom",
    substrate = "default:stone_with_diamond",
    base_texture = "default_stone.png^default_mineral_diamond.png",
    texture = "marinara_seaanemone_tentacle3.png",
    inventory_texture = "marinara_seaanemone_tentacle3_inv.png",
    color = "#5273FF",
    color_strength = 130,
    visual_scale = 1.5,
    initial_param2 = 16,
    water_depth = 2,
    light_source = 9,
    animation = {type = "vertical_frames", length = 5},
})

register_deep_plant("freeminer:bedrock_lantern", {
    description = "Bedrock Lantern",
    substrate = "default:stone",
    base_texture = "default_stone.png",
    texture = "marinara_seaworm3.png",
    inventory_texture = "marinara_seaworm3_inv.png",
    color = "#B5FFCF",
    color_strength = 130,
    visual_scale = 1.5,
    initial_param2 = 16,
    water_depth = 2,
    light_source = 10,
    animation = {type = "vertical_frames", length = 6},
})
