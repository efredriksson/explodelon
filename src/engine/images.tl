local type Color = {number, number, number}

local images = {Color = Color}

local function color_equal(c1: Color, c2: Color): boolean
	return c1[1] == c2[1] and c1[2] == c2[2] and c1[3] == c2[3]
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

--- Scale 0-1 represent how far from current to max to increase color component 
local function increase_color(color: number, scale: number): number
	return color + scale * (255 - color)
end

function images.make_lighter(image: Image, scale: number)
	local image_data = image:getData()
	-- Using C index in getPixel API for some reason...
	for i = 0, image:getWidth() - 1 do
		for j = 0, image:getHeight() - 1 do
			local r, g, b, alpha = image_data:getPixel(i, j)
			if alpha ~= 0 then
				r = increase_color(r, scale)
				g = increase_color(g, scale)
				b = increase_color(b, scale)
				image_data:setPixel(i, j, r, g, b, alpha)
			end
		end
	end
end

function images.set_alpha(image: Image, alpha: number)
    local image_data = image:getData()
	for i = 0, image:getWidth() - 1 do
		for j = 0, image:getHeight() - 1 do
			local r, g, b, old_alpha = image_data:getPixel(i, j)	
            if old_alpha ~= 0 then
				image_data:setPixel(i, j, r, g, b, alpha)
			end
		end
	end
end

return images