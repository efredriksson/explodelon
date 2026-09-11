-- Item -> its lesson.

local choreography = require("preview.choreography")
local bomb = require("preview.options.bomb")
local fire = require("preview.options.fire")
local kick = require("preview.options.kick")
local lightning_bomb = require("preview.options.lightning_bomb")
local speed = require("preview.options.speed")
local scenery = require("preview.scenery")
local settings = require("settings")

local type Choreography = choreography.Choreography
local type ItemType = settings.ItemType
local type Scenery = scenery.Scenery

-- Needs a builder below.
local ROTATION: {ItemType} = {"bomb", "fire", "speed", "kick", "lightning_bomb"}

local scenery_builders: {ItemType: function(): Scenery} = {
    bomb = bomb.new_scenery,
    fire = fire.new_scenery,
    speed = speed.new_scenery,
    kick = kick.new_scenery,
    lightning_bomb = lightning_bomb.new_scenery,
}

local choreography_builders: {ItemType: function(): Choreography} = {
    bomb = bomb.new_choreography,
    fire = fire.new_choreography,
    speed = speed.new_choreography,
    kick = kick.new_choreography,
    lightning_bomb = lightning_bomb.new_choreography,
}

local options = {
    rotation = ROTATION,
}

function options.scenery_for(item: ItemType): Scenery
    return scenery_builders[item]()
end

function options.choreography_for(item: ItemType): Choreography
    return choreography_builders[item]()
end

return options
