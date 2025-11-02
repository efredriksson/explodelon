local audio = {}
local loaded_audio_sources: {Source} = {}

function audio.new_source(filename: string, source_type: SourceType): Source
    local new_source = lutro.audio.newSource(filename, source_type)
    table.insert(loaded_audio_sources, new_source)
    return new_source
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

return audio
