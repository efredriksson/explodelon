require("animation")
require("geometry")
require("player")
require("entity")

global enum ItemType
   "speed"
   "bomb"
   "kick"
   "fire"
end

global function load_item_assets()
    global take_item_sound = lutro.audio.newSource("assets/take_item.wav", "static")
    take_item_sound:setVolume(0.25)
    global tic_counter = 0
    global frame_animation = Animation.new(lutro.graphics.newImage("assets/items/frame.png"), 18, 18, 1, 30)
	global item_shadow = lutro.graphics.newImage("assets/items/shadow.png")
	global item_icons: {ItemType: Image} = {
        ["speed"] = lutro.graphics.newImage("assets/items/speed.png"),
        ["bomb"] = lutro.graphics.newImage("assets/items/bomb.png"),
        ["kick"] = lutro.graphics.newImage("assets/items/kick.png"),
        ["fire"] = lutro.graphics.newImage("assets/items/fire.png"),
    }
end

global record Item is Entity
    type: ItemType
    position: Point
end

function Item.new(item_type: ItemType, position: Point): Item
   local self: Item = setmetatable({}, { __index = Item })
   self.type = item_type
   self.position = position
   return self
end

function Item:draw()
    local item_icon = item_icons[self.type]
    local y_draw = self.position.y - 9
    local x_draw = self.position.x - 1
	frame_animation:draw(x_draw, y_draw)
	lutro.graphics.draw(item_icon, x_draw, y_draw)
	lutro.graphics.draw(item_shadow, x_draw, y_draw)
end

global record Items
    on_ground: {Item}
    by_players: {integer: {Item}}
end

function Items.new(): Items
   local self: Items = setmetatable({}, { __index = Items })
   self.on_ground = {}
   self.by_players = {}
   return self
end

function Items:dropNew(available_spots: {Point})
    tic_counter = tic_counter + 1
    if tic_counter % 120 ~= 0 then
        -- Only consider drop a new item every 120 tic (2 seconds)
        return
    end

    local item_drop_probability = 0.1
    if lutro.math.random() > item_drop_probability then
        return
    end

    for i, available_spot in ipairs(available_spots) do
        for _, existing_item in ipairs(self.on_ground) do
            if available_spot.x == existing_item.position.x and available_spot.y == existing_item.position.y then
                table.remove(available_spots, i)
            end 
        end
    end

    local spot_to_drop = available_spots[lutro.math.random(#available_spots)]
    local items_that_can_drop: {ItemType} = {"speed", "bomb", "kick", "fire"}
    local item_to_drop = items_that_can_drop[lutro.math.random(#items_that_can_drop)]
    table.insert(self.on_ground, Item.new(item_to_drop, spot_to_drop))
end

function Items:update(dt: number)
    frame_animation:update(dt)
end

function Items:consumed_by_player(player: Player, index: integer)
    lutro.audio.play(take_item_sound)

    local item = table.remove(self.on_ground, index)
    if self.by_players[player.id] == nil then
        self.by_players[player.id] = {}
    end
    table.insert(self.by_players[player.id], item)
    if item.type == "speed" then
        player.speed = player.speed + 5
    elseif item.type == "bomb" then
        player.bombs = player.bombs + 1
    elseif item.type == "kick" then
        player.has_kick = true
    elseif item.type == "fire" then
        player.fire = player.fire + 1
    else
        assert(false, "Unhandled item type!")
    end
end