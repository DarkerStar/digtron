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
	
	-- pipeworks does not expose an API for its teleporting tubes, so we have
	-- to recreate a lot of its internals.
	
	-- Read pipeworks teleport tube database.
	local function read_tube_db()
		local filename = minetest.get_worldpath() .. "/teleport_tubes"
		local file = io.open(filename, "r")
		if file ~= nil then
			local file_content = file:read("*all")
			io.close(file)
			if file_content and file_content ~= "" then
				local tp_tube_db = minetest.deserialize(file_content)
				tp_tube_db.version = nil
				return tp_tube_db
			end
		else
			return {}
		end
	end
	
	-- Get node name when node is not loaded.
	local function read_node_with_vm(pos)
		local vm = VoxelManip()
		local MinEdge, MaxEdge = vm:read_from_map(pos, pos)
		local data = vm:get_data()
		local area = VoxelArea:new({MinEdge = MinEdge, MaxEdge = MaxEdge})
		return minetest.get_name_from_content_id(data[area:index(pos.x, pos.y, pos.z)])
	end
	
	-- Get teleport tube receiver.
	local function get_receiver(pos, channel)
		-- Because we don't have access to pipeworks's database, we have to
		-- read the file every time.
		local tubes = read_tube_db()
		local receivers = {}
		for key, val in pairs(tubes) do
			-- skip all non-receivers and the tube that it came from as early as possible, as this is called often
			if (val.cr == 1 and val.channel == channel and (val.x ~= pos.x or val.y ~= pos.y or val.z ~= pos.z)) then
				local is_loaded = (minetest.get_node_or_nil(val) ~= nil)
				local node_name = is_loaded and minetest.get_node(val).name or read_node_with_vm(val)
				
				if minetest.registered_nodes[node_name] and minetest.registered_nodes[node_name].is_teleport_tube then
					table.insert(receivers, val)
				end
			end
		end
		
		if receivers[1] ~= nil then
			return receivers[math.random(1,#receivers)]
		else
			return nil
		end
	end
	
	-- This function is basically a copy of eject_items() in
	-- node_item_ejector.lua, modified for teleporation purposes.
	local function teleport_items(pos, node, player)
		minetest.debug(DEBUG_PREFIX .. "beginning teleport ejection")
		
		-- Determine receiver.
		local channel = "digtron"
		local receiver = get_receiver(pos, channel)
		if receiver == nil then
			minetest.debug(DEBUG_PREFIX .. "no receivers on channel:", channel)
			minetest.sound_play("buzzer", {gain=0.5, pos=pos})
			return false
		end
		
		-- (((Clipped section checking output mode, because teleport ejectors don't have them.)))
		-- if not pipeworks_path then eject_even_without_pipeworks = true end -- if pipeworks is not installed, always eject into world (there's no other option)
		-- 
		-- local dir = minetest.facedir_to_dir(node.param2)
		-- local destination_pos = vector.add(pos, dir)
		-- local destination_node_name = minetest.get_node(destination_pos).name
		-- local destination_node_def = minetest.registered_nodes[destination_node_name]
		-- 
		-- local insert_into_pipe = false
		-- local eject_into_world = false
		-- if pipeworks_path and minetest.get_node_group(destination_node_name, "tubedevice") > 0 then
		-- 	insert_into_pipe = true
		-- elseif eject_even_without_pipeworks then
		-- 	if destination_node_def and not destination_node_def.walkable then
		-- 		eject_into_world = true
		-- 	else
		-- 		minetest.sound_play("buzzer", {gain=0.5, pos=pos})
		-- 		return false
		-- 	end
		-- else
		-- 	return false
		-- end
		
		local layout = DigtronLayout.create(pos, player)
		
		-- Build a list of all the items that builder nodes want to use.
		local filter_items = {}
		for _, node_image in pairs(layout.builders) do
			filter_items[node_image.meta.inventory.main[1]:get_name()] = true
		end
		
		-- Look through the inventories and find an item that's not on that list.
		local source_node = nil
		local source_index = nil
		local source_stack = nil
		for _, node_image in pairs(layout.inventories) do
			if type(node_image.meta.inventory.main) ~= "table" then
				node_image.meta.inventory.main = {}
			end
			for index, item_stack in pairs(node_image.meta.inventory.main) do
				if item_stack:get_count() > 0 and not filter_items[item_stack:get_name()] then
					source_node = node_image
					source_index = index
					source_stack = item_stack
					break
				end
			end
			if source_node then break end
		end
		
		-- (((Everything from this point on is teleporter-specific.)))
		if source_node == nil then
			minetest.debug(DEBUG_PREFIX .. "nothing to eject")
			return false
		end
		
		-- TODO: actually teleport item.
		minetest.debug(DEBUG_PREFIX .. "ejecting:", source_stack:get_name(), source_stack:get_count())
		
		-- Create a pipeworks.luaentity object at the position of the
		-- receiver, with zero velocity.
		local receiver_pos = vector.new(receiver.x, receiver.y, receiver.z)
		local obj = pipeworks.luaentity.add_entity(receiver_pos, "pipeworks:tubed_item")
		obj:set_item(source_stack:to_string())
		obj.start_pos = receiver_pos
		obj:set_velocity(vector.new(0, 0, 0))
		obj.owner = player:get_player_name()
		minetest.debug(DEBUG_PREFIX .. "teleported to:", receiver.x, receiver.y, receiver.z)
		
		-- Remove teleported item from inventory.
		local meta = minetest.get_meta(source_node.pos)
		local inv = meta:get_inventory()
		inv:set_stack("main", source_index, nil)
		
		-- Give feedback about ejection.
		minetest.sound_play("steam_puff", {gain=0.5, pos=pos})
		
		return true
	end
	
	minetest.debug(DEBUG_PREFIX .. "registering node")
	minetest.register_node("digtron:inventory_ejector_teleporter", {
		description = S("Digtron Teleporting Inventory Ejector"),
		-- TODO: make docs (use regular item ejector docs for now)
		_doc_items_longdesc = digtron.doc.inventory_ejector_longdesc,
		_doc_items_usagehelp = digtron.doc.inventory_ejector_usagehelp,
		groups = {cracky = 3, oddly_breakable_by_hand=3, digtron = 9},
		tiles = {"digtron_plate.png", "digtron_plate.png", "digtron_plate.png", "digtron_plate.png", "digtron_plate.png^digtron_teleport.png", "digtron_plate.png^digtron_teleport_back.png"},
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
		
		on_construct = function(pos)
			local meta = minetest.get_meta(pos)
			meta:set_string("autoeject", "true")
		end,
		
		execute_eject = function(pos, node, player)
			teleport_items(pos, node, player)
		end,
	})
	minetest.debug(DEBUG_PREFIX .. "registering node: success")
	
else
	-- pipeworks was not found
	minetest.debug(DEBUG_PREFIX .. "pipeworks not found")
end -- if pipeworks_path
