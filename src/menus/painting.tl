-- Flat-colour drawing for menu screens, and the palette they share.

local rectangles = require("engine.geometry.rectangles")
local images = require("engine.images")

local type Color = images.Color
local type Rectangle = rectangles.Rectangle

local BLACK: Color = {0, 0, 0}
local WHITE: Color = {255, 255, 255}
local AMBER: Color = {245, 197, 66}
local CYAN: Color = {89, 199, 232}
local PURPLE: Color = {186, 120, 224}
local RED: Color = {226, 71, 58}
local GREEN: Color = {119, 221, 119}
local BLUE: Color = {74, 122, 232}
local PINK: Color = {235, 130, 180}

local painting = {
    BLACK = BLACK,
    WHITE = WHITE,
    AMBER = AMBER,
    CYAN = CYAN,
    PURPLE = PURPLE,
    RED = RED,
    GREEN = GREEN,
    BLUE = BLUE,
    PINK = PINK,
}

function painting.set_color(tint: Color, alpha?: number)
    lutro.graphics.setColor(tint[1], tint[2], tint[3], alpha or 255)
end

function painting.fill_rect(
    x: number, y: number, width: number, height: number, tint: Color, alpha?: number
)
    painting.set_color(tint, alpha)
    lutro.graphics.rectangle("fill", x, y, width, height)
end

function painting.draw_hline(x0: number, x1: number, y: number, tint: Color)
    painting.fill_rect(math.min(x0, x1), y, math.abs(x1 - x0) + 1, 1, tint)
end

function painting.draw_vline(x: number, y0: number, y1: number, tint: Color)
    painting.fill_rect(x, math.min(y0, y1), 1, math.abs(y1 - y0) + 1, tint)
end

function painting.draw_box(
    area: Rectangle, tint: Color, thickness?: number, alpha?: number
)
    painting.set_color(tint, alpha)
    for ring = 0, (thickness or 1) - 1 do
        local bounds = area:expand(ring)
        lutro.graphics.rectangle(
            "line", bounds.x, bounds.y, bounds.width, bounds.height
        )
    end
end

return painting
