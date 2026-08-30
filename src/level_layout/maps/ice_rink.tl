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
end

function IceRinkLayout.new(): IceRinkLayout
    local self: IceRinkLayout = setmetatable({}, {__index = IceRinkLayout})
    return self
end

function IceRinkLayout:get_goals(): {Goal}
    return {}
end

function IceRinkLayout:get_conveyor_belts(): {ConveyorBelt}
    return {}
end

function IceRinkLayout:get_trampolines(): {Trampoline}
    return {}
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
