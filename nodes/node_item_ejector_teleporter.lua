-- A teleporting inventory item ejector that takes non-building, non-fuel
-- items from inventories, and teleports them on a pipeworks tube channel.

local DEBUG_PREFIX = "[Digtron teleporting ejector] "
minetest.debug(DEBUG_PREFIX .. "WARNING: Under heavy development!")

-- internationalization boilerplate
local MP = minetest.get_modpath(minetest.get_current_modname())
local S, NS = dofile(MP.."/intllib.lua")

-- Check for pipeworks.
local pipeworks_path = minetest.get_modpath("pipeworks")
if pipeworks_path then
	-- pipeworks was found
	minetest.debug(DEBUG_PREFIX .. "pipeworks found:", pipeworks_path)
	
else
	-- pipeworks was not found
	minetest.debug(DEBUG_PREFIX .. "pipeworks not found")
end -- if pipeworks_path
