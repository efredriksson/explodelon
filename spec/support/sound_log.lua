-- Counts how often each sound is played, for specs of when the game makes a sound.
--
--     require("spec.support.headless_lutro")(1)
--     local sound_log = require("spec.support.sound_log")
--     sound_log.install()                  -- before any load_assets()
--     sound_log.clear()
--     sound_log.played("kick")             -- times assets/sfx/kick.wav was played
local sound_log = {}

local plays = {}

local function new_source(path)
    local source = {}
    function source:play() plays[path] = (plays[path] or 0) + 1 end
    function source:stop() end
    function source:pause() end
    function source:isPlaying() return false end
    function source:isPaused() return false end
    function source:setVolume() end
    function source:setLooping() end
    function source:setPitch() end
    return source
end

function sound_log.install()
    lutro.audio.newSource = new_source
end

function sound_log.clear()
    plays = {}
end

function sound_log.played(name)
    return plays["assets/sfx/" .. name .. ".wav"] or 0
end

return sound_log
