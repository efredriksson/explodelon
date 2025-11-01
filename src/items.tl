require("entity")
require("geometry.points")
require("players")
local animations = require("animations")
local const = require("const")
local itertools = require("itertools")

local take_item_sound: Source
local frame_animation: Animation
local item_shadow: Image
local item_icons: {ItemType: Image}

global record Item is Entity, ExplosionBlocking, Explodable
    type: ItemType
    position: Point
    is_exploding: boolean
    in_explosion: boolean
end

function Item.new(item_type: ItemType, position: Point): Item
    local self: Item = setmetatable({}, { __index = Item })
    self.type = item_type
    self.position = position
    self.is_exploding = false
    self.in_explosion = true
    return self
end

function Item:get_position(): Point
    return self.position
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

function Item:is_destroyed(): boolean
    return self.is_exploding
end

global record Items
    on_ground: {Item}
    by_players: {integer: {ItemType}}
end

local items = {}

function items.new(): Items
   local self: Items = setmetatable({}, { __index = Items })
   self.on_ground = {}
   self.by_players = {}
   return self
end

global function get_random_item(): ItemType
    local items_that_can_drop: {ItemType} = {"speed", "bomb", "kick", "fire"}
    return items_that_can_drop[lutro.math.random(#items_that_can_drop)]
end

function Items:drop_at(position: Point, item: ItemType)
    table.insert(self.on_ground, Item.new(item, position))
end

function Items:update(dt: number)
    frame_animation:update(dt)
    for i, item in ipairs(self.on_ground) do
        if item:is_destroyed() then
            table.remove(self.on_ground, i)
        end
    end
end

function Items:drop_items_of(players: {Player}, available_spots: {Point})
    local max_items_to_drop = 5

    for _, player in ipairs(players) do
        if self.by_players[player.id] then
            local shuffled_items = itertools.shuffle(self.by_players[player.id])
            self.by_players[player.id] = nil
            for i, item in ipairs(shuffled_items) do
                if i <= max_items_to_drop then
                   local spot_to_drop = available_spots[lutro.math.random(#available_spots)]
                   self:drop_at(spot_to_drop, item)
                end
            end
        end
    end
end

function Items:consumed_by_player(player: Player, index: integer)
    lutro.audio.play(take_item_sound)

    local item = table.remove(self.on_ground, index)
    if self.by_players[player.id] == nil then
        self.by_players[player.id] = {}
    end
    table.insert(self.by_players[player.id], item.type)
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
        if item.position:in_radius_of(player.position, const.BLOCK_SIZE / 2) and not item.is_exploding then
            self:consumed_by_player(player, i)
        end
    end
end


function Items:load_assets()
    take_item_sound = lutro.audio.newSource("assets/take_item.wav", "static")
    take_item_sound:setVolume(0.25)
    frame_animation = animations.new(lutro.graphics.newImage("assets/items/frame.png"), 18, 18, 1, 30)
	item_shadow = lutro.graphics.newImage("assets/items/shadow.png")
	item_icons = {
        ["speed"] = lutro.graphics.newImage("assets/items/speed.png"),
        ["bomb"] = lutro.graphics.newImage("assets/items/bomb.png"),
        ["kick"] = lutro.graphics.newImage("assets/items/kick.png"),
        ["fire"] = lutro.graphics.newImage("assets/items/fire.png"),
    }
end

return items
