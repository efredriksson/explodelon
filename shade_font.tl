require("geometry")

global record ShadedFont
   main: Font
   shade: Font
end

function ShadedFont.new(main: Font, shade: Font): ShadedFont
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

global function get_shaded_number_font(): ShadedFont
    local font_symbols = " 0123456789:\""
    local clock_main = lutro.graphics.newImageFont("assets/imgfont/numbers.png", font_symbols)
	local clock_shade = lutro.graphics.newImageFont("assets/imgfont/numbers_blue_tint.png", font_symbols)
	return ShadedFont.new(clock_main, clock_shade)
end