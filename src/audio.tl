local audio = {}
local loaded_audio_sources: {Source} = {}

local record SourcePool is Source
   delegates: {Source}
end

function SourcePool.new(delegates: {Source}): SourcePool
   local self: SourcePool = setmetatable({}, { __index = SourcePool })
   self.delegates = delegates
   return self
end

function SourcePool:setVolume(volume: number)
    for _, source in ipairs(self.delegates) do
        source:setVolume(volume)
    end
end

function SourcePool:setLooping(loop: boolean)
    for _, source in ipairs(self.delegates) do
        source:setLooping(loop)
    end
end

function SourcePool:setPitch(pitch: number)
    for _, source in ipairs(self.delegates) do
        source:setPitch(pitch)
    end
end

function SourcePool:play()
    for _, source in ipairs(self.delegates) do
        if not source:isPlaying() then
            -- Found a source in pool not yet playing!
            source:play()
            return
        end
    end
end

function SourcePool:pause()
    assert(false, "Not implemented")
end

function SourcePool:stop()
    assert(false, "Not implemented")
end

function SourcePool:isPlaying(): boolean
    assert(false, "Not implemented")
end

function SourcePool:isPaused(): boolean
    assert(false, "Not implemented")
end

function audio.new_source(filename: string, source_type: SourceType): Source
    local new_source = lutro.audio.newSource(filename, source_type)
    table.insert(loaded_audio_sources, new_source)
    return new_source
end

-- For audio that can be played many times at same time.
-- Should only be used for short audio as memory consumption could be very hight otherwise.
function audio.new_source_pool(filename: string, source_type: SourceType, pool_size: integer): Source
    local in_pool: {Source} = {}
    for _=1, pool_size do
        local new_source = lutro.audio.newSource(filename, source_type)
        table.insert(in_pool, new_source)
        table.insert(loaded_audio_sources, new_source)
    end
    return SourcePool.new(in_pool)
end

function audio.pause()
    for _, source in ipairs(loaded_audio_sources) do
        if source:isPlaying() then
            source:pause()
        end
    end
end

function audio.unpause()
    for _, source in ipairs(loaded_audio_sources) do
        if source:isPaused() then
            source:play()
        end
    end
end

function audio.stop()
    for _, source in ipairs(loaded_audio_sources) do
        if source:isPlaying() then
            source:stop()
        end
    end
end

return audio
