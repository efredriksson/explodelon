local points = require("engine.geometry.points")
local itertools = require("itertools")
local block_layouts = require("level_layout.block_layouts")
local grid = require("level_layout.grid")
local entities = require("level_layout.maps.entities")

local type MapLayout = entities.MapLayout
local type BlockType = entities.BlockType
local type Goal = entities.Goal
local type ConveyorBelt = entities.ConveyorBelt
local type Trampoline = entities.Trampoline
local type Point = points.Point

local record BouncingLayout is MapLayout
    get_conveyor_belts: function(self): {ConveyorBelt}
    get_goals: function(self): {Goal}
    get_trampolines: function(self): {Trampoline}
    conveyor_belts: {ConveyorBelt}
    goals: {Goal}
    trampolines: {Trampoline}
end

local function build_trampolines(): {Trampoline}
    local function trampoline_at(column: integer, row: integer): Trampoline
        return Trampoline.new(grid.get_tile_position(column, row))
    end

    return {
        trampoline_at(4, 1),
        trampoline_at(10, 1),
        trampoline_at(6, 4),
        trampoline_at(12, 4),
        trampoline_at(4, 6),
        trampoline_at(10, 6),
        trampoline_at(6, 9),
        trampoline_at(12, 9),
    }
end

function BouncingLayout.new(): BouncingLayout
    local self: BouncingLayout = setmetatable({}, {__index = BouncingLayout})
    self.conveyor_belts = {}
    self.goals = {}
    self.trampolines = build_trampolines()
    return self
end

function BouncingLayout:get_goals(): {Goal}
    return self.goals
end

function BouncingLayout:get_conveyor_belts(): {ConveyorBelt}
    return self.conveyor_belts
end

function BouncingLayout:get_trampolines(): {Trampoline}
    return self.trampolines
end

local function trampoline_position(trampoline: Trampoline): Point
    return trampoline.position
end

function BouncingLayout:get_block_layout(
    occupies: {Point}
): {integer: {integer: BlockType}}
    return block_layouts.grid(
        occupies, itertools.map(self:get_trampolines(), trampoline_position)
    )
end

function BouncingLayout:has_ice(): boolean
    return false
end

return BouncingLayout.new()
