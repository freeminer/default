
minetest.register_node("spring:water",{
    description = "Water Spring",
    tiles = {"default_water.png"},
})

minetest.register_abm({
    nodenames = {"spring:water"},
    interval = 2,
    chance = 2,
    action = function(pos,node)
        minetest.set_node(pos,{name = "default:water_source", param2=128})
    end
})

minetest.register_node("spring:lava",{
    description = "Lava Spring",
    tiles = {"default_lava.png"},
})

minetest.register_abm({
    nodenames = {"spring:lava"},
    interval = 2,
    chance = 2,
    action = function(pos,node)
        minetest.set_node(pos,{name = "default:lava_source", param2=128})
    end
})
