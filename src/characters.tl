

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
-- Global state on players (IDs) that should choose a character:
local in_queue_to_join: {integer} = {}

function CharacterSelection.new(
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

function characters.is_unused(sprite: CharacterName): boolean
    assert(#character_selections < #ALL_SPRITES, "All sprites are selected!")
    for _, selected in ipairs(character_selections) do
        if sprite == selected.sprite then
            return false
        end
    end

    return true
end

function characters.get_unused(): CharacterName
    assert(#character_selections < #ALL_SPRITES, "All sprites are selected!")

    for _, sprite in ipairs(characters.get_names()) do
		if characters.is_unused(sprite) then
			return sprite
		end
    end
end

function characters.new_selection(
    player_id: integer,
    sprite?: CharacterName
): CharacterSelection
    local new_selection = CharacterSelection.new(player_id, sprite or characters.get_unused())
    table.insert(character_selections, new_selection)
    return new_selection
end

function characters.get_selections(): {CharacterSelection}
    return character_selections
end

function characters.have_not_selected(player_id: integer): boolean
    for _, selection in ipairs(character_selections) do
        if selection.player_id == player_id then
            return false
        end
    end

    return true
end

function characters.auto_select_for(nbr_to_select: integer)
    character_selections = {}
    for i, sprite in ipairs(characters.get_names(nbr_to_select)) do
        characters.new_selection(i, sprite)
    end
end

function characters.clear_selections()
    character_selections = {}
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

function characters.queue_selection_for(player_id: integer)
    table.insert(in_queue_to_join, player_id)
end

function characters.next_player_selecting(): integer
	for i, player_joining in ipairs(in_queue_to_join) do
		table.remove(in_queue_to_join, i)
		return player_joining
	end

	return nil
end

return characters
