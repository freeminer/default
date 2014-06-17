-- Weather:
-- * rain
-- * snow
-- * wind (not implemented)

assert(core.add_particlespawner, "I told you to run the latest GitHub!")
assert(freeminer.get_heat, "I told you to run the latest freeminer!")

addvectors = function (v1, v2)
	return {x=v1.x+v2.x, y=v1.y+v2.y, z=v1.z+v2.z}
end

local cloud_height = tonumber(core.setting_get("cloud_height"));

get_snow = function (p)
	if not p then return 0 end
	if p.y > cloud_height then return 0 end
	local heat = freeminer.get_heat(p)
	if heat >= 0 then return 0 end
	local humidity = freeminer.get_humidity(p)
	if humidity < 60 then return 0 end
	--print('S h='..freeminer.get_heat(p)..' h='..freeminer.get_humidity(p))
	return (humidity-60)/(100-60)
end

get_rain = function (p)
	if not p then return 0 end
	if p.y > cloud_height then return 0 end
	local heat = freeminer.get_heat(p)
	if heat <= 0 then return 0 end
	if heat > 50 then return 0 end
	local humidity = freeminer.get_humidity(p)
	if humidity < 60 then return 0 end
	--print('R h='..freeminer.get_heat(p)..' h='..freeminer.get_humidity(p))
	return (humidity-60)/(100-60)
end

if core.setting_getbool("weather") then
	if core.setting_getbool("weather") and core.setting_getbool("liquid_real") then
		dofile(core.get_modpath("weather").."/rain.lua")
	end
	dofile(core.get_modpath("weather").."/snow.lua")
end
