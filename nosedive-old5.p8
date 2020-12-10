pico-8 cartridge // http://www.pico-8.com
version 29
__lua__
-- nosedive
-- by hen

function _init()
 debug_color = 8
 debug_messages = {}
 
 explosion_position = nil

 level_queue = {
  level:easy(),
  level:pythagup(),
  level:ubend(),
  level:circleup(),
  level:easy(),
  level:bendup(),
  level:bottleneck(),
  level:easy(),
  level:ubend(),
  level:easy(),
 }
 
 next_level()

 camera_position = xy(0, 0)
 camera_velocity = xy(1, 0)
 camera_error_count = 0
 camera_move_frame = nil
 camera_target_depth = nil

 clock_frame = 0

 coins = {}

 collision_point = nil

 gravity_velocity = xy(0, 0.1)

 cave_floor = {}
 cave_floor_blur_colors = {}
 cave_floor_blur_heights = {}
 cave_floor_edge_colors = {}
 cave_floor_edge_heights = {}
 cave_roof = {}
 cave_roof_blur_colors = {}
 cave_roof_blur_heights = {}
 cave_roof_edge_colors = {}
 cave_roof_edge_heights = {}

 for x = 0, 127 do
  add(cave_floor, xy(x, 119))
  add(cave_floor_blur_colors, 1)
  add(cave_floor_blur_heights, 0)
  add(cave_floor_edge_colors, 7)
  add(cave_floor_edge_heights, 0)
  add(cave_roof, xy(x, 8))
  add(cave_roof_blur_colors, 1)
  add(cave_roof_blur_heights, 0)
  add(cave_roof_edge_colors, 7)
  add(cave_roof_edge_heights, 0)
 end

 helicopter_alive = true
 helicopter_died = nil
 helicopter_inclination = "hovering"
 helicopter_position = xy(48, 80)
 helicopter_velocity = xy(1, 0)

 hitbox_offset = xy(-4, -4)
 hitbox_box = box(helicopter_position + hitbox_offset, xy(8, 8))

 rotor_engaged = false
 rotor_velocity = xy(0, 0)

 smoke_puffs = {}

 chunk_queue = {
  chunk:straight(),
 }

 next_chunk()

 for x = 1, 128 do
  local chunk_slice = pump_chunk()
  local rp = xy(x, chunk_start_roof + chunk_slice.roof)
  local fp = xy(x, chunk_start_floor + chunk_slice.floor)
  add_cave(x, rp, fp)
  if chunk_slice.coin ~= nil then
   local cp = xy(x, rp.y + ((fp.y - rp.y) * chunk_slice.coin))
   add(coins, cp)
  end
 end

 speed(1)
end

-->8
-- update

function _update60()
 update_clock()
 update_camera()
 update_cave()
 update_chunk()
 update_coins()
 update_rotor()
 update_helicopter()
 update_hitbox()
 update_collision()
 update_smoke()
 update_explosion()
end

function avg(l)
 local t = 0
 for i in all(l) do
  t += i
 end
 return t / #l
end

function update_camera()
 if not helicopter_alive then
  if (clock_frame - helicopter_died) % 8 == 0 then
   camera_velocity.x = max(0, camera_velocity.x - 1)
  end
 end

 local ideal_camera_depth = avg({
  cave_roof[32].y,
  cave_floor[32].y,
  cave_roof[96].y,
  cave_floor[96].y,
 }) - 64
 local camera_error_offset = camera_position.y - ideal_camera_depth
 local camera_error_magnitude = abs(camera_error_offset)

 if camera_error_magnitude < 2 then
  camera_error_count = 0
 else
  camera_error_count += 1
 end

 if camera_error_count > 1 then
  camera_velocity.y = camera_error_offset
   * (camera_error_count / 256)
   * -1
 end

 camera_position += camera_velocity
end

