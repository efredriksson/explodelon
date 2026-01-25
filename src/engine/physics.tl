require("engine.geometry.points")
local vectors = require("engine.geometry.vectors")

local physics = {}

global record ProjectileTrajectory
	height: number
	end_height: number
    velocity: number
    lateral_velocity: Vector
    gravity: number
	duration: number
end

function ProjectileTrajectory:in_air_position(ground_pos: Point): Point
	return ground_pos:move(vectors.new(0, -self.height))
end

function ProjectileTrajectory:get_direction(): Vector
	return self.lateral_velocity:normalize()
end

function ProjectileTrajectory:finished(): boolean
	return self.duration <= 0
end

function ProjectileTrajectory:update(dt: number, ground_pos: Point): Point
	self.duration = self.duration - dt
	local new_position = ground_pos:move(self.lateral_velocity:scale(dt))
	self.height = self.height + self.velocity * dt
	self.velocity = self.velocity - self.gravity * dt

	return new_position
end

function physics.calc_init_projectile_velocity(h_diff: number, h_max: number, t_end: number): number
	-- Derived from projectile equation, calculates initial velocity given the
	-- projectile height (h_max) and the time the arc will take (t_end) and the height
	-- difference of start and end position (h_diff).
	return (2 / t_end) * (h_max + math.sqrt(h_max * (h_max + h_diff)))
end

function physics.calc_gravity(init_velocity: number, h_max: number): number
	-- Calculates gravity from how the projectile arc should look like. Not very physical
	-- but making up gravity coffecients that makes things look good is hard. 
	return init_velocity * init_velocity / (2 * h_max)
end

function physics.new_trajectory(
	start_height: number, velocity: number, lateral_velocity: Vector, gravity: number, duration: number
): ProjectileTrajectory
	local self: ProjectileTrajectory = setmetatable({}, { __index = ProjectileTrajectory })
	self.height = start_height
    self.velocity = velocity
    self.lateral_velocity = lateral_velocity
    self.gravity = gravity
	self.duration = duration
	return self
end

function physics.calc_trajectory(
	start_height: number, end_height: number, h_max: number, duration: number, position: Point, target: Point
): ProjectileTrajectory
    local velocity = physics.calc_init_projectile_velocity(
		math.abs(start_height - end_height), h_max, duration
	)
	local gravity = physics.calc_gravity(velocity, h_max)
	
    local throw_vector = vectors.new(
        target.x - position.x,
        target.y - position.y
    )
    local lateral_velocity = throw_vector:scale(1 / duration)
	return physics.new_trajectory(start_height, velocity, lateral_velocity, gravity, duration)
end

return physics
