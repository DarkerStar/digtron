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
	
	minetest.debug(DEBUG_PREFIX .. "registering node")
	minetest.register_node("digtron:inventory_ejector_teleporter", {
		description = S("Digtron Teleporting Inventory Ejector"),
		-- TODO: make docs (use regular item ejector docs for now)
		_doc_items_longdesc = digtron.doc.inventory_ejector_longdesc,
		_doc_items_usagehelp = digtron.doc.inventory_ejector_usagehelp,
		groups = {cracky = 3,  oddly_breakable_by_hand=3, digtron = 1},
		-- TODO: change appearance
		tiles = {"digtron_plate.png", "digtron_plate.png", "digtron_plate.png", "digtron_plate.png", "digtron_plate.png^digtron_output.png", "digtron_plate.png^digtron_output_back.png"},
		drawtype = "nodebox",
		sounds = digtron.metal_sounds,
		paramtype = "light",
		paramtype2 = "facedir",
		is_ground_content = false,
		node_box = {
			type = "fixed",
			fixed = {
				{-0.5, -0.5, -0.5, 0.5, 0.5, 0.1875}, -- NodeBox1
				{-0.3125, -0.3125, 0.1875, 0.3125, 0.3125, 0.3125}, -- NodeBox2
				{-0.1875, -0.1875, 0.3125, 0.1875, 0.1875, 0.5}, -- NodeBox3
			}
		},
	})
	minetest.debug(DEBUG_PREFIX .. "registering node: success")
else
	-- pipeworks was not found
	minetest.debug(DEBUG_PREFIX .. "pipeworks not found")
end -- if pipeworks_path