function update_cave()
 if camera_velocity.x == 0 then
  return
 end

 for h = 1, camera_velocity.x do
   for i = 1, 127 do
    local j = min(128, i + 1)
    cave_roof[i].x = cave_roof[j].x
    cave_roof[i].y = cave_roof[j].y
    cave_floor[i].x = cave_floor[j].x
    cave_floor[i].y = cave_floor[j].y
    cave_floor_blur_heights[i] = cave_floor_blur_heights[j]
    cave_floor_edge_heights[i] = cave_floor_edge_heights[j]
    cave_roof_blur_heights[i] = cave_roof_blur_heights[j]
    cave_roof_edge_heights[i] = cave_roof_edge_heights[j]
   end
 end

 for i = 1, 128 do
  if helicopter_position.x - camera_position.x > i then
   cave_roof_edge_colors[i] = 1
   cave_floor_edge_colors[i] = 1
  else
   if helicopter_position.y - cave_roof[i].y - (i/2) < 8 then
    cave_roof_edge_colors[i] = 7
   else
    cave_roof_edge_colors[i] = 1
   end
  
   if cave_floor[i].y - helicopter_position.y - (i/2) < 8 then
    cave_floor_edge_colors[i] = 7
   else
    cave_floor_edge_colors[i] = 1
   end
  end
 end
end

function update_clock()
 clock_frame += 1
end

function update_coins()
 for coin in all(coins) do
  if coin.x < camera_position.x - 8 then
   dbg("del coin")
   del(coins, coin)
  end
 end
end

function update_collision()
 if explosion_position ~= nil then
  return
 end
 collision_point = nil

 for i = 1, hitbox_box.size.x do
  local j = hitbox_box.position.x - camera_position.x + (hitbox_box.size.x - i)

  local roof = cave_roof[j]
  if hitbox_box:contains(roof) then
   collision_point = roof
   break
  end

  if hitbox_box.y1 < roof.y then
   collision_point = helicopter_position + xy(4, 0)
   break
  end

  local floor = cave_floor[j]
  if hitbox_box:contains(floor) then
   collision_point = floor
   break
  end

  if hitbox_box.y2 > floor.y then
   collision_point = helicopter_position + xy(4, 0)
   break
  end
 end

 if collision_point ~= nil then
  dbg("boom " .. helicopter_position.x .. " " .. helicopter_position.y)
  dbg(collision_point.x .. " " .. collision_point.y)
  helicopter_alive = false
  helicopter_died = clock_frame

  camera(camera_position.x, camera_position.y)
  line(
   helicopter_position.x,
   helicopter_position.y,
   collision_point.x,
   collision_point.y,
   8
  )

  local dx = collision_point.x - helicopter_position.x
  local dy = -(collision_point.y - helicopter_position.y)
  local angle = atan2(dx, dy)
  dbg(angle)

  local p = xy(
   helicopter_position.x + 8 * cos(angle),
   helicopter_position.y - 8 * sin(angle)
  )

  if collision_point:below(helicopter_position) then
   helicopter_velocity.y = -2
  else
   helicopter_velocity.y = 2
  end
 end
end

function update_explosion()
 if explosion_position == nil and collision_point ~= nil then
  if not collision_point:above(helicopter_position) then
   dbg("m")
   explosion_position = collision_point
  end
 end
end

function update_helicopter()
 if explosion_position ~= nil then
  helicopter_velocity = xy(0, 0)
 else
  helicopter_velocity += rotor_velocity + gravity_velocity
  helicopter_velocity.y = mid(-1.5, helicopter_velocity.y, 1.9)
  helicopter_position += helicopter_velocity
 end

 if helicopter_velocity.y > 0 and not rotor_engaged then
  helicopter_inclination = "dropping"
 elseif helicopter_velocity.y < 0 and rotor_engaged then
  helicopter_inclination = "climbing"
 else
  helicopter_inclination = "hovering"
 end
end

function update_hitbox()
 if explosion_position == nil then
  hitbox_box:move(helicopter_position + hitbox_offset)
 end
end

function update_chunk()
 for i = 1, camera_velocity.x do
  local li = 128 - i + 1
  local lx = cave_roof[128 - i].x + 1
  local chunk_slice = pump_chunk()

  local rp = xy(lx, chunk_start_roof + chunk_slice.roof)
  local fp = xy(lx, chunk_start_floor + chunk_slice.floor)

  add_cave(li, rp, fp)

  if chunk_slice.coin ~= nil then
   local cp = xy(lx, rp.y + ((fp.y - rp.y) * chunk_slice.coin))
   add(coins, cp)
  end
 end
end

function update_rotor()
 rotor_engaged = btn(5)
 if helicopter_alive and rotor_engaged then
  rotor_velocity.y = -0.3
 else
  rotor_velocity.y = 0
 end
end

