--- The rules for the flames of one explosion: which tiles burn as time passes,
-- and how each one looks. Times are in seconds. Tiles are grid columns and
-- rows; the caller says what is on a tile through a `meets` function.
local vectors = require("engine.geometry.vectors")
local itertools = require("itertools")

local type Direction = vectors.Direction

-- The centre and the first ring light up together, this long after the bomb
-- goes off.
local FIRST_RING_TIME = 1 / 60
local RING_TIME = 2 / 60
local PHASE_TIME = 5 / 60
local PHASES = 4
local THINNING_TIME = PHASE_TIME * (PHASES - 1)
-- After the last ring the flame stays thick this long before it starts to thin.
local THICK_TIME_AT_FULL_LENGTH = 8 / 60
-- This long after the last ring every tile is drawn afresh, and once more
-- HANDOVER_TIME later.
local HANDOVER_TIME_AFTER_LAST_RING = 2 / 60
local HANDOVER_TIME = 1 / 60
-- The thinnest flame only hurts for this long as it appears.
local THINNEST_DEADLY_TIME = 1 / 60
-- The cracking bomb stays on the centre this long past the last ring.
local BURST_TIME_AFTER_LAST_RING = 5 / 60
local BURST_STAGE_TIMES: {number} = {7 / 60, 6 / 60}
local BURST_STAGES = #BURST_STAGE_TIMES + 1
local ARM_ORDER: {Direction} = {"right", "down", "left", "up"}

--- What a growing arm finds on the next tile.
local enum Meeting
    "passes" -- nothing there: the flame enters the tile and goes on
    "capped_before" -- a wall: the arm ends on the tile before, in an end cap
    "flat_before" -- something the flame joins or sets alight: the arm ends on the tile before, cut flat
    "ends_on" -- something the flame swallows: it covers the tile and ends there
end

local type Meets = function(i: integer, j: integer): Meeting

local enum Shape
    "center"
    "middle"
    "tip"
end

--- One burning tile.
local record Flame
    i: integer
    j: integer
    shape: Shape
    direction: Direction
    phase: integer
    deadly: boolean
    time_since_drawn: number
end

function Flame.new(
    i: integer,
    j: integer,
    shape: Shape,
    direction: Direction,
    phase: integer,
    deadly: boolean,
    time_since_drawn: number
): Flame
    local self: Flame = setmetatable({}, {__index = Flame})
    self.i = i
    self.j = j
    self.shape = shape
    self.direction = direction
    self.phase = phase
    self.deadly = deadly
    self.time_since_drawn = time_since_drawn
    return self
end

local record Arm
    direction: Direction
    length: integer
    stopped: boolean
    cut_flat: boolean
end

function Arm.new(direction: Direction): Arm
    local self: Arm = setmetatable({}, {__index = Arm})
    self.direction = direction
    self.length = 0
    self.stopped = false
    self.cut_flat = false
    return self
end

function Arm:shape_at(distance: integer): Shape
    if distance == self.length and not self.cut_flat then
        return "tip"
    end
    return "middle"
end

local record Explosion
    i: integer
    j: integer
    fire: integer
    age: number
    sustained_time: number
    sustains: boolean
    arms: {Arm}
end

local flames = {
    Explosion = Explosion,
    Flame = Flame,
    Meeting = Meeting,
    Meets = Meets,
    PHASES = PHASES,
    BURST_STAGES = BURST_STAGES,
}

--- An explosion centred on column i, row j, which goes off now unless it is to
-- start some seconds later.
function flames.new(
    i: integer, j: integer, fire: integer, seconds_later?: number
): Explosion
    local self: Explosion = setmetatable({}, {__index = Explosion})
    self.i = i
    self.j = j
    self.fire = fire
    self.age = -(seconds_later or 0)
    self.sustained_time = 0
    self.sustains = false
    self.arms = itertools.map(ARM_ORDER, Arm.new)
    return self
end

--- An explosion that keeps every explosion set off in its line of fire burning
-- until it fades itself.
function flames.new_sustaining(
    i: integer, j: integer, fire: integer, seconds_later?: number
): Explosion
    local self = flames.new(i, j, fire, seconds_later)
    self.sustains = true
    return self
end

function flames.growth_time(tiles: integer): number
    return tiles * RING_TIME
end

function Explosion:_ring_time(ring: integer): number
    return FIRST_RING_TIME + (ring - 1) * RING_TIME
end

function Explosion:_last_ring_time(): number
    return self:_ring_time(self.fire)
end

function Explosion:_handover_time(): number
    return self:_last_ring_time() + HANDOVER_TIME_AFTER_LAST_RING
end

--- How long the flame has been thinning; negative while it is still thick. A
-- sustained explosion grows on time and then stays thick for longer.
function Explosion:_thinning_for(): number
    local first_thin_time = self:_last_ring_time() + THICK_TIME_AT_FULL_LENGTH
    return self.age - self.sustained_time - first_thin_time
end

