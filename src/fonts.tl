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

function fonts.new_menu_white(): MenuFont
    local white_font = lutro.graphics.newImageFont(
        "assets/imgfont/white.png", FONT_SYMBOLS
    )
    return MenuFont.new(white_font, nil)
end

function fonts.new_menu_black(): MenuFont
    local black_font = lutro.graphics.newImageFont(
        "assets/imgfont/black.png", FONT_SYMBOLS
    )
    return MenuFont.new(black_font, nil)
end

-- Shared; decoded once, not per colour.
local black_outline_font: Font

local function get_black_outline_font(): Font
    if not black_outline_font then
        black_outline_font = lutro.graphics.newImageFont(
            "assets/imgfont/black.png", FONT_SYMBOLS
        )
    end
    return black_outline_font
end

local function new_outlined(ink_font: Font): MenuFont
    return MenuFont.new(ink_font, get_black_outline_font())
end

function fonts.new_menu_white_outlined(): MenuFont
    return new_outlined(
        lutro.graphics.newImageFont("assets/imgfont/white.png", FONT_SYMBOLS)
    )
end

function fonts.new_menu_gray_outlined(): MenuFont
    return new_outlined(
        lutro.graphics.newImageFont("assets/imgfont/gray.png", FONT_SYMBOLS)
    )
end

local WHITE_INK: Color = {255, 255, 255}

-- Recolours the shared glyph sheet (engine.images.change_colors) instead of
-- a PNG per colour.
function fonts.new_menu_colored_outlined(ink_color: Color): MenuFont
    local ink_image = lutro.graphics.newImage("assets/imgfont/white.png")
    images.change_colors(ink_image, {[WHITE_INK] = ink_color})
    return new_outlined(lutro.graphics.newImageFont(ink_image, FONT_SYMBOLS))
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