function update_smoke()
 for i, puff in pairs(smoke_puffs) do
  puff.position.x += puff.velocity.x / 16
  puff.position.y += puff.velocity.y / 8
  puff.age += 1
  if puff.age % 20 == 0 then
   puff.radius -= 1
  end
  if puff.radius < 0 then
   del(smoke_puffs, smoke_puffs[1])
  end
 end

 if helicopter_alive and clock_frame % 4 == 0 then
  local puff_radius = 0
  if rotor_engaged then
   puff_radius = 1
  end
  add(smoke_puffs, {
   position = helicopter_position - xy(8, 0),
   velocity = helicopter_velocity,
   radius = puff_radius,
   age = 0,
  })
 end
end

-->8
-- draw

function _draw()
 camera(camera_position.x, camera_position.y)
 draw_cave()
 draw_coins()
 draw_smoke()
 draw_helicopter()
 draw_hitbox()
 draw_collision()
 draw_explosion()

 camera(0, 0)
 draw_overlay()
end

function draw_cave()
 local camera_top = camera_position.y - 2
 local camera_bottom = camera_position.y + 128 + 4

 for i = 1, 128 do
  local x = i + camera_position.x - 1
  local roof = cave_roof[i].y
  local floor = cave_floor[i].y

  line(x, roof, x, floor, 0)
  line(x, camera_top, x, roof, 5)
  line(x, roof, x, roof - cave_roof_blur_heights[i], cave_roof_blur_colors[i])
  line(x, roof, x, roof - cave_roof_edge_heights[i], cave_roof_edge_colors[i])
  line(x, floor, x, camera_bottom, 5)
  line(x, floor, x, floor + cave_floor_blur_heights[i], cave_floor_blur_colors[i])
  line(x, floor, x, floor + cave_floor_edge_heights[i], cave_floor_edge_colors[i])
 end
end

function draw_coins()
 for coin in all(coins) do
  spr(64 + loop(clock_frame, 24, 24), coin.x, coin.y)
 end
end

function draw_helicopter()
 local helicopter_sprite_column = ({
  hovering = 1,
  dropping = 2,
  climbing = 3,
 })[helicopter_inclination]

 local helicopter_sprite_x = (helicopter_sprite_column - 1) * 16

 local tail_y_offset = ({
  hovering = 2,
  dropping = 0,
  climbing = 3,
 })[helicopter_inclination]

 sspr(
  helicopter_sprite_x,
  0,
  16,
  8,
  helicopter_position.x - 8,
  helicopter_position.y - 4
 )

 sspr(
  helicopter_sprite_x + 3,
  8 + loop(clock_frame, 32, 8) * 3,
  13,
  3,
  helicopter_position.x - 5,
  helicopter_position.y - 5
 )

 sspr(
  helicopter_sprite_x,
  8 + loop(clock_frame, 8, 8) * 3,
  3, 3,
  helicopter_position.x - 8,
  helicopter_position.y + tail_y_offset - 4
 )
end

function draw_collision()
 if collision_point == nil then
  return
 end

 circ(
  collision_point.x,
  collision_point.y,
  2,
  12
 )

 circ(
  helicopter_position.x,
  helicopter_position.y,
  2,
  8
 )

end

function draw_explosion()
 if explosion_position ~= nil then
  circfill(
   explosion_position.x,
   explosion_position.y,
   8,
   8
  )
 end
end

function draw_hitbox()
 rect(
  hitbox_box.x1,
  hitbox_box.y1,
  hitbox_box.x2,
  hitbox_box.y2,
  11
 )

 for i = 1, hitbox_box.size.x do
  pset(
   hitbox_box.position.x + i,
   hitbox_box.position.y + hitbox_box.size.y,
   11
  )

  local roof_color = 11
  local floor_color = 11
  if hitbox_box:contains(cave_roof[hitbox_box.position.x - camera_position.x + i]) then
   roof_color = 14
  end
  if hitbox_box:contains(cave_floor[hitbox_box.position.x - camera_position.x + i]) then
   floor_color = 14
  end

  line(
   hitbox_box.position.x + i,
   cave_roof[hitbox_box.position.x - camera_position.x + i].y,
   hitbox_box.position.x + i,
   cave_roof[hitbox_box.position.x - camera_position.x + i].y - 1,
   roof_color
  )

  line(
   hitbox_box.position.x + i,
   cave_floor[hitbox_box.position.x - camera_position.x + i].y,
   hitbox_box.position.x + i,
   cave_floor[hitbox_box.position.x - camera_position.x + i].y + 1,
   floor_color
  )
 end
