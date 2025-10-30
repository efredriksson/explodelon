require("geometry")

global record ShadedFont
   main: Font
   shade: Font
end

local fonts = {}

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

global record MenuFont
   image_font: Font
end

function MenuFont.new(image_font: Font): MenuFont
   local self: MenuFont = setmetatable({}, { __index = MenuFont })
   self.image_font = image_font
   return self
end

local FONT_SYMBOLS = " abcdefghijklmnopqrstuvwxyz0123456789.!'-:*"

function fonts.new_menu_white(): MenuFont
    local white_font = lutro.graphics.newImageFont("assets/imgfont/white.png", FONT_SYMBOLS)
    return MenuFont.new(white_font)
end

function fonts.new_menu_black(): MenuFont
    local black_font = lutro.graphics.newImageFont("assets/imgfont/black.png", FONT_SYMBOLS)
    return MenuFont.new(black_font)
end

function MenuFont:print_centered(text: string, box_width: number, position: Point)
	lutro.graphics.setFont(self.image_font)
	lutro.graphics.printf(text, position.x, position.y, box_width, "center")
end

return fonts
