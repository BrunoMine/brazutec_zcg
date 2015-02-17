--[[
ZCG mod para minetest
Crado por Zeg'9 da comunidade internacional <http://minetest.net/>
Alteradoe adaptado por BrunoMine da comunidade minetestbr <http://minetestbr.blogspot.com.br/> 
]]--

-- Carregar outros arquivos
print("[Brazutec_zcg] Carregando mod brazutec_zcg... ")

-- Função para do inventário de guia de montagem
 
local tela_principal = {}
tela_principal.set_inventory_formspec = function(player,formspec)
		minetest.show_formspec(player:get_player_name(), "", formspec)
end

zcg = {}

zcg.users = {}
zcg.crafts = {}
zcg.itemlist = {}

zcg.items_in_group = function(group)
	local items = {}
	local ok = true
	for name, item in pairs(minetest.registered_items) do
		-- the node should be in all groups
		ok = true
		for _, g in ipairs(group:split(',')) do
			if not item.groups[g] then
				ok = false
			end
		end
		if ok then table.insert(items,name) end
	end
	return items
end

local table_copy = function(table)
	local out = {}
	for k,v in pairs(table) do
		out[k] = v
	end
	return out
end

zcg.add_craft = function(input, output, groups)
	if minetest.get_item_group(output, "not_in_craft_guide") > 0 then
		return
	end
	if not groups then groups = {} end
	local c = {}
	c.width = input.width
	c.type = input.type
	c.items = input.items
	if c.items == nil then return end
	for i, item in pairs(c.items) do
		if item:sub(0,6) == "group:" then
			local groupname = item:sub(7)
			if groups[groupname] ~= nil then
				c.items[i] = groups[groupname]
			else
				for _, gi in ipairs(zcg.items_in_group(groupname)) do
					local g2 = groups
					g2[groupname] = gi
					zcg.add_craft({
						width = c.width,
						type = c.type,
						items = table_copy(c.items)
					}, output, g2) -- it is needed to copy the table, else groups won't work right
				end
				return
			end
		end
	end
	if c.width == 0 then c.width = 3 end
	table.insert(zcg.crafts[output],c)
end

zcg.load_crafts = function(name)
	zcg.crafts[name] = {}
	local _recipes = minetest.get_all_craft_recipes(name)
	if _recipes then
		for i, recipe in ipairs(_recipes) do
			if (recipe and recipe.items and recipe.type) then
				zcg.add_craft(recipe, name)
			end
		end
	end
	if zcg.crafts[name] == nil or #zcg.crafts[name] == 0 then
		zcg.crafts[name] = nil
	else
		table.insert(zcg.itemlist,name)
	end
end

zcg.need_load_all = true

zcg.load_all = function()
	print("[Brazutec Zcg] Carregando todas as receitas, isso pode levar algum tempo...")
	local i = 0
	for name, item in pairs(minetest.registered_items) do
		if (name and name ~= "") then
			zcg.load_crafts(name)
		end
		i = i+1
	end
	table.sort(zcg.itemlist)
	zcg.need_load_all = false
	print("[Brazutec Zcg] Todos as receitas carregadas.")
end