end

function draw_overlay()
 draw_bar("cpu", stat(1), 1, 123)
 draw_bar("chk", chunk_progress, 32, 123)
 draw_bar("lvl", level_progress, 64, 123)

 for i,debug_message in pairs(debug_messages) do
   print(debug_message[1], 0, (i-1)*8, debug_message[2])
 end
end

function draw_bar(l, p, x, y)
 line(x+1, y+1, x+14, y+1, 5)
 line(x+1, y+1, x+14*p, y+1, 7)
 rect(x, y, x+15, y+2, 1)
 print(l, x+17, y-1, 7)
end

function draw_smoke()
 for i, puff in pairs(smoke_puffs) do
  circ(puff.position.x, puff.position.y, puff.radius, 7)
 end
end

-->8
-- levels

level = (function()
 local level = {}

 setmetatable(level, {
  __call = function(_, chunks)
   return {
    chunks = chunks,
   }
  end
 })

 function level:bendup()
  return level({
   chunk:sine(),
  })
 end

 function level:bottleneck()
  return level({
   chunk:narrow(),
   chunk:widen(),
  })
 end

 function level:circleup()
  return level({
   chunk:fourcircles(),
  })
 end

 function level:easy()
  return level({
   chunk:straight(),
  })
 end

 function level:pythagup()
  return level({
   chunk:pythag(16, 1, 1),
   chunk:pythag(16, 1, -1),
   chunk:pythag(16, -1, 1),
   chunk:pythag(16, -1, -1),
  })
 end

 function level:ubend()
  return level({
   chunk:ubend(),
  })
 end

 return level
end)()

function next_level()
 dbg("next level")

 if #level_queue == 0 then
  add(level_queue, level:easy())
 end

 local level_object = level_queue[1]
 del(level_queue, level_object)

 chunk_queue = level_object.chunks
 level_length = #chunk_queue
 level_progress = 0
end


-->8
-- chunks

chunk = (function()
 local chunk = {}

 setmetatable(chunk, {
  __call = function(_, length, roof, floor, coins)
   return {
    length = length,
    roof = roof,
    floor = floor,
    coins = coins or {},
   }
  end
 })

 function chunk:fourcircles()
  return chunk(
   128,
   terrain:twocircles(64),
   terrain:twocircles(64)
  )
 end

 function chunk:narrow()
  return chunk(
   128,
   terrain:noise(2) + terrain:descend(32) + terrain:sinewave(2, 2),
   terrain:noise(2) + terrain:ascend(32) + terrain:sinewave(2, 2)
  )
 end

 function chunk:pythag(l, direction, side)
  return chunk(
   l,
   terrain:pythagstep(l, direction, side),
   terrain:pythagstep(l, -direction, side)
  )
 end

 function chunk:sine()
  return chunk(
   128,
   terrain:curveup(512),
   terrain:curveup(512)
  )
 end

 function chunk:straight()
  return chunk(
   128,
   terrain:noise(2),
   terrain:noise(2),
   {{ 0.9, 0.5 }}
  )
 end

 function chunk:ubend()
  return chunk(
   256,
   terrain:noise(1) + terrain:sinewave(8, 4) + terrain:fudge(24) + terrain:descend(128),
   terrain:noise(1) + terrain:sinewave(8, 4) + terrain:fudge(-24) + terrain:descend(128),
   {
    { 0.2, 0.8 },
    { 0.3, 0.2 },
    { 0.45, 0.8 },
    { 0.55, 0.2 },
    { 0.7, 0.8 },
    { 0.8, 0.2 },
    { 0.95, 0.8 },
    }
  )
 end

 function chunk:widen()
  return chunk(
   64,
   terrain:ascend(32) + terrain:sinewave(2, 2),
   terrain:descend(32) + terrain:sinewave(2, 2)
  )
 end

 return chunk
end)()

