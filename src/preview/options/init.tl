-- Item -> its lesson.

local choreography = require("preview.choreography")
local bomb = require("preview.options.bomb")
local fire = require("preview.options.fire")
local kick = require("preview.options.kick")
local scenery = require("preview.scenery")
local settings = require("settings")

local type Choreography = choreography.Choreography
local type ItemType = settings.ItemType
local type Scenery = scenery.Scenery

-- Needs a builder below.
local ROTATION: {ItemType} = {"bomb", "fire", "kick"}

local scenery_builders: {ItemType: function(): Scenery} = {
    bomb = bomb.new_scenery,
    fire = fire.new_scenery,
    kick = kick.new_scenery,
}

local choreography_builders: {ItemType: function(): Choreography} = {
    bomb = bomb.new_choreography,
    fire = fire.new_choreography,
    kick = kick.new_choreography,
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
