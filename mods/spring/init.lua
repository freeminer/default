
core.register_node("spring:water",{
    description = "Water spring",
    tiles = {"default_water.png"},
})

core.register_abm({
    nodenames = {"spring:water"},
    interval = 2,
    chance = 2,
    action = function(pos,node)
        core.set_node(pos,{name = "default:water_source", param2=128})
    end
})

core.register_node("spring:water_compressed",{
    description = "Water spring compressed",
    tiles = {"default_water.png"},
})

core.register_abm({
    nodenames = {"spring:water_compressed"},
    interval = 2,
    chance = 2,
    action = function(pos,node)
        core.set_node(pos,{name = "default:water_source", param2=128+31})
    end
})

core.register_node("spring:lava",{
    description = "Lava spring",
    tiles = {"default_lava.png"},
})

core.register_abm({
    nodenames = {"spring:lava"},
    interval = 2,
    chance = 2,
    action = function(pos,node)
        core.set_node(pos,{name = "default:lava_source", param2=128})
    end
})

core.register_node("spring:dirt",{
    description = "Dirt spring",
    tiles = {"default_dirt.png"},
})

core.register_abm({
    nodenames = {"spring:dirt"},
    interval = 2,
    chance = 2,
    action = function(pos,node)
        core.set_node(pos,{name = "default:dirt", param2=128})
    end
})

core.register_node("spring:dirt_compressed",{
    description = "Dirt spring compressed",
    tiles = {"default_dirt.png"},
})

core.register_abm({
    nodenames = {"spring:dirt_compressed"},
    interval = 2,
    chance = 2,
    action = function(pos,node)
        core.set_node(pos,{name = "default:dirt", param2=128+31})
    end
})

core.register_node("spring:sand",{
    description = "Sand spring",
    tiles = {"default_sand.png"},
})

core.register_abm({
    nodenames = {"spring:sand"},
    interval = 2,
    chance = 2,
    action = function(pos,node)
        core.set_node(pos,{name = "default:sand", param2=128})
    end
})
