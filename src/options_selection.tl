-- Pick a ruleset and see what its counts do, at double size.

local dino_animations = require("dino_animations")
local eggs = require("eggs")
local points = require("engine.geometry.points")
local rectangles = require("engine.geometry.rectangles")
local images = require("engine.images")
local joysticks = require("engine.joysticks")
local scenes = require("engine.scenes")
local fonts = require("fonts")
local items = require("items")
local itertools = require("itertools")
local background = require("level_graphics.background")
local soft_block_animations = require("level_graphics.soft_block_animations")
local arrows = require("menus.arrows")
local game_rule_screen = require("menus.game_rule_screen")
local menu_items = require("menus.items")
local painting = require("menus.painting")
local player_selection = require("player_selection")
local preview_options = require("preview.options.init")
local window = require("preview.options.window")
local scripted_battle = require("preview.scripted_battle")
local settings = require("settings")

local type Color = images.Color
local type DinoColor = settings.DinoColor
local type ItemType = settings.ItemType
local type Map = settings.Map
local type MenuFont = fonts.MenuFont
local type MenuSelection = menu_items.MenuSelection
local type Rectangle = rectangles.Rectangle
local type RulesetName = settings.RulesetName
local type Scene = scenes.Scene
local type ScriptedBattle = scripted_battle.ScriptedBattle

local RULESET_ORDER <total>: {RulesetName: integer} = {
    default = 1,
    insanity = 2,
    bomb_stack = 3,
    dino_madness = 4,
}

local RULESETS = itertools.in_position_order(RULESET_ORDER)

local ITEM_ORDER: {ItemType} = {"bomb", "fire", "speed", "kick", "lightning_bomb"}
local DINO_ORDER: {DinoColor} = {"blue", "pink", "green", "yellow", "purple"}

-- Padding cropped away, so materiel is as big as its subject, not its canvas.
local SOFT_BLOCK_CROP = rectangles.new(0, 0, 16, 16)
local EGG_CROP = rectangles.new(1, 2, 18, 22)
local DINO_CROP = rectangles.new(9, 14, 16, 18)

-- Short of the tile's bottom border, which reads as a stray line under a
-- floating pickup.
local PICKUP_CROP = rectangles.new(0, 0, 18, 17)

local MATERIEL_SCALE = 2

local MENU_DINO_LEVEL = 1
local DISABLED_ALPHA = 64

-- The picker's half, left of the lesson window.
local FLANK_WIDTH = window.FRAME.x

-- Half size: an exact halving keeps the chunky source clean and clears the
-- longest name at 2x.
local ARROW_Y = 143
local ARROW_SCALE = 0.5

-- Clear of the border and the screen edge.
local ARROW_INSET = 4
local NAME_POSITION = points.new(0, 144)

local ACCENT_RULE_INSET = 12
local ACCENT_RULE_Y = 172

-- Longer than this wraps in the flank.
local HINTS = "start for more options"
local HINTS_POSITION = points.new(0, 186)

local big_font: MenuFont
local big_gray_font: MenuFont
local hint_font: MenuFont
local gray_font: MenuFont
local ok_sound: Source
local frame_sprite: Image
local egg_sprite: Image
local item_sprites: {ItemType: Image} = {}
local bright_dino_sprites: {DinoColor: Image} = {}
local faded_dino_sprites: {DinoColor: Image} = {}
local soft_block_sprites: {Map: Image} = {}

local type MaterielKind = enum
    "soft_block"
    "item"
    "egg"
    "dino"
end

local record Materiel
    kind: MaterielKind
    item: ItemType
    color: DinoColor
end

function Materiel.new(kind: MaterielKind, item?: ItemType, color?: DinoColor): Materiel
    local self: Materiel = setmetatable({}, {__index = Materiel})
    self.kind = kind
    self.item = item
    self.color = color
    return self
end

local function item_materiel(item: ItemType): Materiel
    return Materiel.new("item", item, nil)
end

local function dino_materiel(color: DinoColor): Materiel
    return Materiel.new("dino", nil, color)
end

local ROW_X = 10
local SLOT_WIDTH = 50
local COUNT_DROP = 2

-- Beside the count, one slot's digits would run into the next slot's.
local PERCENT_DROP = 14

local record Row
    materiel: {Materiel}
    baseline: number
end

function Row.new(materiel: {Materiel}, baseline: number): Row
    local self: Row = setmetatable({}, {__index = Row})
    self.materiel = materiel
    self.baseline = baseline
    return self
end

function Row:count_y(): number
    return self.baseline + COUNT_DROP
end

function Row:slot_x(position: integer): number
    return ROW_X + (position - 1) * SLOT_WIDTH
end

local MATERIEL_ROWS: {Row} = {
    Row.new(
        itertools.combine(
            {Materiel.new("soft_block")}, itertools.map(ITEM_ORDER, item_materiel)
        ),
        36
    ),
    Row.new(
        itertools.combine(
            {Materiel.new("egg")}, itertools.map(DINO_ORDER, dino_materiel)
        ),
        107
    ),
}

