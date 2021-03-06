--I have no idea where I got this function from
function distance( x1, y1, x2, y2 )
	local dx = x1 - x2
	local dy = y1 - y2
	return math.sqrt ( dx * dx + dy * dy )
end

--http://stackoverflow.com/questions/2705793/how-to-get-number-of-entries-in-a-lua-table
function tablelength(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end

-- Round 'v' to 'p' decimal places https://love2d.org/forums/viewtopic.php?f=4&t=146#p1508
function round(v, p)
	local scale = math.pow(10, p or 0);
	local res = math.floor(math.abs(v) * scale + 0.5) / scale;
    if v < 0 then 
        res = -res; 
    end;
    return res;
end;

function force_load_train(self)
	local chunkpos  = self.object:getpos()
	minetest.forceload_block(chunkpos)
	minetest.forceload_block({x=chunkpos.x-5, y=chunkpos.y, z=chunkpos.z})
	minetest.forceload_block({x=chunkpos.x+5, y=chunkpos.y, z=chunkpos.z})
	minetest.forceload_block({x=chunkpos.x, y=chunkpos.y, z=chunkpos.z-5})
	minetest.forceload_block({x=chunkpos.x, y=chunkpos.y, z=chunkpos.z+5})
end

train_functions = {}


function train_functions.activate(self,staticdata)
	self.object:set_armor_groups({immortal=1})
	if self.id == nil then
		self.id = train_id
	end
	--deserialization
	if staticdata then
		local data = minetest.deserialize(staticdata)
		if data then
			self.gear      = data.gear
			self.lastpos   = data.lastpos
			self.stop      = data.stop
			self.position  = data.position
			self.direction = data.direction
			self.id        = data.id
		end
	end
end

function train_functions.remove_entities(self, hitter)
	--have this remove the table in the train tables
	self.object:remove()
	self.cotruck.object:remove()
	if train_table[self.id] ~= nil then
		if train_table[self.id][3] ~= nil then
			train_table[self.id][3].object:remove()
		end
	end
end
function train_functions.serialize(self)
	self.tmp = {
		gear      = self.gear,
		lastpos   = self.lastpos,
		stop      = self.stop,
		position  = self.position,
		id        = self.id,
		direction = self.direction,
	}
end



--this cannot exceed 1 block per tick or the mod will become messed up
function train_on_track(self,position)
	--check if cotruck exists or if needed to be stopped - do this here to prevent unneeded cpu usage - this is also for very long cars
	if self.cotruck.object:get_luaentity() == nil then
		print("stop and force load it's area")
		return
	end
	if self.stop == true then
		return
	end
	
	local pos    = self.object:getpos()
	local pos    = {x=round(pos.x, round_to),y=round(pos.y, round_to),z=round(pos.z, round_to)}--make it nice and even -- move this to the end as well so it is displayed perfectly
	local center = {x=math.floor(pos.x + 0.5),y=math.floor(pos.y + 0.5),z=math.floor(pos.z + 0.5)} 	
	--0 and 2 are z 1 and 3 are x
	--a and c are z b and d are x
	--e is always current pos (think engine)
	--check clockwise
	local a = minetest.get_node_group(minetest.get_node({x=pos.x,y=pos.y,z=pos.z+prediction_distance}).name, "track")
	local b = minetest.get_node_group(minetest.get_node({x=pos.x+prediction_distance,y=pos.y,z=pos.z}).name, "track")
	local c = minetest.get_node_group(minetest.get_node({x=pos.x,y=pos.y,z=pos.z-prediction_distance}).name, "track")
	local d = minetest.get_node_group(minetest.get_node({x=pos.x-prediction_distance,y=pos.y,z=pos.z}).name, "track")
	local e = minetest.get_node_group(minetest.get_node(pos).name, "track")
	
	local a2 = minetest.get_node({x=pos.x,y=pos.y,z=pos.z+prediction_distance}).param2
	local b2 = minetest.get_node({x=pos.x+prediction_distance,y=pos.y,z=pos.z}).param2
	local c2 = minetest.get_node({x=pos.x,y=pos.y,z=pos.z-prediction_distance}).param2
	local d2 = minetest.get_node({x=pos.x-prediction_distance,y=pos.y,z=pos.z}).param2
	local e2 = minetest.get_node(pos).param2
	
	--print("a:"..a.."|b:"..b.."|c:"..c.."|d:"..d.."|e:"..e.."|a2:"..a2.."|b2:"..b2.."|c2:"..c2.."|d2:"..d2.."|e2:"..e2) --massive debug
	
	--check if track in front of you while on a straight
	if e == 1 then 
		--z related track
		if e2 == 0 then
			if self.direction == 0 then
				if a == 1 then 
					if a2 == 0 then
						self.object:moveto({x=pos.x,y=pos.y,z=pos.z+train_speed}, false)
					end
				end
			elseif self.direction == 2 then
				if c == 1 then
					if c2 == 0 then 
						self.object:moveto({x=pos.x,y=pos.y,z=pos.z-train_speed}, false)
					end
				end
			end
		-- x related track
		elseif e2 == 1 then 
			if self.direction == 1 then
				if b == 1 then 
					if b2 == 1 then
						self.object:moveto({x=pos.x+train_speed,y=pos.y,z=pos.z}, false)
					end
				end
			elseif self.direction == 3 then
				if d == 1 then
					if d2 == 1 then 
						self.object:moveto({x=pos.x-train_speed,y=pos.y,z=pos.z}, false)
					end
				end
			end
		end
		
		--check if turn is matching
		--z related straight track
		if e2 == 0 then
			if self.direction == 0 then
				if a == 2 then
					if a2 == 2 or a2 == 3 then
						self.object:moveto({x=pos.x,y=pos.y,z=pos.z+train_speed}, false)
					end
				end
			elseif self.direction == 2 then
				if c == 2 then
					if c2 == 0 or c2 == 1 then
						self.object:moveto({x=pos.x,y=pos.y,z=pos.z-train_speed}, false)
					end
				end
			end
		--x related straight track
		elseif e2 == 1 then
			if self.direction == 1 then
				if b == 2 then
					if b2 == 0 or b2 == 3 then
						self.object:moveto({x=pos.x+train_speed,y=pos.y,z=pos.z}, false)
					end
				end
			elseif self.direction == 3 then
				if d == 2 then
					if d2 == 1 or d2 == 2 then
						self.object:moveto({x=pos.x-train_speed,y=pos.y,z=pos.z}, false)
					end
				end
			end
		end
	--handle turning and turn prediction	 	 
	elseif e == 2 then 
		if e2 == 0 then
			if self.direction == 0 then
				if (a == 1 and a2 == 0) or (a == 2 and (a2 == 2 or a2 == 3))  then
					self.object:moveto({x=center.x,y=pos.y,z=pos.z+train_speed}, false)
				end
			elseif self.direction == 1 then
				if math.abs(round(pos.x-center.x, round_to)) > 0 then
					self.object:moveto({x=pos.x+train_speed,y=pos.y,z=pos.z}, false)
				elseif math.abs(round(pos.x-center.x, round_to)) == 0 then
					self.direction = 0
					self.object:moveto({x=center.x,y=pos.y,z=pos.z+train_speed}, false)
				end
			elseif self.direction == 2 then
				if math.abs(round(pos.z-center.z, round_to)) > 0 then
					self.object:moveto({x=pos.x,y=pos.y,z=pos.z-train_speed}, false)
				elseif math.abs(round(pos.z-center.z, round_to)) == 0 then
					self.direction = 3
					self.object:moveto({x=pos.x-train_speed,y=pos.y,z=center.z}, false)
				end
			elseif self.direction == 3 then
				if (d == 1 and d2 == 1) or (d == 2 and (d2 == 1 or d2 == 2))  then
					self.object:moveto({x=pos.x-train_speed,y=pos.y,z=center.z}, false)
				end
			end	
		elseif e2 == 1 then
			if self.direction == 0 then
				if (a == 1 and a2 == 0) or (a == 2 and (a2 == 2 or a2 == 3))  then
					self.object:moveto({x=center.x,y=pos.y,z=pos.z+train_speed}, false)
				end
			elseif self.direction == 1 then
				if (b == 1 and b2 == 1) or (b == 2 and (b2 == 0 or b2 == 3))  then
					self.object:moveto({x=pos.x+train_speed,y=pos.y,z=center.z}, false)
				end
			elseif self.direction == 2 then
				if math.abs(round(pos.z-center.z, round_to)) > 0 then
					self.object:moveto({x=pos.x,y=pos.y,z=pos.z-train_speed}, false)
				elseif math.abs(round(pos.z-center.z, round_to)) == 0 then
					self.direction = 1
					self.object:moveto({x=pos.x+train_speed,y=pos.y,z=center.z}, false)
				end
			elseif self.direction == 3 then
				if math.abs(round(pos.x-center.x, round_to)) > 0 then
					self.object:moveto({x=pos.x-train_speed,y=pos.y,z=pos.z}, false)
				elseif math.abs(round(pos.x-center.x, round_to)) == 0 then
					self.direction = 0
					self.object:moveto({x=center.x,y=pos.y,z=pos.z+train_speed}, false)
				end				
			end
		elseif e2 == 2 then
			if self.direction == 0 then
				if math.abs(round(pos.z-center.z, round_to)) > 0 then
					self.object:moveto({x=pos.x,y=pos.y,z=pos.z+train_speed}, false)
				elseif math.abs(round(pos.z-center.z, round_to)) == 0 then
					self.direction = 1
					self.object:moveto({x=pos.x+train_speed,y=pos.y,z=center.z}, false)
				end	
			elseif self.direction == 1 then
				if (b == 1 and b2 == 1) or (b == 2 and (b2 == 0 or b2 == 3))  then
					self.object:moveto({x=pos.x+train_speed,y=pos.y,z=center.z}, false)
				end
			elseif self.direction == 2 then
				if (c == 1 and c2 == 0) or (c == 2 and (c2 == 0 or c2 == 1))  then
					self.object:moveto({x=center.x,y=pos.y,z=pos.z-train_speed}, false)
				end
			elseif self.direction == 3 then
				if math.abs(round(pos.x-center.x, round_to)) > 0 then
					self.object:moveto({x=pos.x-train_speed,y=pos.y,z=pos.z}, false)
				elseif math.abs(round(pos.x-center.x, round_to)) == 0 then
					self.direction = 2
					self.object:moveto({x=center.x,y=pos.y,z=pos.z-train_speed}, false)
				end				
			end
		elseif e2 == 3 then
			if self.direction == 0 then
				if math.abs(round(pos.z-center.z, round_to)) > 0 then
					self.object:moveto({x=pos.x,y=pos.y,z=pos.z+train_speed}, false)
				elseif math.abs(round(pos.z-center.z, round_to)) == 0 then
					self.direction = 3
					self.object:moveto({x=pos.x-train_speed,y=pos.y,z=center.z}, false)
				end
			elseif self.direction == 1 then
				if math.abs(round(pos.x-center.x, round_to)) > 0 then
					self.object:moveto({x=pos.x+train_speed,y=pos.y,z=pos.z}, false)
				elseif math.abs(round(pos.x-center.x, round_to)) == 0 then
					self.direction = 2
					self.object:moveto({x=center.x,y=pos.y,z=pos.z-train_speed}, false)
				end
			elseif self.direction == 2 then
				if (c == 1 and c2 == 0) or (c == 2 and (c2 == 0 or c2 == 1))  then
					self.object:moveto({x=center.x,y=pos.y,z=pos.z-train_speed}, false)
				end
			elseif self.direction == 3 then
				if (d == 1 and d2 == 1) or (d == 2 and (d2 == 1 or d2 == 2))  then
					self.object:moveto({x=pos.x-train_speed,y=pos.y,z=center.z}, false)
				end
			end
		end
	end
	--set the lastpos so you can use it to equal the distance between the trucks when they stop
	local lastpos    = self.object:getpos()
	self.lastpos    = {x=round(pos.x, round_to),y=round(pos.y, round_to),z=round(pos.z, round_to)}	
	
	
	--make sure that everything is even and absolute
	local newpos = self.object:getpos()
	local newpos = {x=round(newpos.x, round_to),y=round(newpos.y, round_to),z=round(newpos.z, round_to)}
	self.object:setpos(newpos)

	--then check if other truck is stopped, if other truck doesn't exist, stop -- this needs a simple value added for single entity cars and engines
	if self.cotruck ~= nil then
		if newpos.x == pos.x and newpos.y == pos.y and newpos.z == pos.z and self.stop == false then
			self.cotruck.stop = true
		else
			self.cotruck.stop = false
		end
	elseif self.cotruck == nil then
		self.stop = true
	end
	
	
end


	--[[
	DOCUMENTATION ON TURNS
	0 = +x and -z
	1 = -x and -z
	2 = -x and +z
	3 = +x and +z
	
	a = z+1
	b = x+1
	c = z-1
	d = x-1

	entity direction
	0+ 2- = z
	1+ 3- = x
	
	rails
	0 = z
	1 = x 
	
	 ]]--	










--[[
                                       You found casper, the friendly bug.

                                         .,,cccd$$$$$$$$$$$ccc,
                                     ,cc$$$$$$$$$$$$$$$$$$$$$$$$$cc,
                                   ,d$$$$$$$$$$$$$$$$"J$$$$$$$$$$$$$$c,
                                 d$$$$$$$$$$$$$$$$$$,$" ,,`?$$$$$$$$$$$$L
                               ,$$$$$$$$$$$$$$$$$$$$$',J$$$$$$$$$$$$$$$$$b
                              ,$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$i `$h
                              $$$$$$$$$$$$$$$$$$$$$$$$$P'  "$$$$$$$$$$$h $$
                             ;$$$$$$$$$$$$$$$$$$$$$$$$F,$$$h,?$$$$$$$$$$h$F
                             `$$$$$$$$$$$$$$$$$$$$$$$F:??$$$:)$$$$P",. $$F
                              ?$$$$$$$$$$$$$$$$$$$$$$(   `$$ J$$F"d$$F,$F
                               ?$$$$$$$$$$$$$$$$$$$$$h,  :P'J$$F  ,$F,$"
                                ?$$$$$$$$$$$$$$$$$$$$$$$ccd$$`$h, ",d$
                                 "$$$$$$$$$$$$$$$$$$$$$$$$",cdc $$$$"
                        ,uu,      `?$$$$$$$$$$$$$$$$$$$$$$$$$$$c$$$$h
                    .,d$$$$$$$cc,   `$$$$$$$$$$$$$$$$??$$$$$$$$$$$$$$$,
                  ,d$$$$$$$$$$$$$$$bcccc,,??$$$$$$ccf `"??$$$$??$$$$$$$
                 d$$$$$$$$$$$$$$$$$$$$$$$$$h`?$$$$$$h`:...  d$$$$$$$$P
                d$$$$$$$$$$$$$$$$$$$$$$$$$$$$`$$$$$$$hc,,cd$$$$$$$$P"
            =$$?$$$$$$$$P' ?$$$$$$$$$$$$$$$$$;$$$$$$$$$???????",,
               =$$$$$$F       `"?????$$$$$$$$$$$$$$$$$$$$$$$$$$$$$bc
               d$$F"?$$k ,ccc$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$i
        .     ,ccc$$c`""u$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$P",$$$$$$$$$$$$h
     ,d$$$L  J$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$" `""$$$??$$$$$$$
   ,d$$$$$$c,"$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$F       `?J$$$$$$$'
  ,$$$$$$$$$$h`$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$F           ?$$$$$$$P""=,
 ,$$$F?$$$$$$$ $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$F              3$$$$II"?$h,
 $$$$$`$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$P"               ;$$$??$$$,"?"
 $$$$F ?$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$P",z'                3$$h   ?$F
        `?$$$$$$$$$$$$$$$??$$$$$$$$$PF"',d$P"                  "?$F
           """""""         ,z$$$$$$$$$$$$$P
                          J$$$$$$$$$$$$$$F
                         ,$$$$$$$$$$$$$$F
                         :$$$$$c?$$$$PF'
                         `$$$$$$$P
                          `?$$$$F
                          
]]--
