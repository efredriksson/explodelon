global type Configuration = interface
   width: integer
   height: integer
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
   
      rectangle: function(mode: string, x: number, y: number, width: number, height: number)
   end

   record joystick
      isDown: function(joystick: integer, button: integer): boolean
   end
   
end