local function dino_sprite_for(color: DinoColor): Image
    if settings.game_rules.dinos.enabled[color] then
        return bright_dino_sprites[color]
    end
    return faded_dino_sprites[color]
end

local function materiel_count(materiel: Materiel): integer
    if materiel.kind == "soft_block" then
        return settings.game_rules.items.nbr_soft_blocks
    elseif materiel.kind == "item" then
        return settings.game_rules.items.nbr_of_items[materiel.item]
    elseif materiel.kind == "egg" then
        return settings.game_rules.dinos.nbr_of_eggs
    end
    return 0
end

local function font_for_count(count: integer): MenuFont
    if count > 0 then
        return big_font
    end
    return big_gray_font
end

-- What a blown-open soft block also drops mid-battle.
local function drop_rate(materiel: Materiel): number
    if materiel.kind ~= "item" then
        return 0
    end
    return settings.game_rules.items.spawn_rates[materiel.item]
end

local function draw_drop_percent(materiel: Materiel, slot_x: number, count_y: number)
    local rate = drop_rate(materiel)
    if rate <= 0 then
        return
    end

    gray_font:print_centered(
        string.format("%d%%", math.floor(rate * 100 + 0.5)),
        SLOT_WIDTH,
        points.new(slot_x, count_y + PERCENT_DROP)
    )
end

local function magnified_region(sheet: Image, crop: Rectangle): Image
    return images.new_magnified_region(
        sheet, crop.x, crop.y, crop.width, crop.height, MATERIEL_SCALE
    )
end

-- Map-dependent, and the map is not known until entry.
local function ensure_soft_block_sprite()
    if soft_block_sprites[settings.map] then
        return
    end
    soft_block_sprites[settings.map] = magnified_region(
        soft_block_animations.get_rigid().image, SOFT_BLOCK_CROP
    )
end

local function draw_sprite(sprite: Image, center_x: number, baseline: number)
    lutro.graphics.draw(
        sprite, center_x - sprite:getWidth() / 2, baseline - sprite:getHeight()
    )
end

-- One frame colour rather than cycling, and no floor shadow: no floor here to
-- fall on.
local function draw_pickup(item: ItemType, center_x: number, baseline: number)
    draw_sprite(frame_sprite, center_x, baseline)
    draw_sprite(item_sprites[item], center_x, baseline)
end

local function draw_materiel(materiel: Materiel, center_x: number, baseline: number)
    if materiel.kind == "item" then
        draw_pickup(materiel.item, center_x, baseline)
    elseif materiel.kind == "soft_block" then
        draw_sprite(soft_block_sprites[settings.map], center_x, baseline)
    elseif materiel.kind == "egg" then
        draw_sprite(egg_sprite, center_x, baseline)
    else
        draw_sprite(dino_sprite_for(materiel.color), center_x, baseline)
    end
end

-- A dino is in or out of the ruleset, and the faded sprite already says so.
local function draw_count(materiel: Materiel, slot_x: number, count_y: number)
    if materiel.kind == "dino" then
        return
    end

    local count = materiel_count(materiel)
    font_for_count(count):print_centered(
        tostring(count), SLOT_WIDTH, points.new(slot_x, count_y)
    )
    draw_drop_percent(materiel, slot_x, count_y)
end

local PREVIEW_TINTS: {ItemType: Color} = {
    bomb = painting.AMBER,
    fire = painting.RED,
    kick = painting.GREEN,
}

local MARKER_WIDTH = 44
local MARKER_TOP = 2
local MARKER_HEIGHT = 57
local MARKER_ALPHA = 200
local MARKER_THICKNESS = 2

local function is_preview_subject(materiel: Materiel, subject: ItemType): boolean
    return materiel.kind == "item" and materiel.item == subject
end

local function draw_marker(slot_x: number, tint: Color)
    painting.draw_box(
        rectangles.new(
            slot_x + (SLOT_WIDTH - MARKER_WIDTH) / 2,
            MARKER_TOP,
            MARKER_WIDTH,
            MARKER_HEIGHT
        ),
        tint,
        MARKER_THICKNESS,
        MARKER_ALPHA
    )
end

local function draw_row(row: Row, subject: ItemType)
    local count_y = row:count_y()
    for position, materiel in ipairs(row.materiel) do
        local slot_x = row:slot_x(position)
        if is_preview_subject(materiel, subject) then
            draw_marker(slot_x, PREVIEW_TINTS[subject])
        end
        draw_materiel(materiel, slot_x + SLOT_WIDTH / 2, row.baseline)
        draw_count(materiel, slot_x, count_y)
    end
end

local record OptionsSelection is Scene
    previous_screen: Scene
    selection: MenuSelection<RulesetName>
    lesson: ScriptedBattle
    rotation_index: integer
end

local options_selection = {}

