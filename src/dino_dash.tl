--- The green dino's dash.
local vectors = require("engine.geometry.vectors")
local itertools = require("itertools")

local type Direction = vectors.Direction

--- The dash has a fixed speed whatever the rider's own.
local DASH_SPEED_BY_LEVEL: {integer: number} = {
    [1] = 120,
    [2] = 180,
    [3] = 240,
}

--- The lowest level that brakes on reverse instead of crashing into walls, and
-- the one that also steers.
local BRAKING_LEVEL = 2
local STEERING_LEVEL = 3

--- Part of a brake: a steady speed kept for some time.
local record BrakeStage
    speed: number
    duration: number
end

function BrakeStage.new(speed: number, duration: number): BrakeStage
    local self: BrakeStage = setmetatable({}, {__index = BrakeStage})
    self.speed = speed
    self.duration = duration
    return self
end

--- A brake slows the dash in steps that leave a level 2 dino sliding 2 tiles
-- and a level 3 one 3 tiles. It then stands still until BRAKE_TIME is up.
local BRAKE_STAGES_BY_LEVEL: {integer: {BrakeStage}} = {
    [2] = {
        BrakeStage.new(120, 10 / 60),
        BrakeStage.new(60, 0.2),
    },
    [3] = {
        BrakeStage.new(180, 8 / 60),
        BrakeStage.new(120, 8 / 60),
        BrakeStage.new(60, 8 / 60),
    },
}

local function brake_distance(level: integer, elapsed: number): number
    local distance: number = 0
    local stage_start: number = 0
    for _, stage in ipairs(BRAKE_STAGES_BY_LEVEL[level] or {}) do
        local time_in_stage = math.max(
            0, math.min(elapsed - stage_start, stage.duration)
        )
        distance = distance + time_in_stage * stage.speed
        stage_start = stage_start + stage.duration
    end
    return distance
end

local dino_dash = {
    BRAKE_TIME = 0.5,
    -- A level 1 dino that dashes into something leaves its rider stuck while it
    -- shakes off the crash.
    CRASH_STUN_TIME = 52 / 60,
}

function dino_dash.speed(level: integer): number
    return DASH_SPEED_BY_LEVEL[level]
end

function dino_dash.can_brake(level: integer): boolean
    return level >= BRAKING_LEVEL
end

function dino_dash.crashes(level: integer): boolean
    return not dino_dash.can_brake(level)
end

function dino_dash.can_steer(level: integer): boolean
    return level >= STEERING_LEVEL
end

--- Speed `elapsed` seconds into a brake.
function dino_dash.brake_speed(level: integer, elapsed: number): number
    local stage_end: number = 0
    for _, stage in ipairs(BRAKE_STAGES_BY_LEVEL[level] or {}) do
        stage_end = stage_end + stage.duration
        if elapsed < stage_end then
            return stage.speed
        end
    end
    return 0
end

--- Mean speed over the `dt` seconds that follow `elapsed` seconds into a brake.
-- A step can straddle the moment a brake slows down, and the brake must slide
-- as far whatever the step.
function dino_dash.brake_speed_over(level: integer, elapsed: number, dt: number): number
    local slid = brake_distance(level, elapsed + dt) - brake_distance(level, elapsed)
    return slid / dt
end

function dino_dash.is_reversing(facing: Direction, held: {Direction}): boolean
    local function against_facing(direction: Direction): boolean
        return direction == vectors.opposite(facing)
    end
    return itertools.count(held, against_facing) > 0
end

--- What a dashing rider effectively holds: always the way the dash goes, and at
-- the top level also what they steer with, so turns follow the walking rules.
function dino_dash.directions(
    facing: Direction, level: integer, held: {Direction}, braking: boolean
): {Direction}
    if braking or not dino_dash.can_steer(level) then
        return {facing}
    end
    local dash_line = vectors.from_direction(facing)
    local function steers(direction: Direction): boolean
        return vectors.from_direction(direction):orthogonal(dash_line)
    end
    return itertools.combine({facing}, itertools.filter(held, steers))
end

return dino_dash
