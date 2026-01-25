-- This module is a Teal implementation of the anim.lua library
-- from https://lutro.libretro.com/doc/usefullibs.html
local logging = require("engine.logger")


global record Animation
	image: Image
    timer: number
	width: number
    height: number
    playing: boolean
    frame_durations: {number}
    total_time: number
    steps: number
    loops: number
end

local animations = {}

function animations.new_with_frames(image: Image, frame_durations: {number}): Animation
    local self: Animation = setmetatable({}, { __index = Animation })
    self.image = image
    self.timer = 0
    self.width = image:getWidth() / #frame_durations
    self.height = image:getHeight()
    self.playing = true
    self.frame_durations = frame_durations
    self.steps = self.image:getWidth() / self.width
    self.loops = 0

    self.total_time = 0
    for _, frame_duration in ipairs(self.frame_durations) do
        self.total_time = self.total_time + frame_duration
    end

    return self
end

function animations.new(image: Image, width: number, frame_duration: number, idle_time?: number): Animation
    local steps = image:getWidth() / width
    
    local frame_durations: {number} = {}
    for _=1, steps do
        table.insert(frame_durations, frame_duration)
    end
    frame_durations[1] = frame_durations[1] + (idle_time or 0)
    return animations.new_with_frames(image, frame_durations)
end

function Animation:reset()
    self.timer = 0
    self.playing = true
    self.loops = 0
end

function Animation:scale_frame_durations(scale: number)
    self.total_time = 0
    for i, frame_duration in ipairs(self.frame_durations) do
        self.frame_durations[i] = frame_duration * scale
        self.total_time = self.total_time + self.frame_durations[i]
    end 
end

function Animation:_get_frame(): integer
    local clamped_time = self.timer
    for frame, frame_duration in ipairs(self.frame_durations) do
        if clamped_time <= frame_duration then
            return frame
        end
        clamped_time = clamped_time - frame_duration
    end

    logging.warning("Could not find frame for time, using last frame") 
    return #self.frame_durations
end

function Animation:update(dt: number)
    if not self.playing then
        return
    end

    self.timer = self.timer + dt
    if self.timer > self.total_time then
        self.timer = 0
        self.loops = self.loops + 1
    end
end

function Animation:draw(x: number, y: number)
    local id = self:_get_frame()
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
        x, y
    )
end

return animations