function options_selection.new(previous_screen: Scene): OptionsSelection
    local self: OptionsSelection = setmetatable({}, {__index = OptionsSelection})
    self.previous_screen = previous_screen
    self.selection = menu_items.new_enum(RULESETS)
    self.rotation_index = 1
    return self
end

local function new_faded_dino_image(color: DinoColor): Image
    local image = dino_animations.new_image(MENU_DINO_LEVEL, "idle", "down", color)
    images.set_alpha(image, DISABLED_ALPHA)
    return image
end

function options_selection.load_assets()
    big_font = fonts.new_menu_white_outlined_big()
    big_gray_font = fonts.new_menu_gray_outlined_big()
    hint_font = fonts.new_menu_white_outlined()
    gray_font = fonts.new_menu_gray_outlined()
    ok_sound = menu_items.ok_sound()

    frame_sprite = magnified_region(items.get_frame_image(), PICKUP_CROP)
    egg_sprite = magnified_region(eggs.get_shake_image(), EGG_CROP)
    for _, item in ipairs(ITEM_ORDER) do
        item_sprites[item] = magnified_region(items.get_icon(item), PICKUP_CROP)
    end
    for _, color in ipairs(DINO_ORDER) do
        bright_dino_sprites[color] = magnified_region(
            dino_animations.get_image(MENU_DINO_LEVEL, "idle", "down", color), DINO_CROP
        )
        faded_dino_sprites[color] = magnified_region(
            new_faded_dino_image(color), DINO_CROP
        )
    end
end

function OptionsSelection:_previewed_item(): ItemType
    return preview_options.rotation[self.rotation_index]
end

-- load() reruns on return from the rules screen, where the map can't change, so
-- the showcase plays on.
function OptionsSelection:_start_lesson()
    if self.lesson then
        return
    end
    local item = self:_previewed_item()
    self.lesson = scripted_battle.new(
        preview_options.scenery_for(item), preview_options.choreography_for(item)
    )
end

function OptionsSelection:_advance_preview()
    self.rotation_index = self.rotation_index % #preview_options.rotation + 1
    local item = self:_previewed_item()
    self.lesson:play(
        preview_options.scenery_for(item), preview_options.choreography_for(item)
    )
end

function OptionsSelection:load()
    self.selection.value = itertools.find(settings.ruleset, RULESETS)
    ensure_soft_block_sprite()
    self:_start_lesson()
end

function OptionsSelection:_leave_for(next_screen: Scene)
    self.lesson:leave()
    scenes.set(next_screen)
end

function OptionsSelection:update(dt: number)
    if joysticks.is_pressed_any(joysticks.BUTTONS.B) then
        self:_leave_for(player_selection.setup())
        return
    end

    if joysticks.is_pressed_any(joysticks.BUTTONS.A) then
        self:_leave_for(self.previous_screen)
        return
    end

    if joysticks.is_pressed_any(joysticks.BUTTONS.START) then
        self:_leave_for(game_rule_screen.new(self))
        return
    end

    local moved = false
    if joysticks.is_pressed_any(joysticks.BUTTONS.RIGHT) then
        moved = self.selection:increment()
    elseif joysticks.is_pressed_any(joysticks.BUTTONS.LEFT) then
        moved = self.selection:decrement()
    end

    if moved then
        ok_sound:play()
        settings.set_ruleset(self.selection:get_value())
    end

    self.lesson:update(dt)
    if self.lesson:taught_once() then
        self:_advance_preview()
    end
end

function OptionsSelection:_draw_arena()
    background.draw()
    self.lesson:draw()
    window.draw_surround(PREVIEW_TINTS[self:_previewed_item()])
end

function OptionsSelection:_draw_readout()
    local subject = self:_previewed_item()
    for _, row in ipairs(MATERIEL_ROWS) do
        draw_row(row, subject)
    end
end

local function draw_arrow(image: Image, x: number)
    lutro.graphics.draw(image, x, ARROW_Y, 0, ARROW_SCALE, ARROW_SCALE)
end

function OptionsSelection:_draw_arrows()
    if not self.selection:at_min() then
        draw_arrow(arrows.left(), ARROW_INSET)
    end

    if not self.selection:at_max() then
        local right_image = arrows.right()
        local scaled_width = right_image:getWidth() * ARROW_SCALE
        draw_arrow(right_image, FLANK_WIDTH - scaled_width - ARROW_INSET)
    end
end

function OptionsSelection:_draw_flank()
    big_font:print_centered(self.selection:as_menu_string(), FLANK_WIDTH, NAME_POSITION)
    hint_font:print_centered(HINTS, FLANK_WIDTH, HINTS_POSITION)
end

function OptionsSelection:_draw_accent_rule()
    painting.draw_hline(
        ACCENT_RULE_INSET,
        FLANK_WIDTH - 1 - ACCENT_RULE_INSET,
        ACCENT_RULE_Y,
        painting.WHITE
    )
end

function OptionsSelection:draw()
    self:_draw_arena()
    self:_draw_readout()
    self:_draw_arrows()
    self:_draw_flank()
    self:_draw_accent_rule()
end

return options_selection
