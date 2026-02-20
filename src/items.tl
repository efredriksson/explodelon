local animations = require("engine.animations")
local audio = require("engine.audio")
local itertools = require("itertools")
local hitboxes = require("engine.hitboxes")
local players = require("players")
local points = require("engine.geometry.points")
local rectangles = require("engine.geometry.rectangles")
local settings = require("settings")
local z_index = require("z_index")

local type Animation = animations.Animation
local type Explodable = require("bombs.explodable")
local type Entity = require("engine.entity")
local type Player = players.Player
local type Point = points.Point
local type Rectangle = rectangles.Rectangle
local type ItemType = settings.ItemType

local take_item_sound: Source
local frame_animation: Animation
local item_shadow: Image
local item_icons: {ItemType: Image}

local record Item is Entity, Explodable
    type: ItemType
    position: Point
    is_exploding: boolean
    in_explosion: boolean
end

function Item.new(item_type: ItemType, position: Point): Item
    local self: Item = setmetatable({}, { __index = Item })
    self.type = item_type
    self.position = position
    self.z_index = z_index.LEVEL
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

function Item:hitbox(): Rectangle
	return hitboxes.new_block(self.position):shrink(4)
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

local record Items
    on_ground: {Item}
    by_players: {integer: {ItemType}}
end

local items = {Items = Items}

function items.new(): Items
   local self: Items = setmetatable({}, { __index = Items })
   self.on_ground = {}
   self.by_players = {}
   return self
end

function Items:possible_drop(available_spots: {Point})
    if #available_spots == 0 then
        return
    end
    local item_spawns: {ItemType} = {}
    local spawn_rates = settings.game_rules.items.spawn_rates
    if lutro.math.random() < spawn_rates.speed then
        table.insert(item_spawns, "speed")
    end
    if lutro.math.random() < spawn_rates.bomb then
        table.insert(item_spawns, "bomb")
    end
    if lutro.math.random() < spawn_rates.lightning_bomb then
        table.insert(item_spawns, "lightning_bomb")
    end
    if lutro.math.random() < spawn_rates.fire then
        table.insert(item_spawns, "fire")
    end
    if lutro.math.random() < spawn_rates.kick then
        table.insert(item_spawns, "kick")
    end

    for _, item_spawn in ipairs(item_spawns) do
        local spot_to_drop = available_spots[lutro.math.random(#available_spots)]
        table.insert(self.on_ground, Item.new(item_spawn, spot_to_drop))
    end
end

function Items:drop_at(position: Point, item: ItemType)
    table.insert(self.on_ground, Item.new(item, position))
end

function Items:update(dt: number)
    frame_animation:update(dt)
    for i = #self.on_ground, 1, -1 do
        local item = self.on_ground[i]
        if item:is_destroyed() then
            table.remove(self.on_ground, i)
        end
    end
end

function Items:drop_items_of(players_: {Player}, available_spots: {Point})
    local max_items_to_drop = 5

    for _, player in ipairs(players_) do
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
    take_item_sound:play()

    local item = table.remove(self.on_ground, index)
    if self.by_players[player.id] == nil then
        self.by_players[player.id] = {}
    end
    table.insert(self.by_players[player.id], item.type)
    if item.type == "speed" then
        player.speed = player.speed + 5
    elseif item.type == "bomb" then
        player.bombs = player.bombs + 1
    elseif item.type == "lightning_bomb" then
        player.lightning_bomb = player.lightning_bomb + 1
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
        if player:hitbox():overlap(item:hitbox()) then
            self:consumed_by_player(player, i)
        end
    end
end


function items.load_assets()
    take_item_sound = audio.new_source_pool("assets/take_item.wav", "static", 5)
    take_item_sound:setVolume(0.75)
    frame_animation = animations.new(lutro.graphics.newImage("assets/items/frame.png"), 18, 1 / 30)
	item_shadow = lutro.graphics.newImage("assets/items/shadow.png")
	item_icons = {
        speed = lutro.graphics.newImage("assets/items/speed.png"),
        bomb = lutro.graphics.newImage("assets/items/bomb.png"),
        lightning_bomb = lutro.graphics.newImage("assets/items/lightning-bomb.png"),
        kick = lutro.graphics.newImage("assets/items/kick.png"),
        fire = lutro.graphics.newImage("assets/items/fire.png"),
    }
end

return items
