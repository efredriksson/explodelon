local choreography = require("preview.choreography")
local bouncing = require("preview.maps.bouncing")
local factory = require("preview.maps.factory")
local football = require("preview.maps.football")
local ice_rink = require("preview.maps.ice_rink")
local scenery = require("preview.scenery")
local settings = require("settings")

local type Choreography = choreography.Choreography
local type Map = settings.Map
local type Scenery = scenery.Scenery

local maps = {}

local scenery_builders <total>: {Map: function(): Scenery} = {
    football = football.new_scenery,
    factory = factory.new_scenery,
    ice_rink = ice_rink.new_scenery,
    bouncing = bouncing.new_scenery,
}

local choreography_builders <total>: {Map: function(): Choreography} = {
    football = football.new_choreography,
    factory = factory.new_choreography,
    ice_rink = ice_rink.new_choreography,
    bouncing = bouncing.new_choreography,
}

function maps.scenery_for(map: Map): Scenery
    return scenery_builders[map]()
end

function maps.choreography_for(map: Map): Choreography
    return choreography_builders[map]()
end

return maps