zcg.formspec = function(pn)
	if zcg.need_load_all then zcg.load_all() end
	local page = zcg.users[pn].page
	local alt = zcg.users[pn].alt
	local current_item = zcg.users[pn].current_item
	local formspec = "size[8,7.5]"
	.. "button_exit[0,0;2,.5;;Sair]"
	if zcg.users[pn].history.index > 1 then
		formspec = formspec .. "image_button[0,1;1,1;brazutec_zcg_previous.png;zcg_previous;;false;false;brazutec_zcg_previous_press.png]"
	else
		formspec = formspec .. "image[0,1;1,1;brazutec_zcg_previous_inactive.png]"
	end
	if zcg.users[pn].history.index < #zcg.users[pn].history.list then
		formspec = formspec .. "image_button[1,1;1,1;brazutec_zcg_next.png;zcg_next;;false;false;brazutec_zcg_next_press.png]"
	else
		formspec = formspec .. "image[1,1;1,1;brazutec_zcg_next_inactive.png]"
	end
	-- Show craft recipe
	if current_item ~= "" then
		if zcg.crafts[current_item] then
			if alt > #zcg.crafts[current_item] then
				alt = #zcg.crafts[current_item]
			end
			if alt > 1 then
				formspec = formspec .. "image_button[7,0;1,1;brazutec_zcg_setapracima.png;zcg_alt:"..(alt-1)..";]"
			end
			if alt < #zcg.crafts[current_item] then
				formspec = formspec .. "image_button[7,2;1,1;brazutec_zcg_setaprabaixo.png;zcg_alt:"..(alt+1)..";]"
			end
			local c = zcg.crafts[current_item][alt]
			if c then
				local x = 3
				local y = 0
				for i, item in pairs(c.items) do
					formspec = formspec .. "item_image_button["..((i-1)%c.width+x)..","..(math.floor((i-1)/c.width+y))..";1,1;"..item..";zcg:"..item..";]"
				end
				if c.type == "normal" or c.type == "cooking" then
					formspec = formspec .. "image[6,2;1,1;brazutec_zcg_method_"..c.type..".png]"
				else -- we don't have an image for other types of crafting
					formspec = formspec .. "label[0,2;Method: "..c.type.."]"
				end
				formspec = formspec .. "image[6,1;1,1;brazutec_zcg_craft_arrow.png]"
				formspec = formspec .. "item_image_button[7,1;1,1;"..zcg.users[pn].current_item..";;]"
			end
		end
	end
	
	-- Node list
	local npp = 8*3 -- nodes per page
	local i = 0 -- for positionning buttons
	local s = 0 -- for skipping pages
	for _, name in ipairs(zcg.itemlist) do
		if s < page*npp then s = s+1 else
			if i >= npp then break end
			formspec = formspec .. "item_image_button["..(i%8)..","..(math.floor(i/8)+3.5)..";1,1;"..name..";zcg:"..name..";]"
			i = i+1
		end
	end
	if page > 0 then
		formspec = formspec .. "image_button[0,6.5;1,1;brazutec_zcg_pagina_anterior.png;zcg_page:"..(page-1)..";]"
	end
	if i >= npp then
		formspec = formspec .. "image_button[1,6.5;1,1;brazutec_zcg_proxima_pagina.png;zcg_page:"..(page+1)..";]"
	end
	formspec = formspec .. "label[2,6.85;Pagina "..(page+1).." de "..(math.floor(#zcg.itemlist/npp+1)).."]" -- The Y is approximatively the good one to have it centered vertically...
	return formspec
end

minetest.register_on_player_receive_fields(function(player,formname,fields)
	local pn = player:get_player_name();
	if zcg.users[pn] == nil then zcg.users[pn] = {current_item = "", alt = 1, page = 0, history={index=0,list={}}} end
	if fields.zcg then
		tela_principal.set_inventory_formspec(player, zcg.formspec(pn))
		return
	elseif fields.zcg_previous then
		if zcg.users[pn].history.index > 1 then
			zcg.users[pn].history.index = zcg.users[pn].history.index - 1
			zcg.users[pn].current_item = zcg.users[pn].history.list[zcg.users[pn].history.index]
			tela_principal.set_inventory_formspec(player,zcg.formspec(pn))
		end
	elseif fields.zcg_next then
		if zcg.users[pn].history.index < #zcg.users[pn].history.list then
			zcg.users[pn].history.index = zcg.users[pn].history.index + 1
			zcg.users[pn].current_item = zcg.users[pn].history.list[zcg.users[pn].history.index]
			tela_principal.set_inventory_formspec(player,zcg.formspec(pn))
		end
	end
	for k, v in pairs(fields) do
		if (k:sub(0,4)=="zcg:") then
			local ni = k:sub(5)
			if zcg.crafts[ni] then
				zcg.users[pn].current_item = ni
				table.insert(zcg.users[pn].history.list, ni)
				zcg.users[pn].history.index = #zcg.users[pn].history.list
				tela_principal.set_inventory_formspec(player,zcg.formspec(pn))
			end
		elseif (k:sub(0,9)=="zcg_page:") then
			zcg.users[pn].page = tonumber(k:sub(10))
			tela_principal.set_inventory_formspec(player,zcg.formspec(pn))
		elseif (k:sub(0,8)=="zcg_alt:") then
			zcg.users[pn].alt = tonumber(k:sub(9))
			tela_principal.set_inventory_formspec(player,zcg.formspec(pn))
		end
	end
	if fields.brazutec_desktop_etiqueta then
		minetest.show_formspec(player:get_player_name(), "", brazutec_laptop.desktop)
	end
end)

--
-- Nó Mini guia de montagem
--

minetest.register_node("brazutec_zcg:mini_guia", {
	description = "Mini Guia de Montagem",
	drawtype = "nodebox",
	tiles = {
		{name="brazutec_zcg_mini_guia.png", animation={type="vertical_frames", aspect_w=16, aspect_h=16, length=2.0}}
	},
	inventory_image = "brazutec_zcg_mini_guia_inventario.png",
	wield_image = "brazutec_zcg_mini_guia_inventario.png",
	paramtype = "light",
	paramtype2 = "wallmounted",
	sunlight_propagates = true,
	light_source = LIGHT_MAX,
	is_ground_content = false,
	walkable = false,
	node_box = {
		type = "wallmounted",
		wall_top    = {-0.3125, 0.3125, -0.3125, 0.3125, 0.5, 0.3125},
		wall_bottom = {-0.3125, -0.5, -0.3125, 0.3125, -0.3125, 0.3125},
		wall_side   = {-0.5, -0.3125, -0.3125, -0.3125, 0.3125, 0.3125},
	},
	groups = {choppy=2,dig_immediate=2,attached_node=1},
	legacy_wallmounted = true,
	sounds = default.node_sound_defaults(),
	on_rightclick = function(pos, node, player, itemstack, pointed_thing)
		local pn = player:get_player_name();
		if zcg.users[pn] == nil then zcg.users[pn] = {current_item = "", alt = 1, page = 0, history={index=0,list={}}} end
		tela_principal.set_inventory_formspec(player, zcg.formspec(pn))
	end,
})

minetest.register_alias("brazutec_zcg_guia", "brazutec_zcg:mini_guia")

--
-- Passar dados para o laptop cub
--

local imagem_app = "brazutec_zcg_app_botao.png"
local etiqueta_app = "zcg"

brazutec_instalar_em_cub(imagem_app, etiqueta_app)

print("[Brazutec_zcg] OK")
