pico-8 cartridge // http://www.pico-8.com
version 35
__lua__

function _init()
 clock_frame = 0

 camera_x1 = 0
 camera_y1 = 0
 camera_x2 = camera_x1 + 127
 camera_y2 = camera_y1 + 127
 camera_vx = 1
 camera_vy = 0

 helicopter_x = 32
 helicopter_y = 64
 helicopter_vx = camera_vx
 helicopter_vy = camera_vy
 helicopter_min_vy = -1.5
 helicopter_max_vy = 2.5
 helicopter_gravity = 0.1

 rotor_engaged = false
 rotor_vy = 0
 rotor_power = -0.3
 rotor_start_frame = 0
 rotor_charging_boost = false
 rotor_boost_frame = 0

 cave_floor = fill(128*helicopter_vx, 113)
 cave_roof = fill(128*helicopter_vx, 15)
 cave_x1 = camera_x1
 cave_x2 = cave_x1 + 127
 cave_y1 = cave_roof[chunk_length]
 cave_y2 = cave_floor[chunk_length]

 chunk_x1 = cave_x1
 chunk_x2 = cave_x2

end

function _update60()
 clock_frame += 1

 camera_x1 += camera_vx
 camera_y1 += camera_vy
 camera_x2 = camera_x1 + 127
 camera_y2 = camera_y1 + 127

 rotor_engaged = btn(5)
 if rotor_start_frame == nil and rotor_engaged then
  rotor_start_frame = clock_frame
  rotor_charging_boost = helicopter_vy == helicopter_max_vy
 elseif clock_frame - rotor_boost_frame > 256 then
  helicopter_vx = max(1, helicopter_vx-1)
  camera_vx = helicopter_vx
  rotor_charging_boost = false
  rotor_boost_frame = clock_frame
 end

 if rotor_engaged then
  rotor_vy = rotor_power
  if rotor_charging_boost and helicopter_vy == helicopter_min_vy and clock_frame - rotor_start_frame > 40 then
   helicopter_vx += 1
   camera_vx += 1
   rotor_charging_boost = false
   rotor_boost_frame = clock_frame
  end
 else
  rotor_start_frame = nil
  rotor_charging_boost = false
  rotor_vy = 0
 end

 helicopter_vy += helicopter_gravity
 helicopter_vy += rotor_vy
 helicopter_vy = mid(
  helicopter_min_vy,
  helicopter_vy,
  helicopter_max_vy
 )

 local hitbox_x1 = helicopter_x - 4
 local hitbox_y1 = helicopter_y - 6
 local hitbox_x2 = hitbox_x1 + 8
 local hitbox_y2 = hitbox_y1 + 12
 for x = hitbox_x1,hitbox_x2 do
  local i = x-camera_x1
  local roof = cave_roof[i]
  local floor = cave_floor[i]
  for y = hitbox_y1,hitbox_y2 do
   local i = flr(x) - camera_x1
   if y < cave_roof[i] then
    helicopter_vy = 1
    goto boom
   end
   if y > cave_floor[i] then
    helicopter_vy = -1
    goto boom
   end
  end
 end
 ::boom::

 helicopter_x += helicopter_vx
 helicopter_y += helicopter_vy

end

function _draw()
 camera(camera_x1, camera_y1)
 cls(0)

 for i = 1,8 do
  local xp = 2 ^ (helicopter_vx + 3)
  local cs = 2 ^ (helicopter_vx + 6)
  local mx = camera_x1%xp
  local my = camera_y1%16
  local lx = camera_x1+(i*xp)-mx
  local ly = camera_y1+(i*16)-my
  local cx = 1
  local cy = 1
  if lx % cs == 0 then
   cx = 13
  end
  line(camera_x1, ly, camera_x1+127, ly, cy)
  line(lx, camera_y1, lx, camera_y1+127, cx)
 end

 for i = 1, 128 do
  local x = camera_x1+i-1
  local cr = cave_roof[i]
  local cf = cave_floor[i]
  line(x, camera_y1, x, cr, 5)
  line(x, cf, x, camera_y2, 5)
 end

 circfill(helicopter_x, helicopter_y, 4, 11)

 camera(0,0)
 print(clock_frame, 4, 4)

end

function static(y)
 return terrain(
  function(p)
   return y
  end
 )
end

function noise(n)
 return terrain(
  function(p)
   if p == 1 then
    return 0
   else
    return flr(rnd(2^n)) - 2^n/2
   end
  end
 )
end

function linear(y)
 return terrain(
  function(p)
   return p * y
  end
 )
end

function chunk(y1, y2)
 local c = {y1,y2}
 setmetatable(c, {
  __add = chunk_add,
  __and = chunk_and,
  __call = chunk_call,
 })
 return c
end

function chunk_add(c1, c2)
 return chunk(
  c1[1] + c2[1],
  c1[2] + c2[2]
 )
end

function chunk_and(c1, c2)
 for y in all(c2) do
  add(c1, y)
 end
 return c1
end

function chunk_call(c, p)
 local v = {}
 for t in all(c) do
  local y = t(p)
  if y ~= nil then
   add(v, y)
  end
 end
 sort(v)
 return v
end



function terrain(fn)
 local t = {fn}
 setmetatable(t, {
  __add = terrain_add,
  __call = terrain_call,
  __mod = terrain_mod,
  __mul = terrain_mul,
 })
 return t
end

function terrain_add(t1, t2)
 return terrain(
  function(p)
   local y1 = t1(p)
   local y2 = t2(p)
   if y1 == nil or y2 == nil then
    return nil
   end
   return y1 + y2
  end
 )
end

function terrain_call(t, p)
 if p == nil then
  return nil
 else
  return t[1](p)
 end
end

function terrain_mod(t1, t2)
 return terrain(
  function(p)
   local y1 = t2(p)
   local y2 = t1(y1)
   if y1 == nil or y2 == nil then
    return nil
   end
   return y2
  end
 )
end

function terrain_mul(t1, t2)
 return terrain(
  function(p)
   local y1 = t1(p)
   local y2 = t2(p)
   if y1 == nil or y2 == nil then
    return nil
   end
   return y1 * y2
  end
 )
end

function fill(n, v)
 local tbl = {}
 for i = 1,n do
  add(tbl, v)
 end
 return tbl
end

