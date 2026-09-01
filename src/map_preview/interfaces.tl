local type MapPreview = interface
    update: function(self, dt: number)
    draw: function(self)
    leave: function(self)
end

return MapPreview
