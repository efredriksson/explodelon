-- Item -> its lesson.

local choreography = require("preview.choreography")
local bomb = require("preview.options.bomb")
local egg = require("preview.options.egg")
local fire = require("preview.options.fire")
local kick = require("preview.options.kick")
local lightning_bomb = require("preview.options.lightning_bomb")
local speed = require("preview.options.speed")
local scenery = require("preview.scenery")

local type Choreography = choreography.Choreography
local type Scenery = scenery.Scenery

-- ItemType's members, plus "egg".
local type PreviewSubject = enum
    "speed"
    "bomb"
    "kick"
    "fire"
    "lightning_bomb"
    "egg"
end

-- Needs a builder below.
local ROTATION: {PreviewSubject} = {
    "bomb", "fire", "speed", "kick", "lightning_bomb", "egg"
}

local scenery_builders: {PreviewSubject: function(): Scenery} = {
    bomb = bomb.new_scenery,
    fire = fire.new_scenery,
    speed = speed.new_scenery,
    kick = kick.new_scenery,
    lightning_bomb = lightning_bomb.new_scenery,
    egg = egg.new_scenery,
}

local choreography_builders: {PreviewSubject: function(): Choreography} = {
    bomb = bomb.new_choreography,
    fire = fire.new_choreography,
    speed = speed.new_choreography,
    kick = kick.new_choreography,
    lightning_bomb = lightning_bomb.new_choreography,
    egg = egg.new_choreography,
}

local options = {
    PreviewSubject = PreviewSubject,
    rotation = ROTATION,
}

function options.scenery_for(subject: PreviewSubject): Scenery
    return scenery_builders[subject]()
end

function options.choreography_for(subject: PreviewSubject): Choreography
    return choreography_builders[subject]()
end

return options
