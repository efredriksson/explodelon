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

return settings
