

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

function character_sprites.get(nbr_to_get?: integer): {CharacterSprite}
    local sprites: {CharacterSprite} = {}
    for i, sprite in ipairs(ALL_SPRITES) do
        if not nbr_to_get or i <= nbr_to_get then
            table.insert(sprites, sprite)
        end
    end

    return sprites
end

return character_sprites
