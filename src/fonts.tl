local points = require("engine.geometry.points")
local images = require("engine.images")

local type Color = images.Color
local type Point = points.Point

local record ShadedFont
    main: Font
    shade: Font
end

local record MenuFont
    main: Font
    outline: Font
end

local fonts = {ShadedFont = ShadedFont, MenuFont = MenuFont}

function fonts.new_shaded(main: Font, shade: Font): ShadedFont
    local self: ShadedFont = setmetatable({}, {__index = ShadedFont})
    self.main = main
    self.shade = shade
    return self
end

function ShadedFont:width(text: string): number
    return self.main:getWidth(text)
end

function ShadedFont:draw(text: string, position: Point)
    lutro.graphics.setFont(self.shade)
    for dx = 1, 0, -1 do
        for dy = 1, 0, -1 do
            if dx == 0 and dy == 0 then
                lutro.graphics.setFont(self.main)
            end
            lutro.graphics.print(text, position.x + dx, position.y + dy)
        end
    end
end

function fonts.new_shaded_numbers(): ShadedFont
    local font_symbols = " 0123456789:\""
    local clock_main = lutro.graphics.newImageFont(
        "assets/imgfont/numbers.png", font_symbols
    )
    local clock_shade = lutro.graphics.newImageFont(
        "assets/imgfont/numbers_blue_tint.png", font_symbols
    )
    return fonts.new_shaded(clock_main, clock_shade)
end

function MenuFont.new(main: Font, outline: Font): MenuFont
    local self: MenuFont = setmetatable({}, {__index = MenuFont})
    self.main = main
    self.outline = outline
    return self
end

local FONT_SYMBOLS = " abcdefghijklmnopqrstuvwxyz0123456789.!'-:*"

local GLYPH_SHEET = "assets/imgfont/white.png"

local WHITE_INK: Color = {255, 255, 255}
local BLACK_INK: Color = {0, 0, 0}
local GRAY_INK: Color = {192, 192, 192}

local NORMAL_SCALE = 1
local BIG_SCALE = 2

-- Bodies are inked edge to edge, so this pixel is all the tracking there is.
local GLYPH_SPACING = 1

local function new_ink_sheet(ink_color: Color): Image
    local sheet = lutro.graphics.newImage(GLYPH_SHEET)
    images.change_colors(sheet, {[WHITE_INK] = ink_color})
    return sheet
end

local function new_glyph_sheet(ink_color: Color, scale: integer): Image
    local sheet = new_ink_sheet(ink_color)
    if scale == NORMAL_SCALE then
        return sheet
    end
    return images.new_magnified_glyph_sheet(sheet, scale)
end

local function new_font(ink_color: Color, scale: integer): Font
    return lutro.graphics.newImageFont(
        new_glyph_sheet(ink_color, scale), FONT_SYMBOLS, GLYPH_SPACING * scale
    )
end

-- A Font never changes once built, so screens sharing an ink share the font.
local built_fonts: {string: Font} = {}

local function font_key(ink_color: Color, scale: integer): string
    return string.format(
        "%d-%d-%d@%d",
        math.floor(ink_color[1]),
        math.floor(ink_color[2]),
        math.floor(ink_color[3]),
        scale
    )
end

local function get_font(ink_color: Color, scale?: integer): Font
    local font_scale = scale or NORMAL_SCALE
    local key = font_key(ink_color, font_scale)
    if not built_fonts[key] then
        built_fonts[key] = new_font(ink_color, font_scale)
    end
    return built_fonts[key]
end

local function new_outlined(ink_color: Color, scale?: integer): MenuFont
    return MenuFont.new(get_font(ink_color, scale), get_font(BLACK_INK, scale))
end

function fonts.new_menu_white(): MenuFont
    return MenuFont.new(get_font(WHITE_INK), nil)
end

function fonts.new_menu_black(): MenuFont
    return MenuFont.new(get_font(BLACK_INK), nil)
end

function fonts.new_menu_white_outlined(): MenuFont
    return new_outlined(WHITE_INK)
end

function fonts.new_menu_white_outlined_big(): MenuFont
    return new_outlined(WHITE_INK, BIG_SCALE)
end

function fonts.new_menu_gray_outlined(): MenuFont
    return new_outlined(GRAY_INK)
end

function fonts.new_menu_colored_outlined(ink_color: Color): MenuFont
    return new_outlined(ink_color)
end

local function print_at(text: string, x: number, y: number, box_width?: number)
    if box_width then
        lutro.graphics.printf(text, x, y, box_width, "center")
    else
        lutro.graphics.print(text, x, y)
    end
end

local function print_menu_text(
    font: MenuFont, text: string, position: Point, box_width?: number
)
    if font.outline then
        lutro.graphics.setFont(font.outline)
        for dx = -1, 1 do
            for dy = -1, 1 do
                print_at(text, position.x + dx, position.y + dy, box_width)
            end
        end
    end

    lutro.graphics.setFont(font.main)
    print_at(text, position.x, position.y, box_width)
end

function MenuFont:print(text: string, position: Point)
    print_menu_text(self, text, position)
end

function MenuFont:width(text: string): number
    return self.main:getWidth(text)
end

function MenuFont:print_centered(text: string, box_width: number, position: Point)
    print_menu_text(self, text, position, box_width)
end

return fonts
