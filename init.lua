local mobs = {}
function mobs:register_monster(name, def)
	minetest.register_entity(name, {
		hp_max = def.hp_max,
		physical = def.physical,
		collisionbox = def.collisionbox,
		visual = def.visual,
		visual_size = def.visual_size,
		textures = def.textures,
		makes_footstep_sound = def.makes_footstep_sound,
		view_range = def.view_range,
		walk_velocity = def.walk_velocity,
		run_velocity = def.run_velocity,
		damage = def.damage,
		light_resistant = def.light_resistant,
		drop = def.drop,
		
		timer = 0,
		attack = {player=nil, dist=nil},
		state = "stand",
		v_start = false,
		
		
		set_velocity = function(self, v)
			local yaw = self.object:getyaw()
			local x = math.sin(yaw) * -v
			local z = math.cos(yaw) * v
			self.object:setvelocity({x=x, y=self.object:getvelocity().y, z=z})
		end,
		
		get_velocity = function(self)
			local v = self.object:getvelocity()
			return (v.x^2 + v.z^2)^(0.5)
		end,
		
		on_step = function(self, dtime)
			if self.object:getvelocity().y > 0.1 then
				local yaw = self.object:getyaw()
				local x = math.sin(yaw) * -2
				local z = math.cos(yaw) * 2
				self.object:setacceleration({x=x, y=-10, z=z})
			else
				self.object:setacceleration({x=0, y=-10, z=0})
			end
			
			self.timer = self.timer+dtime
			if self.state ~= "attack" then
				if self.timer < 1 then
					return
				end
				self.timer = 0
			end
			
			if not self.light_resistant and minetest.env:get_timeofday() > 0.2 and minetest.env:get_timeofday() < 0.8 and minetest.env:get_node_light(self.object:getpos()) > 3 then
				self.object:punch(self.object, 1.0, {
					full_punch_interval=1.0,
					groupcaps={
						fleshy={times={[3]=1/10}},
					}
				}, nil)
			end
			
			if string.find(minetest.env:get_node(self.object:getpos()).name, "default:water") then
				self.object:punch(self.object, 1.0, {
					full_punch_interval=1.0,
					groupcaps={
						fleshy={times={[3]=1/1}},
					}
				}, nil)
			end
			
			if string.find(minetest.env:get_node(self.object:getpos()).name, "default:lava") then
				self.object:punch(self.object, 1.0, {
					full_punch_interval=1.0,
					groupcaps={
						fleshy={times={[3]=1/2}},
					}
				}, nil)
			end
			
			for _,player in pairs(minetest.get_connected_players()) do
				local s = self.object:getpos()
				local p = player:getpos()
				local dist = ((p.x-s.x)^2 + (p.y-s.y)^2 + (p.z-s.z)^2)^0.5
				if dist < self.view_range then
					if self.attack.dist then
						if self.attack.dist < dist then
							self.state = "attack"
							self.attack.player = player
							self.attack.dist = dist
						end
					else
						self.state = "attack"
						self.attack.player = player
						self.attack.dist = dist
					end
				end
			end
			
			if self.state == "stand" then
				if math.random(1, 2) == 1 then
					self.object:setyaw(self.object:getyaw()+((math.random(0,360)-180)/180*math.pi))
				end
				if math.random(1, 100) <= 50 then
					self.set_velocity(self, self.walk_velocity)
					self.state = "walk"
				end
			elseif self.state == "walk" then
				if math.random(1, 100) <= 30 then
					self.object:setyaw(self.object:getyaw()+((math.random(0,360)-180)/180*math.pi))
					self.set_velocity(self, self.get_velocity(self))
				end
				if math.random(1, 100) <= 10 then
					self.set_velocity(self, 0)
					self.state = "stand"
				end
				if self.get_velocity(self) <= 0.5 and self.object:getvelocity().y == 0 then
					local v = self.object:getvelocity()
					v.y = 5
					self.object:setvelocity(v)
				end
			elseif self.state == "attack" then
				local s = self.object:getpos()
				local p = self.attack.player:getpos()
				local dist = ((p.x-s.x)^2 + (p.y-s.y)^2 + (p.z-s.z)^2)^0.5
				if dist > self.view_range or self.attack.player:get_hp() <= 0 then
					self.state = "stand"
					self.v_start = false
					self.set_velocity(self, 0)
					self.attack = {player=nil, dist=nil}
					return
				else
					self.attack.dist = dist
				end
				
				local vec = {x=p.x-s.x, y=p.y-s.y, z=p.z-s.z}
				local yaw = math.atan(vec.z/vec.x)+math.pi/2
				if p.x > s.x then
					yaw = yaw+math.pi
				end
				self.object:setyaw(yaw)
				if self.attack.dist > 2 then
					if not self.v_start then
						self.v_start = true
						self.set_velocity(self, self.run_velocity)
					else
						if self.get_velocity(self) <= 0.5 and self.object:getvelocity().y == 0 then
							local v = self.object:getvelocity()
							v.y = 5
							self.object:setvelocity(v)
						end
						self.set_velocity(self, self.run_velocity)
					end
				else
					self.set_velocity(self, 0)
					self.v_start = false
					if self.timer > 1 then
						self.timer = 0
						if self.damage > 3 then
							self.attack.player:punch(self.object, 1.0,  {
								full_punch_interval=1.0,
								groupcaps={
									fleshy={times={[1]=1/(self.damage-2),[2]=1/(self.damage-1),[3]=1/self.damage}},
								}
							}, vec)
						elseif self.damage > 2 then
							self.attack.player:punch(self.object, 1.0,  {
								full_punch_interval=1.0,
								groupcaps={
									fleshy={times={[2]=1/(self.damage-1),[3]=1/self.damage}},
								}
							}, vec)
						elseif self.damage > 1 then
							self.attack.player:punch(self.object, 1.0,  {
								full_punch_interval=1.0,
								groupcaps={
									fleshy={times={[3]=1/self.damage}},
								}
							}, vec)
						end
					end
				end
			end
		end,
		
		on_activate = function(self, staticdata)
			self.object:set_armor_groups({fleshy=3})
			self.object:setacceleration({x=0, y=-10, z=0})
			self.state = "stand"
			self.object:setvelocity({x=0, y=self.object:getvelocity().y, z=0})
			self.object:setyaw(math.random(1, 360)/180*math.pi)
		end,
		
		on_punch = function(self, hitter)
			if self.object:get_hp() <= 0 then
				if hitter and hitter:is_player() and hitter:get_inventory() then
					for i=1,math.random(0,3)+2 do
						hitter:get_inventory():add_item("main", ItemStack(self.drop))
					end
				else
					for i=1,math.random(0,3)+2 do
						local obj = minetest.env:add_item(self.object:getpos(), self.drop)
						if obj then
							obj:get_luaentity().collect = true
							local x = math.random(1, 5)
							if math.random(1,2) == 1 then
								x = -x
							end
							local z = math.random(1, 5)
							if math.random(1,2) == 1 then
								z = -z
							end
							obj:setvelocity({x=1/x, y=obj:getvelocity().y, z=1/z})
						end
					end
				end
			end
		end,
		
	})
