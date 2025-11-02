

global type CharacterSprite = enum
    "kotetsu"
    "honey"
    "kinu" 
    "milon"
    "black" 
    "white" 
    "kabuki" 
    "master_higins" 
    "manjimaru" 
    "bonks" 
end

local ALL_SPRITES: {CharacterSprite} = {
    "kotetsu",
    "honey",
    "kinu",
    "milon",
    "black",
    "white",
    "kabuki",
    "master_higins",
    "manjimaru",
    "bonks",
}

local character_sprites = {}

global record CharacterSelection
    player_id: integer
    sprite: CharacterSprite
end


function character_sprites.new_selection(
    player_id: integer,
    sprite: CharacterSprite
): CharacterSelection
    local self: CharacterSelection = setmetatable({}, { __index = CharacterSelection })
    self.player_id = player_id
    self.sprite = sprite
    return self
end


function character_sprites.get(nbr_to_get?: integer): {CharacterSprite}
    local sprites: {CharacterSprite} = {}
    for i, sprite in ipairs(ALL_SPRITES) do
        if not nbr_to_get or i <= nbr_to_get then
            table.insert(sprites, sprite)
        end
    end

    return sprites
end

function character_sprites.get_selections(nbr_to_get?: integer): {CharacterSelection}
    local selections: {CharacterSelection} = {}
    for i, sprite in ipairs(character_sprites.get(nbr_to_get)) do
        table.insert(selections, character_sprites.new_selection(i, sprite))
    end

    return selections
end

function character_sprites.is_unused(sprite: CharacterSprite, already_selected: {CharacterSelection}): boolean
    assert(#already_selected < #ALL_SPRITES, "All sprites are selected!")
    for _, selected in ipairs(already_selected) do
        if sprite == selected.sprite then
            return false
        end
    end

    return true
end

function character_sprites.get_unused(already_selected: {CharacterSelection}): CharacterSprite
    assert(#already_selected < #ALL_SPRITES, "All sprites are selected!")

    for _, sprite in ipairs(character_sprites.get()) do
		if character_sprites.is_unused(sprite, already_selected) then
			return sprite
		end     
    end
end

return character_sprites
