require("const")
require("geometry")
require("entity")
require("animation")
require("dinos")

local egg_shake_image: Image
local egg_open_image: Image

global record Egg is Entity, ExplosionBlocking, Explodable
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
    self.animation = Animation.new(egg_shake_image, 20, 26, 3, 18, 2)
    return self
end

function Egg:get_position(): Point
    return self.position
end

local function convert_pos_for_egg_draw(animation: Animation, pos: Point): Point
	return Point.new(pos.x + (BLOCK_SIZE - animation.width) / 2, pos.y + BLOCK_SIZE - animation.height)
end

function Egg:open()
    self.breaking = true
    self.animation = Animation.new(egg_open_image, 34, 34, 3, 18, 0.5)
end

function Egg:blow_up()
    self.is_exploding = true
end

function Egg:draw()
    if self.is_exploding then
        return
    end

    local draw_pos = convert_pos_for_egg_draw(self.animation, self.position)
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

function Eggs.new(): Eggs
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

function Eggs:possible_hatcher_at(player_position: Point, player_dir: Direction): Dino
    for _, egg in ipairs(self.on_ground) do
        if egg.position:in_radius_of(player_position, BLOCK_SIZE / 2) then
			if not egg.breaking and not egg.is_exploding then
				egg:open()
                return Dino.new(egg.position, player_dir)
			end
        end
    end

    return nil
end

function Eggs.load_assets()
    egg_shake_image = lutro.graphics.newImage("assets/tirras/egg.png")
    egg_open_image = lutro.graphics.newImage("assets/tirras/egg_open.png")
end
