local points = require("engine.geometry.points")

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
   local self: ShadedFont = setmetatable({}, { __index = ShadedFont })
   self.main = main
   self.shade = shade
   return self
end

function ShadedFont:draw(text: string, position: Point)
	lutro.graphics.setFont(self.shade)
    for dx=1, 0, -1 do
        for dy=1, 0, -1 do
            if dx == 0 and dy == 0 then
                lutro.graphics.setFont(self.main)
            end
            lutro.graphics.print(text, position.x + dx, position.y + dy)
        end
    end
end

function fonts.new_shaded_numbers(): ShadedFont
    local font_symbols = " 0123456789:\""
    local clock_main = lutro.graphics.newImageFont("assets/imgfont/numbers.png", font_symbols)
	local clock_shade = lutro.graphics.newImageFont("assets/imgfont/numbers_blue_tint.png", font_symbols)
	return fonts.new_shaded(clock_main, clock_shade)
end

function MenuFont.new(main: Font, outline: Font): MenuFont
   local self: MenuFont = setmetatable({}, { __index = MenuFont })
   self.main = main
   self.outline = outline
   return self
end

local FONT_SYMBOLS = " abcdefghijklmnopqrstuvwxyz0123456789.!'-:*"

function fonts.new_menu_white(): MenuFont
    local white_font = lutro.graphics.newImageFont("assets/imgfont/white.png", FONT_SYMBOLS)
    return MenuFont.new(white_font, nil)
end

function fonts.new_menu_black(): MenuFont
    local black_font = lutro.graphics.newImageFont("assets/imgfont/black.png", FONT_SYMBOLS)
    return MenuFont.new(black_font, nil)
end

function fonts.new_menu_white_outlined(): MenuFont
    local white_font = lutro.graphics.newImageFont("assets/imgfont/white.png", FONT_SYMBOLS)
    local black_font = lutro.graphics.newImageFont("assets/imgfont/black.png", FONT_SYMBOLS)
    return MenuFont.new(white_font, black_font)
end

function fonts.new_menu_gray_outlined(): MenuFont
    local gray_font = lutro.graphics.newImageFont("assets/imgfont/gray.png", FONT_SYMBOLS)
    local black_font = lutro.graphics.newImageFont("assets/imgfont/black.png", FONT_SYMBOLS)
    return MenuFont.new(gray_font, black_font)
end

function MenuFont:print_centered(text: string, box_width: number, position: Point)
    if self.outline then
        lutro.graphics.setFont(self.outline)
        for dx=-1, 1 do
            for dy=-1, 1 do
                lutro.graphics.printf(text, position.x + dx, position.y + dy, box_width, "center")
            end
        end
    end

    lutro.graphics.setFont(self.main)
	lutro.graphics.printf(text, position.x, position.y, box_width, "center")
end

return fonts