function next_chunk()
 dbg("next chunk")
 level_progress = (level_length - #chunk_queue) / level_length

 if #chunk_queue == 0 then
  next_level()
 end

 chunk_object = chunk_queue[1]
 del(chunk_queue, chunk_object)
 chunk_distance = 0
 chunk_progress = 0
 chunk_start_roof = cave_roof[127].y
 chunk_start_floor = cave_floor[127].y
 chunk_length = chunk_object.length
 chunk_coins = chunk_object.coins
end

function pump_chunk()
 if chunk_progress >= 1 then
  next_chunk()
 end

 local rcl = chunk_length * max(helicopter_velocity.x, 1)
 chunk_distance += 1
 if chunk_distance == rcl then
  chunk_progress = 1
 else
  chunk_progress = chunk_distance / rcl
 end

 local roof = chunk_object.roof(chunk_progress)
 local floor = chunk_object.floor(chunk_progress)
 local coin = nil

 if #chunk_coins > 0 then
  if chunk_coins[1][1] <= chunk_progress then
   coin = chunk_coins[1][2]
   del(chunk_coins, chunk_coins[1])
  end
 end

 return {
  roof = roof,
  floor = floor,
  coin = coin,
 }
end

-->8
-- terrain

terrain = (function()
 local terrain = {}

 setmetatable(terrain, {
  __call = function(_, fn)
   local g = { fn }

   setmetatable(g, {
    __add = function(g1, g2)
     add(g1, g2[1])
     return g1
    end,
  
    __call = function(_, p)
     local o = 0
     for f in all(g) do
      o += f(p)
     end
     return o
    end,
   })
  
   return g

  end
 })

 function terrain:ascend(depth)
  return terrain(
   function(p)
    return p * -depth
   end
  )
 end

 function terrain:curveup(radius)
  return terrain(
   function(p)
    local cx = p * radius
    local c = xy(0, 0)
    local p = xy(p*radius, radius)
    local a = p:angle(c)
    local y = radius * sin(a)
    return y - radius
   end
  )
 end

 function terrain:descend(depth)
  return terrain(
   function(p)
    return p * depth
   end
  )
 end

 function terrain:flat()
  return terrain(
   function(p)
    return 0
   end
  )
 end

 function terrain:fudge(n)
  return terrain(
   function(p)
    if p == 1 then
     return 0
    else
     return n
    end
   end
  )
 end

 function terrain:noise(n)
  return terrain(
   function(p)
    if p == 1 then
     return 0
    else
     return flr(rnd(n)) - n/2
    end
   end
  )
 end

 function terrain:pythagstep(r, d, s)
  return terrain(
   function(p)
    if s == -1 then
     p = 1 - p
    end
    local a = flr(r*p)
    local c = r
    local py = sqrt(c^2 - a^2)
    local y = r - py
    if s == -1 and d == 1 then
     y = py + 0
    elseif s == -1 and d == -1 then
     y = r - r - r + y
    elseif d == -1 then
     y = py - r
    end
    return y
   end
  )
 end

 function terrain:sinewave(magnitude, frequency)
  return terrain(
   function(p)
    return sin(p * frequency) * magnitude
   end
  )
 end

 function terrain:twocircles(r1, r2)
  return terrain(
   function(p)
    if p < 0.5 then
     local p1 = p * 2
     local y = sqrt(r1^2 - (p1 * r1)^2)
     return y - r1
    else
     local p2 = 1 - ((p - 0.5) * 2)
     local y = sqrt(r1^2 - (p2 * r1)^2)
     return 0 - r1 - y
    end
   end
  )
 end

 return terrain
end)()

-->8

function add_cave(ci, new_roof, new_floor)
 cave_roof[ci] = new_roof
 cave_floor[ci] = new_floor

 local from = max(1, ci - 4)
 local to = min(127, ci + 4)

 for i = from, to do
  local roof = cave_roof[i].y or new_roof.y
  local floor = cave_floor[i].y or new_floor.y

  cave_floor_blur_heights[i] = tminmax(max, {
   floor,
   tgad(cave_floor, i - 1, 1, floor + 2),
   tgad(cave_floor, i - 2, 1, floor + 2),
   tgad(cave_floor, i + 1, 1, floor + 2),
   tgad(cave_floor, i + 2, 1, floor + 2),
  }) - floor

  cave_floor_edge_heights[i] = tminmax(max, {
   floor,
   tgad(cave_floor, i - 1, 0, floor),
   tgad(cave_floor, i + 1, 0, floor),
  }) - floor

  cave_roof_blur_heights[i] = roof - tminmax(min, {
   roof,
   tgad(cave_roof, i - 1, -1, roof),
   tgad(cave_roof, i - 2, -1, roof),
   tgad(cave_roof, i + 1, -1, roof),
   tgad(cave_roof, i + 2, -1, roof),
  })

  cave_roof_edge_heights[i] = roof - tminmax(min, {
   roof,
   tgad(cave_roof, i - 1, 0, roof),
   tgad(cave_roof, i + 1, 0, roof),
  })
 end
end

function dbg(message)
  while #debug_messages >= 4 do
    del(debug_messages, debug_messages[1])
  end
  debug_color += 1
  if debug_color > 15 then
    debug_color = 8
  end
  add(debug_messages, { message, debug_color })
end

function speed(n)
 camera_velocity.x = n
 helicopter_velocity.x = n
end

function loop(n, m, o)
 return flr(n % m / flr(m / o))
end

function xy(x, y)
 local p = { x = x or 0, y = y or 0 }
  
 setmetatable(p, {
  __add = function(p1, p2)
   return xy(p1.x + p2.x, p1.y + p2.y)
  end,

  __sub = function(p1, p2)
   return xy(p1.x - p2.x, p1.y - p2.y)
  end,

  __lt = function(p1, p2)
   return p1.x < p2.x and p1.y < p2.y
  end,

  __gt = function(p1, p2)
   return p1.x > p2.x and p1.y > p2.y
  end,
 })

 function p:angle(p2)
  return atan2(p2.x - self.x, -(p2.y - self.y))
 end

 function p:above(p2)
  return self.y < p2.y
 end

 function p:below(p2)
  return self.y > p2.y
 end

 return p
end

function box(position, size)
 local box = {
  position = position,
  size = size,
  x1 = position.x,
  x2 = position.x + size.x,
  y1 = position.y,
  y2 = position.y + size.y,
 }

 function box:move(p)
  self.position = p
  self.x1 = p.x
  self.x2 = p.x + size.x
  self.y1 = p.y
  self.y2 = p.y + size.y
 end

 function box:contains(p)
  return p > self.position and p < self.position + self.size
 end

 return box
end

function tgad(t, g, a, d)
 if t[g] == nil or t[g].y == nil then
  return d
 else
  return t[g].y + a
 end
end

function tminmax(fn, t)
 if #t == 0 then
  return nil
 elseif #t == 1 then
  return t[1]
 else
  local m = t[1]
  for i = 2, #t do
   m = fn(m, t[i])
  end
  return m
 end
end


__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000050000000300000005000000000000000500000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000003330000003bb000333300000000000003333660000000000000000000000000000000000000000000000000000000000000000000000000000000000
0300003335536600033b3b3b35530000000000333553333000000000000000000000000000000000000000000000000000000000000000000000000000000000
03bb3b3b3bb33330055333333bb3660003003b3b3bb3333000000000000000000000000000000000000000000000000000000000000000000000000000000000
033b333333333330000555333333333003bb33333333555000000000000000000000000000000000000000000000000000000000000000000000000000000000
00555555333355500000005555333330033b55553355000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000555500000000000005555500055500005500000000000000000000000000000000000000000000000000000000000000000000000000000000000000
60000000000000006005660000000000600000000000666500000000000000000000000000000000000000000000000000000000000000000000000000000000
06056666666666650600006666600000060000006666000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00600000000000000060000000666665006566660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
06000000000000000605560000000000060000000000666600000000000000000000000000000000000000000000000000000000000000000000000000000000
06055666666666660600006666600000060000006666000000000000000000000000000000000000000000000000000000000000000000000000000000000000
06000000000000000600000000666666060556660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00600000000000000065660000000000006000000000666500000000000000000000000000000000000000000000000000000000000000000000000000000000
06056666666666650600006666600000060000006666000000000000000000000000000000000000000000000000000000000000000000000000000000000000
60000000000000006000000000666665600566660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000006660000000000000000000000665500000000000000000000000000000000000000000000000000000000000000000000000000000000
66666666666666556660006666600000666000006666000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000666655000666660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
60000000000000006005660000000000600000000000666500000000000000000000000000000000000000000000000000000000000000000000000000000000
06056666666666650600006666600000060000006666000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00600000000000000060000000666665006566660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
06000000000000000605560000000000060000000000666600000000000000000000000000000000000000000000000000000000000000000000000000000000
06055666666666660600006666600000060000006666000000000000000000000000000000000000000000000000000000000000000000000000000000000000
06000000000000000600000000666666060556660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00600000000000000065660000000000006000000000666500000000000000000000000000000000000000000000000000000000000000000000000000000000
06056666666666650600006666600000060000006666000000000000000000000000000000000000000000000000000000000000000000000000000000000000
60000000000000006000000000666665600566660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000006660000000000000000000000665500000000000000000000000000000000000000000000000000000000000000000000000000000000
66666666666666556660006666600000666000006666000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000666655000666660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
05055000005055000005055000005050000005000000005000000000000000000000000000000000000000000000000000000000000000000000000000000000
00999900009999000099990000999905009999050099990000999905009999000099990000999900009999000099990000999900009999000099990000999900
09aaaa9009aaaa9009aaaa9009aaaa9009aaaa9509aaaa9509aaaa9009aaaa9509aaaa9009aaaa9009aaaa9009aaaa9009aaaa9009aaaa9009aaaa9009aaaa90
09a99a9009a99a9009a99a9009a99a9009a99a9009a99a9509a99a9509a99a9009a99a9509a99a9009a99a9009a99a9009a99a9009a99a9009a99a9009a99a90
09a9aa9009a9aa9009a9aa9009a9aa9009a9aa9009a9aa9009a9aa9509a9aa9509a9aa9009a9aa9509a9aa9009a9aa9009a9aa9009a9aa9009a9aa9009a9aa90
09aaaa9009aaaa9009aaaa9009aaaa9009aaaa9009aaaa9009aaaa9009aaaa9509aaaa9509aaaa9009aaaa9509aaaa9009aaaa9009aaaa9009aaaa9009aaaa90
00999900009999000099990000999900009999000099990000999900009999000099990500999905009999000099990500999900009999000099990050999900
00000000000000000000000000000000000000000000000000000000000000000000000000000050000005500000550000055050005505000550500005050000
00000000000000000000000000000000000000000500000005500000005500005555555500000000000000000000000000000000000000000000000000000000
00999900009999000099990000999900509999005099990000999900509999005555555500000000000000000000000000000000000000000000000000000000
09aaaa9009aaaa9009aaaa9059aaaa9059aaaa9009aaaa9059aaaa9009aaaa905555555500000000000000000000000000000000000000000000000000000000
09a99a9009a99a9059a99a9059a99a9009a99a9059a99a9009a99a9009a99a905555555500000000000000000000000000000000000000000000000000000000
09a9aa9059a9aa9059a9aa9009a9aa9059a9aa9009a9aa9009a9aa9009a9aa905555555500000000000000000000000000000000000000000000000000000000
59aaaa9059aaaa9009aaaa9059aaaa9009aaaa9009aaaa9009aaaa9009aaaa905555555500000000000000000000000000000000000000000000000000000000
50999900009999005099990000999900009999000099990000999900009999005555555500000000000000000000000000000000000000000000000000000000
00500000050000000000000000000000000000000000000000000000000000005555555500000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00777700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07cccc70000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
7cccccc7000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
7cccccc7000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
7cccccc7000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
7cccccc7000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07cccc70000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00777700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00888800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
08666680000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
86666668000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
86666668000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
86666668000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
86666668000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
08666680000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00888800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000006060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
01200000097500e750097500e75011750117530e7500e75009753117500e75011750157501575311750117500975315750117501575018750187530c7500c75009753117500c7531175015750157501575315100
012000000c750117500c75011750157501575311750117500c75315750117501575018750187531575015750107531875015750187501c7501c75310750107500c75315750107501575019750197532170021100
01200000157551675013752167551a7501a7500000000000157551675013752167551b7501b7501570015750157550e7001a750157521a7551d7501d7501d7500000000000000000000000000000000000000000
01200000157551675013752167551a7501a7500c0000c000157551675013752167551c7501c750157001575015755157551a7551e7552175021750217502d7000000000000000000000000000000000000000000
010a00000c013006050060500605006150060517615176050c013006160061500605006150060517615176050c013006050060500605006150060500605006050c01300616006150060500615006051761517605
010a00002151300600006000060000600006001760017600095330e531095310e53311530115330e5350e5351d513027000e7001a70009700117000e7001a70009533115310e5311153315530155331153511535
01200000091540e150091500e15011150111530e1500e15009153111500e15011150151501515311150111500915315150111501515018150181530c1500c15009153111500c1531115015150151501515315100
01200002007460c746000070000700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004
011000000c0430000000000000000000000000000000000024625000000000000000000000000000000000000c043000000000000000000000000000000000002462500000000000000000000000000000000000
__music__
00 00424344
00 01424344
00 02424344
00 03424344
03 04054344
03 08424344

