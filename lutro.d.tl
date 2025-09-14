global type Configuration = interface
   width: integer
   height: integer
end

local enum DrawMode
   "fill"
   "line"
end

local type Object = interface
end

local type Drawable = interface
   is Object
end

global type Image = interface
   is Drawable, Object

   getWidth: function(self: Image): number
   getHeight: function(self: Image): number
end

global type Font = interface
   is Object
   getWidth: function(self: Font, text: string): number
end

global record lutro
   conf: function(t: Configuration)
   load: function()
   update: function(dt: number)
   draw: function()

   record graphics
      clear: function()
      print: function(text: string, x: number, y: number)

      setColor: function(r: number, g: number, b: number, lum?: number)
      setBackgroundColor: function(r: number, g: number, b: number, lum?: number)

      newImageFont: function(filename: string, glyphs: string): Font
      setFont: function(font: Font)

      newImage: function(filename: string): Image

      draw: function(drawable: Drawable, x?: number, y?: number, r?: number, sx?: number, sy?: number, ox?: number, oy?: number, kx?: number, ky?: number)
		
      rectangle: function(mode: DrawMode, x: number, y: number, width: number, height: number)
   end

   record joystick
      isDown: function(joystick: integer, button: integer): boolean
      getJoystickCount: function(): integer
   end

end