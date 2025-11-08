

global type CharacterName = enum
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

local ALL_SPRITES: {CharacterName} = {
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

local characters = {}

global record CharacterSelection
    player_id: integer
    sprite: CharacterName
end


function characters.new_selection(
    player_id: integer,
    sprite: CharacterName
): CharacterSelection
    local self: CharacterSelection = setmetatable({}, { __index = CharacterSelection })
    self.player_id = player_id
    self.sprite = sprite
    return self
end


function characters.get_names(nbr_to_get?: integer): {CharacterName}
    local sprites: {CharacterName} = {}
    for i, sprite in ipairs(ALL_SPRITES) do
        if not nbr_to_get or i <= nbr_to_get then
            table.insert(sprites, sprite)
        end
    end

    return sprites
end

function characters.get_selections(nbr_to_get?: integer): {CharacterSelection}
    local selections: {CharacterSelection} = {}
    for i, sprite in ipairs(characters.get_names(nbr_to_get)) do
        table.insert(selections, characters.new_selection(i, sprite))
    end

    return selections
end

function characters.is_unused(sprite: CharacterName, already_selected: {CharacterSelection}): boolean
    assert(#already_selected < #ALL_SPRITES, "All sprites are selected!")
    for _, selected in ipairs(already_selected) do
        if sprite == selected.sprite then
            return false
        end
    end

    return true
end

function characters.get_unused(already_selected: {CharacterSelection}): CharacterName
    assert(#already_selected < #ALL_SPRITES, "All sprites are selected!")

    for _, sprite in ipairs(characters.get_names()) do
		if characters.is_unused(sprite, already_selected) then
			return sprite
		end
    end
end

return characters
