-- Item -> its lesson.

local choreography = require("preview.choreography")
local bomb = require("preview.options.bomb")
local dino_blue = require("preview.options.dino_blue")
local dino_green = require("preview.options.dino_green")
local dino_pink = require("preview.options.dino_pink")
local egg = require("preview.options.egg")
local fire = require("preview.options.fire")
local kick = require("preview.options.kick")
local lightning_bomb = require("preview.options.lightning_bomb")
local speed = require("preview.options.speed")
local scenery = require("preview.scenery")

local type Choreography = choreography.Choreography
local type Scenery = scenery.Scenery

-- ItemType's members, plus "egg" and one "dino_<color>" per enabled-able dino.
local type PreviewSubject = enum
    "speed"
    "bomb"
    "kick"
    "fire"
    "lightning_bomb"
    "egg"
    "dino_blue"
    "dino_pink"
    "dino_green"
end

-- Needs a builder below.
local ROTATION: {PreviewSubject} = {
    "bomb",
    "fire",
    "speed",
    "kick",
    "lightning_bomb",
    "egg",
    "dino_blue",
    "dino_pink",
    "dino_green",
}

local scenery_builders: {PreviewSubject: function(): Scenery} = {
    bomb = bomb.new_scenery,
    fire = fire.new_scenery,
    speed = speed.new_scenery,
    kick = kick.new_scenery,
    lightning_bomb = lightning_bomb.new_scenery,
    egg = egg.new_scenery,
    dino_blue = dino_blue.new_scenery,
    dino_pink = dino_pink.new_scenery,
    dino_green = dino_green.new_scenery,
}

local choreography_builders: {PreviewSubject: function(): Choreography} = {
    bomb = bomb.new_choreography,
    fire = fire.new_choreography,
    speed = speed.new_choreography,
    kick = kick.new_choreography,
    lightning_bomb = lightning_bomb.new_choreography,
    egg = egg.new_choreography,
    dino_blue = dino_blue.new_choreography,
    dino_pink = dino_pink.new_choreography,
    dino_green = dino_green.new_choreography,
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
