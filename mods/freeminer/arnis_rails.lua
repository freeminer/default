-- The engine supplies positions from the native railway plan. Advtrains owns
-- a separate persistent node database, indexed here once after it is loaded.
local at = rawget(_G, "advtrains")
if not at or not at.ndb or not at.ndb.get_nodes then return end
local pending, blocks, indexed = {}, {}, false
local function block_key(x, y, z)
	return math.floor(x / 16) .. ":" .. math.floor(y / 16) .. ":" .. math.floor(z / 16)
end
local function index_node(pos, present)
	if not indexed then return end
	local key, nodekey = block_key(pos.x, pos.y, pos.z), minetest.pos_to_string(pos)
	if present then
		blocks[key] = blocks[key] or {}
		blocks[key][nodekey] = {x=pos.x, y=pos.y, z=pos.z}
	elseif blocks[key] then
		blocks[key][nodekey] = nil
		if not next(blocks[key]) then blocks[key] = nil end
	end
end
local update, clear = at.ndb.update, at.ndb.clear
at.ndb.update = function(pos, node)
	update(pos, node)
	index_node(pos, at.ndb.get_node_raw(pos) ~= nil)
end
if clear then
	at.ndb.clear = function(pos)
		clear(pos)
		index_node(pos, false)
	end
end
local function build_index()
	if indexed then return end
	indexed = true
	for y, columns in pairs(at.ndb.get_nodes()) do
		for x, column in pairs(columns) do
			for z in pairs(column) do index_node({x=x, y=y, z=z}, true) end
		end
	end
end
local function inside(p, lo, hi)
	return p.x >= lo.x and p.x <= hi.x and p.y >= lo.y and p.y <= hi.y and
		p.z >= lo.z and p.z <= hi.z
end
local function synchronize(batch)
	build_index()
	local stale = {}
	for by = math.floor(batch.lo.y / 16), math.floor(batch.hi.y / 16) do
		for bx = math.floor(batch.lo.x / 16), math.floor(batch.hi.x / 16) do
			for bz = math.floor(batch.lo.z / 16), math.floor(batch.hi.z / 16) do
				for key, pos in pairs(blocks[bx .. ":" .. by .. ":" .. bz] or {}) do
					if inside(pos, batch.lo, batch.hi) and not batch.nodes[key] then
						local node = minetest.get_node_or_nil(pos)
						if node and node.name ~= "ignore" then stale[#stale+1] = {pos=pos, node=node} end
					end
				end
			end
		end
	end
	for _, entry in ipairs(stale) do at.ndb.update(entry.pos, entry.node) end
	for _, entry in pairs(batch.nodes) do
		local node = minetest.get_node_or_nil(entry.pos)
		if node and node.name ~= "ignore" then
			if node.name ~= entry.node.name or node.param2 ~= entry.node.param2 then
				minetest.swap_node(entry.pos, entry.node)
			end
			local cached = at.ndb.get_node_raw(entry.pos)
			if not cached or cached.name ~= entry.node.name or cached.param2 ~= entry.node.param2 then
				at.ndb.update(entry.pos, entry.node)
			end
		end
	end
end
minetest.set_gen_notify("custom", nil, {"freeminer:arnis_rails"})
minetest.register_on_generated(function(lo, hi)
	if minetest.get_mapgen_setting("mg_name") ~= "earth" then return end
	local notify = minetest.get_mapgen_object("gennotify")
	local positions = notify and notify.custom and notify.custom["freeminer:arnis_rails"]
	if not positions then return end
	local batch = {lo=vector.new(lo), hi=vector.new(hi), nodes={}}
	for _, pos in ipairs(positions) do
		local node = minetest.get_node_or_nil(pos)
		local def = node and minetest.registered_nodes[node.name]
		if def and def.groups and def.groups.save_in_at_nodedb then
			batch.nodes[minetest.pos_to_string(pos)] = {pos=pos, node=node}
		end
	end
	if (at.mainloop_runcnt or 0) > 0 then synchronize(batch)
	else pending[#pending+1] = batch end
end)
minetest.register_globalstep(function()
	if #pending == 0 or (at.mainloop_runcnt or 0) == 0 then return end
	local batches = pending
	pending = {}
	for _, batch in ipairs(batches) do synchronize(batch) end
end)
