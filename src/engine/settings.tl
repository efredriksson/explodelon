local record EngineSettings
    draw_hitboxes: boolean
    log_scene_perf: boolean
    block_size: integer -- Used for default hitbox size and fast collision detection
end

function EngineSettings.new(): EngineSettings
    local self: EngineSettings = setmetatable({}, { __index = EngineSettings })
    self.draw_hitboxes = false
    self.log_scene_perf = false
    self.block_size = 32
    return self
end

local settings = EngineSettings.new()

function EngineSettings.set_draw_hitboxs(value: boolean)
    settings.draw_hitboxes = value
end

function EngineSettings.set_log_scene_perf(value: boolean)
    settings.log_scene_perf = value
end

function EngineSettings.set_block_size(value: integer)
    settings.block_size = value
end

local record LutroFeatures
    HAVE_COMPOSITION: boolean
    HAVE_TRANSFORM: boolean
    HAVE_INOTIFY: boolean
    HAVE_JIT: boolean
    HAVE_LUASOCKET: boolean
    HAVE_16_JOYSTICKS: boolean
end

function EngineSettings.get_features(): LutroFeatures
    -- featureflags can be nil if an old version, then no
    -- features are expected to exist (nil but same as false).
    local features = lutro.featureflags
    if features == nil then
        return {}
    end

    -- Cast as record, any features not existing are assumed to
    -- not exist and is nil and will work as false.
    return features as LutroFeatures
end

return settings