--- Tiles each arm may reach by now.
function Explosion:_radius(): integer
    local rings = math.floor((self.age - FIRST_RING_TIME) / RING_TIME) + 1
    return math.max(0, math.min(self.fire, rings))
end

--- 1 is the thick flame, PHASES the thinnest. Every tile of the explosion is in
-- the same phase, however early its arm was stopped.
function Explosion:phase(): integer
    local thinning_for = self:_thinning_for()
    if thinning_for < 0 then
        return 1
    end
    return math.min(PHASES, 2 + math.floor(thinning_for / PHASE_TIME))
end

function Explosion:is_over(): boolean
    return self:_thinning_for() >= THINNING_TIME
end

function Explosion:is_burning(): boolean
    return self.age >= FIRST_RING_TIME and not self:is_over()
end

function Explosion:_is_deadly(): boolean
    local thinnest_for = self:_thinning_for() - (THINNING_TIME - PHASE_TIME)
    return thinnest_for < THINNEST_DEADLY_TIME
end

--- A tile is redrawn on every ring while the explosion grows, twice at the
-- handover, and on every change of phase after that. Where two explosions share
-- a tile, the one that drew last is the one on screen.
function Explosion:_time_since_drawn(): number
    local handover_time = self:_handover_time()
    local thinning_for = self:_thinning_for()
    if self.age < handover_time then
        return self.age - self:_ring_time(self:_radius())
    elseif self.age < handover_time + HANDOVER_TIME then
        return self.age - handover_time
    elseif thinning_for < 0 then
        return self.age - handover_time - HANDOVER_TIME
    end
    return thinning_for % PHASE_TIME
end

--- Which stage of the cracking bomb to draw on the centre, or 0 for none.
function Explosion:burst_stage(): integer
    local burst_end = self:_last_ring_time() + BURST_TIME_AFTER_LAST_RING
    if self.age < 0 or self.age >= burst_end then
        return 0
    end
    local stage_end: number = 0
    for stage, stage_time in ipairs(BURST_STAGE_TIMES) do
        stage_end = stage_end + stage_time
        if self.age < stage_end then
            return stage
        end
    end
    return BURST_STAGES
end

function Explosion:_arm_tile(arm: Arm, distance: integer): integer, integer
    local step = vectors.from_direction(arm.direction)
    return self.i + math.floor(step.x) * distance,
        self.j + math.floor(step.y) * distance
end

function Explosion:_grow_arm(arm: Arm, meets: Meets)
    while not arm.stopped and arm.length < self:_radius() do
        local distance = arm.length + 1
        local meeting = meets(self:_arm_tile(arm, distance))
        if meeting == "passes" then
            arm.length = distance
        elseif meeting == "ends_on" then
            arm.length = distance
            arm.stopped = true
        else
            arm.stopped = true
            arm.cut_flat = meeting == "flat_before"
        end
    end
end

--- Between the two draws of the handover an arm that stopped short of its full
-- length shows without its end cap.
function Explosion:_shape_at(arm: Arm, distance: integer): Shape
    local since_handover = self.age - self:_handover_time()
    local in_handover = since_handover >= 0 and since_handover < HANDOVER_TIME
    if in_handover and arm.length < self.fire then
        return "middle"
    end
    return arm:shape_at(distance)
end

function Explosion:has_in_line_of_fire(i: integer, j: integer): boolean
    local in_row = j == self.j and math.abs(i - self.i) <= self.fire
    local in_column = i == self.i and math.abs(j - self.j) <= self.fire
    return in_row or in_column
end

--- Stays thick until `other` thins, then thins and goes out in step with it,
-- unless it outlasts `other` as it is. It sustains in turn, so a chain set off
-- through it lasts as long.
function Explosion:burn_as_long_as(other: Explosion)
    local outlasted_by = self:_thinning_for() - other:_thinning_for()
    self.sustained_time = self.sustained_time + math.max(0, outlasted_by)
    self.sustains = true
end

--- Lets `dt` seconds pass and every arm grow into the rings it has reached. An
-- arm that has been stopped stays stopped, even if what stopped it goes away.
function Explosion:advance(dt: number, meets: Meets)
    self.age = self.age + dt
    for _, arm in ipairs(self.arms) do
        self:_grow_arm(arm, meets)
    end
end

function Explosion:flames(): {Flame}
    if not self:is_burning() then
        return {}
    end
    local phase = self:phase()
    local deadly = self:_is_deadly()
    local time_since_drawn = self:_time_since_drawn()
    local burning: {Flame} = {
        Flame.new(self.i, self.j, "center", nil, phase, deadly, time_since_drawn),
    }
    for _, arm in ipairs(self.arms) do
        for distance = 1, arm.length do
            local i, j = self:_arm_tile(arm, distance)
            local shape = self:_shape_at(arm, distance)
            table.insert(
                burning,
                Flame.new(i, j, shape, arm.direction, phase, deadly, time_since_drawn)
            )
        end
    end
    return burning
end

return flames
