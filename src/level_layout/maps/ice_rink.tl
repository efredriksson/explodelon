local points = require("engine.geometry.points")
local block_layouts = require("level_layout.block_layouts")
local entities = require("level_layout.maps.entities")

local type MapLayout = entities.MapLayout
local type BlockType = entities.BlockType
local type Goal = entities.Goal
local type ConveyorBelt = entities.ConveyorBelt
local type Trampoline = entities.Trampoline
local type Point = points.Point

local record IceRinkLayout is MapLayout
    get_conveyor_belts: function(self): {ConveyorBelt}
    get_goals: function(self): {Goal}
    get_trampolines: function(self): {Trampoline}
    conveyor_belts: {ConveyorBelt}
    goals: {Goal}
    trampolines: {Trampoline}
end

function IceRinkLayout.new(): IceRinkLayout
    local self: IceRinkLayout = setmetatable({}, {__index = IceRinkLayout})
    self.conveyor_belts = {}
    self.goals = {}
    self.trampolines = {}
    return self
end

function IceRinkLayout:get_goals(): {Goal}
    return self.goals
end

function IceRinkLayout:get_conveyor_belts(): {ConveyorBelt}
    return self.conveyor_belts
end

function IceRinkLayout:get_trampolines(): {Trampoline}
    return self.trampolines
end

function IceRinkLayout:get_block_layout(
    occupies: {Point}
): {integer: {integer: BlockType}}
    return block_layouts.quadrant(occupies)
end

function IceRinkLayout:has_ice(): boolean
    return true
end

return IceRinkLayout.new()
