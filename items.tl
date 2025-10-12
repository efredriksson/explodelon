require("animation")
require("geometry")
require("player")
require("entity")

local ITEM_EXPLOSION_DURATION: number = 0.7

global enum ItemType
   "speed"
   "bomb"
   "kick"
   "fire"
end

global function load_item_assets()
    global take_item_sound = lutro.audio.newSource("assets/take_item.wav", "static")
    take_item_sound:setVolume(0.25)
    global frame_animation = Animation.new(lutro.graphics.newImage("assets/items/frame.png"), 18, 18, 1, 30)
	global item_shadow = lutro.graphics.newImage("assets/items/shadow.png")
	global item_icons: {ItemType: Image} = {
        ["speed"] = lutro.graphics.newImage("assets/items/speed.png"),
        ["bomb"] = lutro.graphics.newImage("assets/items/bomb.png"),
        ["kick"] = lutro.graphics.newImage("assets/items/kick.png"),
        ["fire"] = lutro.graphics.newImage("assets/items/fire.png"),
    }
end

global record Item is Entity, BlocksExplosion, ExplodeTarget
    type: ItemType
    position: Point
    is_exploding: boolean
    exploded_for: number
    animate_explosion: boolean
end

function Item.new(item_type: ItemType, position: Point): Item
    local self: Item = setmetatable({}, { __index = Item })
    self.type = item_type
    self.position = position
    self.is_exploding = false
    self.exploded_for = 0
    self.animate_explosion = true
    return self
end

function Item:blow_up()
    self.is_exploding = true
end

function Item:draw()
    if self.is_exploding then
        return
    end

    local item_icon = item_icons[self.type]
    local y_draw = self.position.y - 9
    local x_draw = self.position.x - 1
	frame_animation:draw(x_draw, y_draw)
	lutro.graphics.draw(item_icon, x_draw, y_draw)
	lutro.graphics.draw(item_shadow, x_draw, y_draw)
end

function Item:update(dt: number)
    if self.is_exploding then
        self.exploded_for = self.exploded_for + dt
    end
end

function Item:is_destroyed(): boolean
    return self.exploded_for > ITEM_EXPLOSION_DURATION
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

function Items:possible_drop(available_spots: {Point})
    local item_drop_probability = 0.1
    if lutro.math.random() > item_drop_probability then
        return
    end

    local spot_to_drop = available_spots[lutro.math.random(#available_spots)]
    local items_that_can_drop: {ItemType} = {"speed", "bomb", "kick", "fire"}
    local item_to_drop = items_that_can_drop[lutro.math.random(#items_that_can_drop)]
    table.insert(self.on_ground, Item.new(item_to_drop, spot_to_drop))
end

function Items:update(dt: number)
    frame_animation:update(dt)
    for i, item in ipairs(self.on_ground) do
        item:update(dt)
        if item:is_destroyed() then
            table.remove(self.on_ground, i)
        end
    end
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

function Items:possible_pickup_by(player: Player)
    for i, item in ipairs(self.on_ground) do
        if item.position:in_radius_of(player.position, BLOCK_SIZE / 2) and not item.is_exploding then
            self:consumed_by_player(player, i)
        end
    end
end
