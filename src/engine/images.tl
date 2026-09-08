local type Color = {number, number, number}

local images = {Color = Color}

local function color_equal(c1: Color, c2: Color): boolean
    return c1[1] == c2[1] and c1[2] == c2[2] and c1[3] == c2[3]
end

--- Runs transform over every non-transparent pixel mutating image.
local function map_opaque_pixels(
    image: Image,
    transform: function(number, number, number, number): number, number, number, number
)
    local image_data = image:getData()
    for i = 0, image:getWidth() - 1 do
        for j = 0, image:getHeight() - 1 do
            local r, g, b, alpha = image_data:getPixel(i, j)
            if alpha ~= 0 then
                image_data:setPixel(i, j, transform(r, g, b, alpha))
            end
        end
    end
end

function images.change_colors(image: Image, color_mapping: {Color: Color})
    local image_data = image:getData()
    -- Using C index in getPixel API for some reason...
    for i = 0, image:getWidth() - 1 do
        for j = 0, image:getHeight() - 1 do
            local r, g, b, alpha = image_data:getPixel(i, j)
            if alpha ~= 0 then
                for from_color, to_color in pairs(color_mapping) do
                    if color_equal({r, g, b}, from_color) then
                        r, g, b = table.unpack(to_color)
                    end
                end
                image_data:setPixel(i, j, r, g, b, alpha)
            end
        end
    end
end

local function new_blank_image(width: number, height: number): Image
    return lutro.graphics.newImage(lutro.image.newImageData(width, height))
end

local function corner_color(image_data: ImageData): Color
    local red, green, blue = image_data:getPixel(0, 0)
    return {red, green, blue}
end

--- lutro delimits glyphs by top-row pixels matching the corner colour; widening
--- a separator would add an empty glyph.
local function scaled_column_width(
    image_data: ImageData, x: number, separator: Color, factor: number
): number
    local red, green, blue = image_data:getPixel(x, 0)
    if color_equal({red, green, blue}, separator) then
        return 1
    end
    return factor
end

local function scaled_column_widths(
    image_data: ImageData, width: number, factor: number
): {number}
    local separator = corner_color(image_data)
    local widths: {number} = {}
    for x = 0, width - 1 do
        table.insert(widths, scaled_column_width(image_data, x, separator, factor))
    end
    return widths
end

local function sum(numbers: {number}): number
    local total: number = 0
    for _, value in ipairs(numbers) do
        total = total + value
    end
    return total
end

local function stamp_block(
    target: ImageData,
    x: number,
    y: number,
    width: number,
    height: number,
    red: number,
    green: number,
    blue: number,
    alpha: number
)
    for offset_x = 0, width - 1 do
        for offset_y = 0, height - 1 do
            target:setPixel(x + offset_x, y + offset_y, red, green, blue, alpha)
        end
    end
end

function images.new_magnified_glyph_sheet(image: Image, factor: number): Image
    local source = image:getData()
    local width = image:getWidth()
    local height = image:getHeight()
    local column_widths = scaled_column_widths(source, width, factor)

    local scaled = new_blank_image(sum(column_widths), height * factor)
    local target = scaled:getData()

    local target_x: number = 0
    for column, column_width in ipairs(column_widths) do
        local x = column - 1
        for y = 0, height - 1 do
            local red, green, blue, alpha = source:getPixel(x, y)
            stamp_block(
                target,
                target_x,
                y * factor,
                column_width,
                factor,
                red,
                green,
                blue,
                alpha
            )
        end
        target_x = target_x + column_width
    end

    return scaled
end

--- Mirrors the image left-to-right in place, so one asset can face both ways.
function images.flip_horizontal(image: Image)
    local image_data = image:getData()
    local width = image:getWidth()
    local height = image:getHeight()
    for i = 0, math.floor(width / 2) - 1 do
        local mirrored_i = width - 1 - i
        for j = 0, height - 1 do
            local left_r, left_g, left_b, left_alpha = image_data:getPixel(i, j)
            local right_r, right_g, right_b, right_alpha = image_data:getPixel(
                mirrored_i, j
            )
            image_data:setPixel(i, j, right_r, right_g, right_b, right_alpha)
            image_data:setPixel(mirrored_i, j, left_r, left_g, left_b, left_alpha)
        end
    end
end

function images.new_mirrored_pair(filename: string): Image, Image
    local original = lutro.graphics.newImage(filename)
    local mirrored = lutro.graphics.newImage(filename)
    images.flip_horizontal(mirrored)
    return original, mirrored
end

--- Scale 0-1 represent how far from current to max to increase color component
local function increase_color(color: number, scale: number): number
    return color + scale * (255 - color)
end

function images.make_lighter(image: Image, scale: number)
    local function lighten(
        r: number, g: number, b: number, alpha: number
    ): number, number, number, number
        return increase_color(r, scale),
            increase_color(g, scale),
            increase_color(b, scale),
            alpha
    end
    map_opaque_pixels(image, lighten)
end

--- Maps a luminance value onto one of three stone-grey tones.
local function stone_shade(luminance: number): number
    if luminance < 85 then
        return 60
    elseif luminance < 170 then
        return 130
    else
        return 195
    end
end

function images.petrify(image: Image)
    local function to_stone(
        r: number, g: number, b: number, alpha: number
    ): number, number, number, number
        local luminance = math.floor((r * 299 + g * 587 + b * 114) / 1000)
        local shade = stone_shade(luminance)
        return shade, shade, shade, alpha
    end
    map_opaque_pixels(image, to_stone)
end

function images.set_alpha(image: Image, alpha: number)
    local function replace_alpha(
        r: number, g: number, b: number, _old_alpha: number
    ): number, number, number, number
        return r, g, b, alpha
    end
    map_opaque_pixels(image, replace_alpha)
end

return images
