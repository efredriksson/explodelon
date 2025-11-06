-- This file contains the interface and type definitions for 'lutro'.
--
-- Similar work have been done for LÖVE :https://github.com/MikuAuahDark/love2d-tl/blob/master/love.d.tl.
-- As Lutro is a subset of LÖVE, the Teal code there can be used as inspiration. For details on what
-- exists in Lutro see https://github.com/libretro/lutro-status?tab=readme-ov-file#status. Otherwise,
-- add to the interface here as needed when using new Lutro functionality. 

global type Configuration = interface
   width: integer
   height: integer
end

global enum DrawMode
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
   getData: function(self: Image): ImageData
end

global type ImageData = interface
   is Object
   getPixel: function(self: ImageData, x: number, y: number): number, number, number, number
   setPixel: function(self: ImageData, x: number, y: number, r: number, g: number, b: number, a: number)
end

global type Font = interface
   is Object
   getWidth: function(self: Font, text: string): number
end

global type Quad = interface
   is Object
   getTextureDimensions: function(self: Quad): number, number
   getViewport: function(self: Quad): number, number, number, number
   setViewport: function(self: Quad, x: number, y: number, w: number, h: number, sw?: number, sh?: number)
end

global type Source = interface
   is Object
   setVolume: function(self: Source, volume: number)
   setLooping: function(self: Source, loop: boolean)
   play: function(self: Source)
   pause: function(self: Source)
   stop: function(self: Source)
   isPlaying: function(self: Source): boolean
   isPaused: function(self: Source): boolean
end

global type GamepadButton = enum
   "a"
   "b"
   "x"
   "y"
   "up"
   "down"
   "right"
   "left"
   "r1"
   "r2"
   "r3"
   "l1"
   "l2"
   "l3"
   "start"
   "select"
end

global type SourceType = enum
   "static"
   "stream"
   "queue"
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
      print: function(text: string, x: number, y: number)
      printf: function(text: string, x: number, y: number, limit: number, align: string)

      newImage: function(filename: string): Image
      newQuad: function(x: number, y: number, width: number, height: number, sw: number, sh: number): Quad

      draw: function(drawable: Drawable, x?: number, y?: number, r?: number, sx?: number, sy?: number, ox?: number, oy?: number, kx?: number, ky?: number)
      draw: function(drawable: Drawable, quad: Quad, x: number, y: number, r?: number, sx?: number, sy?: number, ox?: number, oy?: number, kx?: number, ky?: number)
		
      rectangle: function(mode: DrawMode, x: number, y: number, width: number, height: number)
   end

   record joystick
      isDown: function(joystick: integer, button: integer): boolean
      getJoystickCount: function(): integer
   end

   record audio
      newSource: function(filename: string, type: SourceType): Source
      play: function(source: Source)
   end

   record math
      random: function(): number
      random: function(max: integer): integer
   end

   gamepadpressed: function(button_nbr: integer, button: GamepadButton)
   gamepadreleased: function(button_nbr: integer, button: GamepadButton)
end
