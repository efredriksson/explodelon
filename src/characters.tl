local type CharacterName = enum
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

local record CharacterSelection
    player_id: integer
    sprite: CharacterName
end

local characters = {
    CharacterName = CharacterName,
    CharacterSelection = CharacterSelection,
}
-- Global state on what characters have been selected:
local character_selections: {CharacterSelection} = {}

function CharacterSelection.new(
    player_id: integer, sprite: CharacterName
): CharacterSelection
    local self: CharacterSelection = setmetatable({}, {__index = CharacterSelection})
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

function characters.is_unused(sprite: CharacterName): boolean
    for _, selected in ipairs(character_selections) do
        if sprite == selected.sprite then
            return false
        end
    end

    return true
end

function characters.new_selection(player_id: integer, sprite: CharacterName)
    table.insert(character_selections, CharacterSelection.new(player_id, sprite))
end

function characters.get_selections(): {CharacterSelection}
    return character_selections
end

function characters.set_auto_selected(nbr_to_select: integer)
    character_selections = {}
    for i, sprite in ipairs(characters.get_names(nbr_to_select)) do
        characters.new_selection(i, sprite)
    end
end

function characters.exist_selection_for(player_id: integer): boolean
    for _, selection in ipairs(character_selections) do
        if selection.player_id == player_id then
            return true
        end
    end

    return false
end

function characters.remove_selection_for(player_id: integer)
    for i, selection in ipairs(character_selections) do
        if selection.player_id == player_id then
            table.remove(character_selections, i)
            return
        end
    end
end

return characters
