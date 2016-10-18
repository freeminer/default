local give = function (player)                                                                                                                                                       
        --print("on_newplayer")                                                                                                                                                      
        if minetest.setting_getbool("give_initial_stuff") then                                                                                                                       
                --minetest.log("action", "Giving initial stuff to player "..player:get_player_name())                                                                                
                --player:get_inventory():add_item('main', 'tnt:tnt 999')                                                                                                               
                player:get_inventory():add_item('main', 'default:torch 999')                                                                                                          
                player:get_inventory():add_item('main', 'default:pick_steel')                                                                                                        
                player:get_inventory():add_item('main', 'default:axe_steel')                                                                                                         
                player:get_inventory():add_item('main', 'default:shovel_steel')                                                                                                      
                --player:get_inventory():add_item('main', 'default:cobble 99')                                                                                                         
                --player:get_inventory():add_item('main', 'spring:water 10')                                                                                                           
                --player:get_inventory():add_item('main', 'spring:lava 3')                                                                                                             
                --player:get_inventory():add_item('main', 'spring:dirt')                                                                                                               
                --player:get_inventory():add_item('main', 'spring:water_compressed')                                                                                                   
                --player:get_inventory():add_item('main', 'spring:dirt_compressed')                                                                                                    
        end                                                                                                                                                                          
end                                                                                                                                                                                  
local giveresp = function (player)                                                                                                                                                   
        --print("on_newplayer")                                                                                                                                                      
        if minetest.setting_getbool("give_initial_stuff") then                                                                                                                       
                --minetest.log("action", "Giving initial stuff to player "..player:get_player_name())                                                                                
                --player:get_inventory():add_item('main', 'tnt:tnt 50')                                                                                                                
                player:get_inventory():add_item('main', 'default:torch 99')                                                                                                          
                player:get_inventory():add_item('main', 'default:pick_wood')                                                                                                        
                --player:get_inventory():add_item('main', 'default:axe_steel')                                                                                                         
                --player:get_inventory():add_item('main', 'default:shovel_steel')                                                                                                      
                --player:get_inventory():add_item('main', 'default:cobble 99')                                                                                                         
                --player:get_inventory():add_item('main', 'spring:water 10')                                                                                                           
                --player:get_inventory():add_item('main', 'spring:lava 3')                                                                                                             
        end                                                                                                                                                                          
end                                                                                                                                                                                  
minetest.register_on_newplayer(give)                                                                                                                                                 
minetest.register_on_respawnplayer(giveresp)                                       


















--[[

local stuff_string = minetest.setting_get("initial_stuff") or
		"default:pick_steel,default:axe_steel,default:shovel_steel," ..
		"default:torch 99,default:cobble 99"

give_initial_stuff = {
	items = {}
}

function give_initial_stuff.give(player)
	minetest.log("action",
			"Giving initial stuff to player " .. player:get_player_name())
	local inv = player:get_inventory()
	for _, stack in ipairs(give_initial_stuff.items) do
		inv:add_item("main", stack)
	end
end

function give_initial_stuff.add(stack)
	give_initial_stuff.items[#give_initial_stuff.items + 1] = ItemStack(stack)
end

function give_initial_stuff.clear()
	give_initial_stuff.items = {}
end

function give_initial_stuff.add_from_csv(str)
	local items = str:split(",")
	for _, itemname in ipairs(items) do
		give_initial_stuff.add(itemname)
	end
end

function give_initial_stuff.set_list(list)
	give_initial_stuff.items = list
end

function give_initial_stuff.get_list()
	return give_initial_stuff.items
end

give_initial_stuff.add_from_csv(stuff_string)
if minetest.setting_getbool("give_initial_stuff") then
	minetest.register_on_newplayer(give_initial_stuff.give)
end


]]
