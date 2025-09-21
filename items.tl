require("animation")
require("geometry")
require("entity")

global enum ItemType
   "speed"
end

global function load_item_assets()
    global tic_counter = 0
    global frame_animation = Animation.new(lutro.graphics.newImage("assets/items/frame.png"), 18, 18, 1, 30)
	global item_shadow = lutro.graphics.newImage("assets/items/shadow.png")
	global item_icons: {ItemType: Image} = {
        ["speed"] = lutro.graphics.newImage("assets/items/speed.png")
    }
end

global record Item is Entity
    type: ItemType
    position: Point
end

function Item.new(item_type: ItemType, position: Point): Item
   local self: Item = setmetatable({}, { __index = Item })
   self.type = item_type
   self.position = position
   return self
end

function Item:draw()
    local item_icon = item_icons[self.type]
    local y_draw = self.position.y - 9
    local x_draw = self.position.x - 1
	frame_animation:draw(x_draw, y_draw)
	lutro.graphics.draw(item_icon, x_draw, y_draw)
	lutro.graphics.draw(item_shadow, x_draw, y_draw)
end

global record Items
    on_ground: {Item}
end

function Items.new(): Items
   local self: Items = setmetatable({}, { __index = Items })
   self.on_ground = {}
   return self
end

function Items:dropNew(available_spots: {Point})
    tic_counter = tic_counter + 1
    print(tic_counter)
    if tic_counter % 120 ~= 0 then
        -- Only consider drop a new item every 120 tic (2 seconds)
        return
    end

    local item_drop_probability = 0.1
    if math.random() > item_drop_probability then
        return
    end

    for i, available_spot in ipairs(available_spots) do
        for _, existing_item in ipairs(self.on_ground) do
            if available_spot.x == existing_item.position.x and available_spot.y == existing_item.position.y then
                table.remove(available_spots, i)
            end 
        end
    end

    local spot_to_drop = available_spots[math.random( #available_spots)]
    table.insert(self.on_ground, Item.new("speed", spot_to_drop))
end

function Items:update(dt: number)
    frame_animation:update(dt)
end
