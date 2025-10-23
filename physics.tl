global function get_init_projectile_velocity(h_diff: number, h_max: number, t_end: number): number
	-- Derived from projectile equation, calculates initial velocity given the
	-- projectile height (h_max) and the time the arc will take (t_end) and the height
	-- difference of start and end position (h_diff).
	return (2 / t_end) * (h_max + math.sqrt(h_max * (h_max + h_diff)))
end

global function get_gravity(init_velocity: number, h_max: number): number
	-- Calculates gravity from how the projectile arc should look like. Not very physical
	-- but making up gravity coffecients that makes things look good is hard. 
	return init_velocity * init_velocity / (2 * h_max)
end
