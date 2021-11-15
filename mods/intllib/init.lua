intllib = {
	Getter = function()
		return function(s)
			return s
		end
	end
}

core.get_translator = intllib.Getter
minetest.get_translator = intllib.Getter

return intllib.Getter()