end

mobs:register_monster("mobs:dirt_monster", {
	hp_max = 5,
	physical = true,
	collisionbox = {-0.4, -1, -0.4, 0.4, 1, 0.4},
	visual = "upright_sprite",
	visual_size = {x=1, y=2},
	textures = {"mobs_dirt_monster.png", "mobs_dirt_monster_back.png"},
	makes_footstep_sound = true,
	view_range = 15,
	walk_velocity = 1,
	run_velocity = 3,
	damage = 2,
	drop = "default:dirt",
})

minetest.register_abm({
	nodenames = {"default:dirt_with_grass"},
	neighbors = {"default:dirt", "default:dirt_with_grass"},
	interval = 60,
	chance = 5000,
	action = function(pos, node)
		pos.y = pos.y+1
		if minetest.env:get_node_light(pos) > 3 then
			return
		end
		if minetest.env:get_node(pos).name ~= "air" then
			return
		end
		pos.y = pos.y+1
		if minetest.env:get_node(pos).name ~= "air" then
			return
		end
		minetest.env:add_entity(pos, "mobs:dirt_monster")
	end
})

mobs:register_monster("mobs:stone_monster", {
	hp_max = 10,
	physical = true,
	collisionbox = {-0.4, -1, -0.4, 0.4, 1, 0.4},
	visual = "upright_sprite",
	visual_size = {x=1, y=2},
	textures = {"mobs_stone_monster.png", "mobs_stone_monster_back.png"},
	makes_footstep_sound = true,
	view_range = 10,
	walk_velocity = 0.5,
	run_velocity = 2,
	damage = 3,
	drop = "default:mossycobble",
})

minetest.register_abm({
	nodenames = {"default:stone"},
	neighbors = {"default:stone"},
	interval = 60,
	chance = 5000,
	action = function(pos, node)
		pos.y = pos.y+1
		if not minetest.env:get_node_light(pos) then
			return
		end
		if minetest.env:get_node_light(pos) > 3 then
			return
		end
		if minetest.env:get_node(pos).name ~= "air" then
			return
		end
		pos.y = pos.y+1
		if minetest.env:get_node(pos).name ~= "air" then
			return
		end
		minetest.env:add_entity(pos, "mobs:stone_monster")
	end
})

mobs:register_monster("mobs:sand_monster", {
	hp_max = 3,
	physical = true,
	collisionbox = {-0.4, -1, -0.4, 0.4, 1, 0.4},
	visual = "upright_sprite",
	visual_size = {x=1, y=2},
	textures = {"mobs_sand_monster.png", "mobs_sand_monster_back.png"},
	makes_footstep_sound = true,
	view_range = 15,
	walk_velocity = 1.5,
	run_velocity = 4,
	damage = 1,
	drop = "default:sand",
	light_resistant = true,
})

minetest.register_abm({
	nodenames = {"default:desert_sand"},
	neighbors = {"default:desert_sand", "default:desert_stone"},
	interval = 60,
	chance = 5000,
	action = function(pos, node)
		pos.y = pos.y+1
		if minetest.env:get_node(pos).name ~= "air" then
			return
		end
		pos.y = pos.y+1
		if minetest.env:get_node(pos).name ~= "air" then
			return
		end
		minetest.env:add_entity(pos, "mobs:sand_monster")
	end
})
