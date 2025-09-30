-- This module is a Teal implementation of the anim.lua library
-- from https://lutro.libretro.com/doc/usefullibs.html

global record Animation
	image: Image
    timer: number
	width: number
    height: number
    playing: boolean
    period: number
    speed: number
    steps: number
    idle_time: number
    idle_timer: number
end

function Animation.new(image: Image, width: number, height: number, period: number, speed: number, idle_time?: number): Animation
    local self: Animation = setmetatable({}, { __index = Animation })
    self.image = image
    self.timer = 0
    self.width = width
    self.height = height
    self.playing = true
    self.speed = speed
    self.period = period
    self.steps = self.image:getWidth() / self.width
    self.idle_time = idle_time or 0
    self.idle_timer = self.idle_time
    return self
end

function Animation:update(dt: number)
    if not self.playing then
        return
    end

    if self.idle_timer >= 0 then
        self.idle_timer = self.idle_timer - dt
        return
    end

    self.timer = self.timer + dt * self.speed

    if self.timer > self.steps * self.period then
        self.timer = 0
        self.idle_timer = self.idle_time
    end
end

function Animation:draw(x: number, y: number)
    local id = math.floor(self.timer / self.period + 1)
    local tw = self.width
    local th = self.height
    local sw = self.image:getWidth()
    local sh = self.image:getHeight()

    local q = lutro.graphics.newQuad(
        ((id-1)%(sw/tw))*tw,
        0,
        tw, th,
        sw, sh)

    lutro.graphics.draw(
        self.image,
        q,
        math.floor(x), math.floor(y)
    )
end