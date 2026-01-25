require("engine.entity")
require("kinematic")
require("players")
local animations = require("engine.animations")
local dinos = require("dinos")
local grid = require("level_layout.grid")
local hitboxes = require("engine.hitboxes")
local points = require("engine.geometry.points")

local egg_shake_image: Image
local egg_open_image: Image

global record Egg is Entity, Explodable
    position: Point
    breaking: boolean
    hatched: boolean
    is_exploding: boolean
    in_explosion: boolean
    animation: Animation
end

function Egg.new(position: Point): Egg
    local self: Egg = setmetatable({}, { __index = Egg })
    self.position = position
    self.breaking = false
    self.hatched = false
    self.is_exploding = false
    self.in_explosion = true
    self.animation = animations.new(egg_shake_image, 20, 1 / 6, 2)
    return self
end

function Egg:get_position(): Point
    return self.position
end

function Egg:get_position_to_draw_egg(): Point
	return points.new(
        self.position.x + (grid.TILE_SIZE - self.animation.width) / 2,
        self.position.y + grid.TILE_SIZE - self.animation.height
    )
end

function Egg:open()
    self.breaking = true
    self.animation = animations.new(egg_open_image, 34, 1 / 6, 0.5)
end

function Egg:blow_up()
    self.is_exploding = true
end

function Egg:hitbox(): Rectangle
	return hitboxes.new_block(self.position):shrink(4)
end

function Egg:draw()
    if self.is_exploding then
        return
    end

    local draw_pos = self:get_position_to_draw_egg()
	self.animation:draw(draw_pos.x, draw_pos.y)
end

function Egg:update(dt: number)
    self.animation:update(dt)
    if self.breaking and self.animation.loops > 0 then
        -- After one animation cycle as 'breaking' the egg have hatched
        self.hatched = true
    end
end

function Egg:is_destroyed(): boolean
    return self.is_exploding
end

global record Eggs
    on_ground: {Egg}
end

local eggs = {}

function eggs.new(): Eggs
   local self: Eggs = setmetatable({}, { __index = Eggs })
   self.on_ground = {}
   return self
end

function Eggs:update(dt: number)
    for i, egg in ipairs(self.on_ground) do
        egg:update(dt)
        if egg.hatched or egg:is_destroyed() then
            table.remove(self.on_ground, i)
        end
    end
end

function Eggs:spawn_at(position: Point)
    table.insert(self.on_ground, Egg.new(position))
end

function Eggs:possible_hatcher(player: Player): Dino
    for _, egg in ipairs(self.on_ground) do
        if player:hitbox():overlap(egg:hitbox()) then
			if not egg.breaking and not egg.is_exploding then
				egg:open()
                return dinos.new(egg.position, player.direction)
			end
        end
    end

    return nil
end

function Eggs.load_assets()
    egg_shake_image = lutro.graphics.newImage("assets/tirras/egg.png")
    egg_open_image = lutro.graphics.newImage("assets/tirras/egg_open.png")
end

return eggs
