-- The corner of the arena a lesson plays in. A real battle can't be clipped to a
-- pane, so the whole board draws and everything outside this window is washed down.

local rectangles = require("engine.geometry.rectangles")
local images = require("engine.images")
local grid = require("level_layout.grid")
local painting = require("menus.painting")
local screen = require("screen")

local type Color = images.Color

-- Board's bottom-right. Five rows (pillars either side of the lesson row), six
-- columns (flank fits the longest ruleset name at 2x).
local COLUMN_SPAN = 6
local ROW_SPAN = 5

local BOARD = grid.dimensions()
local FIRST_COLUMN = BOARD.x_max - COLUMN_SPAN + 1
local LAST_COLUMN = BOARD.x_max
local FIRST_ROW = BOARD.y_max - ROW_SPAN + 1
local LAST_ROW = BOARD.y_max

-- Quiets the busiest map; still reads as the arena.
local WASH_ALPHA = 200
local BORDER_THICKNESS = 2

local ORIGIN = grid.get_tile_position(FIRST_COLUMN, FIRST_ROW)
local AREA = rectangles.new(
    ORIGIN.x, ORIGIN.y, COLUMN_SPAN * grid.TILE_SIZE, ROW_SPAN * grid.TILE_SIZE
)

-- Around the window, not on it. Layout clears this, not AREA.
local FRAME = AREA:expand(1)

local window = {
    FIRST_COLUMN = FIRST_COLUMN,
    LAST_COLUMN = LAST_COLUMN,
    FIRST_ROW = FIRST_ROW,
    LAST_ROW = LAST_ROW,
    FRAME = FRAME,
}

local function wash(x: number, y: number, width: number, height: number)
    painting.fill_rect(x, y, width, height, painting.BLACK, WASH_ALPHA)
end

-- Border tint matches the readout marker.
function window.draw_surround(border_tint: Color)
    local right = AREA.x + AREA.width
    local bottom = AREA.y + AREA.height

    wash(0, 0, screen.WIDTH, AREA.y)
    wash(0, bottom, screen.WIDTH, screen.HEIGHT - bottom)
    wash(0, AREA.y, AREA.x, AREA.height)
    wash(right, AREA.y, screen.WIDTH - right, AREA.height)
    painting.draw_box(FRAME, border_tint, BORDER_THICKNESS)
end

return window
