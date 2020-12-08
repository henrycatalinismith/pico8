pico-8 cartridge // http://www.pico-8.com
version 29
__lua__
-- nosedive
-- by hen

function _init()
 clock_frame = 0

 debug_messages = {}
 debug_color = 8

 update_mode = 0
 update_camera = 1
 update_cave = 2
 update_helicopter = 4
 update_rotor = 8
 update_exhaust = 16
 update_rotor_fragments = 32
 update_helicopter_fragments = 64

 update_enable(update_camera)
 update_enable(update_cave)
 update_enable(update_rotor)
 update_enable(update_helicopter)
 update_enable(update_exhaust)

 draw_mode = 0
 draw_cave = 1
 draw_helicopter = 2
 draw_rotor = 4
 draw_exhaust = 8
 draw_helicopter_fragments = 16
 draw_rotor_fragments = 32
 draw_hitbox = 64

 draw_enable(draw_cave)
 draw_enable(draw_helicopter)
 draw_enable(draw_exhaust)
 draw_enable(draw_rotor)

 camera_area = box(
  xy(1, 0),
  xy(128, 128)
 )
 camera_velocity = xy(1, 0)

 cave_floor = {}
 cave_roof = {}

 cave_floor_blur_colors = {}
 cave_floor_blur_heights = {}
 cave_floor_edge_colors = {}
 cave_floor_edge_heights = {}

 cave_roof_blur_colors = {}
 cave_roof_blur_heights = {}
 cave_roof_edge_colors = {}
 cave_roof_edge_heights = {}

 for x = 1, 128 do
  add(cave_floor, xy(x, 127))
  add(cave_roof, xy(x, 0))
 end

 cave_floor_blur_colors = fill(128, 1)
 cave_floor_blur_heights = fill(128, 0)
 cave_floor_edge_colors = fill(128, 7)
 cave_floor_edge_heights = fill(128, 0)
 cave_roof_blur_colors = fill(128, 1)
 cave_roof_blur_heights = fill(128, 0)
 cave_roof_edge_colors = fill(128, 7)
 cave_roof_edge_heights = fill(128, 0)

 for x = 1, 128 do
  add_cave(
   x, 
   xy(x, 8 + rnd(2)),
   xy(x, 119 + rnd(2))
  )
 end

 gravity_velocity = xy(0, 0.1)
 helicopter_exhaust = {}
 helicopter_collision_frame = nil
 helicopter_collision_point = nil
 helicopter_fragments = {}
 helicopter_fragments_colors = {0,0,0,0,0,3,4,11}

 for i = 1,8 do
  add(helicopter_exhaust, {
   color = 6,
   frame = clock_frame,
   position = xy(0, 0),
   radius = 1,
   velocity = xy(0, 0)
  })
 end

 for i = 1,128 do
  add(helicopter_fragments, {
   color = helicopter_fragments_colors[1],
   position = xy(0, 0),
   velocity = xy(0, 0)
  })
 end

 helicopter_inclination = "hovering"
 helicopter_ascent_max = -1.5
 helicopter_descent_max = 2
 helicopter_position = xy(48, 80)
 helicopter_velocity = camera_velocity
 helicopter_hitbox_offset = xy(-4, -4)
 helicopter_hitbox = box(
  helicopter_position + helicopter_hitbox_offset,
  xy(8, 8)
 )
 rotor_collision_frame = nil
 rotor_collision_point = nil
 rotor_engaged = false
 rotor_fragments = {}
 rotor_fragments_colors = {0,0,0,0,0,0,0,0,0,5,6,6,7,11}

 for i = 1,128 do
  add(rotor_fragments, {
   color = rotor_fragments_colors[1],
   position = xy(0, 0),
   velocity = xy(0, 0)
  })
 end

 rotor_velocity = xy(0, 0)
end

function _update60()
 clock_frame += 1

 if (update_mode & update_camera) != 0 then
  camera_area:move(camera_area.position + camera_velocity)
 end

 if (update_mode & update_cave) != 0 then
  for i = 1, camera_velocity.x do
   for j = 1, 127 do
    cave_roof[j].x = cave_roof[j+1].x
    cave_roof[j].y = cave_roof[j+1].y
    cave_floor[j].x = cave_floor[j+1].x
    cave_floor[j].y = cave_floor[j+1].y

    cave_roof_blur_heights[j] = cave_roof_blur_heights[j+1]
    cave_roof_edge_heights[j] = cave_roof_edge_heights[j+1]
    cave_floor_blur_heights[j] = cave_floor_blur_heights[j+1]
    cave_floor_edge_heights[j] = cave_floor_edge_heights[j+1]
   end

   add_cave(
    128,
    xy(
     cave_roof[127].x + 1,
     8 + rnd(2)
    ),
    xy(
     cave_floor[127].x + 1,
     119 + rnd(2)
    )
   )
  end
 end

 if (update_mode & update_rotor) != 0 then
  rotor_engaged = btn(5)
  if rotor_engaged then
   rotor_velocity.y = -0.3
  else
   rotor_velocity.y = 0
  end
 end

 for i = 1, 128 do
  if helicopter_collision_frame then
   cave_roof_edge_colors[i] = 1
   cave_floor_edge_colors[i] = 1
  elseif helicopter_position.x - camera_area.x1 > i then
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


 if (update_mode & update_helicopter) != 0 then
  helicopter_velocity += rotor_velocity + gravity_velocity
  helicopter_velocity.y = mid(
   helicopter_ascent_max,
   helicopter_velocity.y,
   helicopter_descent_max
  )
  helicopter_position += helicopter_velocity

  helicopter_hitbox:move(helicopter_position + helicopter_hitbox_offset)

  if rotor_collision_frame then
   helicopter_inclination = "dropping"
  elseif helicopter_velocity.y > 0 and not rotor_engaged then
   helicopter_inclination = "dropping"
  elseif helicopter_velocity.y < 0 and rotor_engaged then
   helicopter_inclination = "climbing"
  else
   helicopter_inclination = "hovering"
  end

  for i = helicopter_hitbox.x1, helicopter_hitbox.x2 do
   local x = i - camera_area.x1
   local roof = cave_roof[x]
   local floor = cave_floor[x]

   if helicopter_hitbox:contains(roof) then
    update_disable(update_rotor)
    update_enable(update_rotor_fragments)
    draw_disable(draw_rotor)
    draw_enable(draw_rotor_fragments)
    rotor_engaged = false
    rotor_velocity.y = 0
    rotor_collision_frame = clock_frame
    rotor_collision_point = roof:copy()
    helicopter_velocity.y = 2
    helicopter_descent_max = 4
    for fragment in all(rotor_fragments) do
     fragment.color = choose(rotor_fragments_colors)
     fragment.position = helicopter_position + xy(0, 4)
     fragment.velocity = xy(
      0 - helicopter_velocity.x*2 + rnd(helicopter_velocity.x*8),
      0 - helicopter_velocity.y + rnd(helicopter_velocity.y * 2)
     )
    end
   end

   if helicopter_hitbox:contains(floor) then
    update_disable(update_camera)
    update_disable(update_cave)
    update_disable(update_helicopter)
    update_enable(update_helicopter_fragments)
    draw_disable(draw_exhaust)
    draw_disable(draw_helicopter)
    draw_enable(draw_helicopter_fragments)
    helicopter_collision_frame = clock_frame
    helicopter_collision_point = floor:copy()
    for fragment in all(helicopter_fragments) do
     fragment.color = choose(helicopter_fragments_colors)
     fragment.position = helicopter_position
     fragment.velocity = helicopter_velocity + xy(
      -1 + rnd(2),
      -4 + rnd(3)
     )
    end
    helicopter_velocity:zero()
    camera_velocity:zero()
   end
  end
 end

 if (update_mode & update_exhaust) != 0 then
  for puff in all(helicopter_exhaust) do
   puff.position.x += puff.velocity.x / 16
   puff.position.y += puff.velocity.y / 8
   if (clock_frame - puff.frame) % 16 == 0 then
    puff.radius -= 1
   end
  end

  if clock_frame % 4 == 0 then
   for i,puff in pairs(helicopter_exhaust) do
    if i == #helicopter_exhaust then
     puff.position = helicopter_position - xy(8, 0)
     puff.frame = clock_frame
     puff.velocity = helicopter_velocity
     if rotor_engaged then
      puff.radius = 1
     else
      puff.radius = 0
     end
    else
     puff.frame = helicopter_exhaust[i+1].frame
     puff.position = helicopter_exhaust[i+1].position
     puff.radius = helicopter_exhaust[i+1].radius
     puff.velocity = helicopter_exhaust[i+1].velocity
    end
   end
  end
 end

 if (update_mode & update_rotor_fragments) != 0 then
  for f in all(rotor_fragments) do
   if not f.stopped then
    f.velocity += gravity_velocity
    f.velocity.y = mid(-4, f.velocity.y, 2)
    f.position += f.velocity
   end
   local i = flr(f.position.x) - camera_area.x1
   if i > 128 or i < 1 then
    goto skipr
   end
   local roof = cave_roof[i]
   local floor = cave_floor[i]
   if f.position.y <= roof.y then
    f.stopped = true
   end
   if f.position.y >= floor.y then
    f.stopped = true
   end
   ::skipr::
  end
 end

 if (update_mode & update_helicopter_fragments) != 0 then
  for f in all(helicopter_fragments) do
   if not f.stopped then
    f.velocity.y += 0.5
    f.velocity.y = mid(-4, f.velocity.y, 1)
    f.position += f.velocity
   end
   local i = flr(f.position.x) - camera_area.x1
   if i > 128 or i < 1 then
    goto skiph
   end
   local roof = cave_roof[i]
   local floor = cave_floor[i]
   if f.position.y <= roof.y then
    f.stopped = true
   end
   if f.position.y >= floor.y then
    f.stopped = true
   end
   ::skiph::
  end
 end
end

function _draw()
 camera(camera_area.x1, camera_area.y1)

 cls(8)

 if (draw_mode & draw_cave) != 0 then
  for i = 1, 128 do
   local x = i + camera_area.x1 - 1
   local roof = cave_roof[i]
   local floor = cave_floor[i]
   line(
    roof.x,
    roof.y,
    floor.x,
    floor.y,
    0
   )

   line(
    roof.x,
    roof.y,
    roof.x,
    camera_area.y1,
    5
   )

   line(
    roof.x,
    roof.y,
    roof.x,
    roof.y - cave_roof_blur_heights[i],
    cave_roof_blur_colors[i]
   )

   line(
    roof.x,
    roof.y,
    roof.x,
    roof.y - cave_roof_edge_heights[i],
    cave_roof_edge_colors[i]
   )

   line(
    floor.x,
    floor.y,
    floor.x,
    camera_area.y2,
    5
   )

   line(
    floor.x,
    floor.y,
    floor.x,
    floor.y + cave_floor_blur_heights[i],
    cave_floor_blur_colors[i]
   )

   line(
    floor.x,
    floor.y,
    floor.x,
    floor.y + cave_floor_edge_heights[i],
    cave_floor_edge_colors[i]
   )
  end
 end

 if (draw_mode & draw_exhaust) != 0 then
  for puff in all(helicopter_exhaust) do
   circ(
    puff.position.x,
    puff.position.y,
    puff.radius,
    puff.color
   )
  end
 end

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

 if (draw_mode & draw_helicopter) != 0 then
  sspr(
   helicopter_sprite_x,
   0,
   16,
   8,
   helicopter_position.x - 8,
   helicopter_position.y - 4
  )
 end

 if (draw_mode & draw_rotor) != 0 then
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

 if (draw_mode & draw_hitbox) != 0 then
  rect(
   helicopter_hitbox.x1,
   helicopter_hitbox.y1,
   helicopter_hitbox.x2,
   helicopter_hitbox.y2,
   11
  )
 end

 if (draw_mode & draw_rotor_fragments) != 0 then
  for f in all(rotor_fragments) do
   pset(
    f.position.x,
    f.position.y,
    f.color
   )
  end
 end

 if (draw_mode & draw_helicopter_fragments) != 0 then
  for f in all(helicopter_fragments) do
   pset(
    f.position.x,
    f.position.y,
    f.color
   )
  end
 end

 camera(0, 0)
 for i,debug_message in pairs(debug_messages) do
   print(debug_message[1], 0, (i-1)*8, debug_message[2])
 end
 bar("cpu", stat(1), 1, 123)
end

function add_cave(i, roof, floor)
 cave_roof[i] = roof
 cave_floor[i] = floor

 for j = max(1, i - 4), min(127, i + 4) do
  local r = cave_roof[j].y
  local f = cave_floor[j].y

  cave_floor_blur_heights[j] = tminmax(max, {
   f,
   tgad(cave_floor, j - 1, 1, f + 2),
   tgad(cave_floor, j - 2, 1, f + 2),
   tgad(cave_floor, j + 1, 1, f + 2),
   tgad(cave_floor, j + 2, 1, f + 2),
  }) - f

  cave_floor_edge_heights[j] = tminmax(max, {
   f,
   tgad(cave_floor, j - 1, 0, f),
   tgad(cave_floor, j + 1, 0, f),
  }) - f

  cave_roof_blur_heights[j] = r - tminmax(min, {
   r,
   tgad(cave_roof, j - 1, -1, r),
   tgad(cave_roof, j - 2, -1, r),
   tgad(cave_roof, j + 1, -1, r),
   tgad(cave_roof, j + 2, -1, r),
  })

  cave_roof_edge_heights[j] = r - tminmax(min, {
   r,
   tgad(cave_roof, j - 1, 0, r),
   tgad(cave_roof, j + 1, 0, r),
  })
 end
end

function flrrnd(n)
 return flr(rnd(n))
end

function choose(table)
 return table[flrrnd(#table) + 1]
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

 function p:copy()
  return xy(self.x, self.y)
 end

 function p:zero()
  self.x = 0
  self.y = 0
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

function bar(l, p, x, y)
 line(x+1, y+1, x+14, y+1, 5)
 line(x+1, y+1, x+14*min(1,p), y+1, 7)
 rect(x, y, x+15, y+2, 1)
 print(l, x+17, y-1, 7)
end

function update_enable(flag)
 update_mode |= flag
end

function update_disable(flag)
 update_mode &= ~flag
end

function draw_enable(flag)
 draw_mode |= flag
end

function draw_disable(flag)
 draw_mode &= ~flag
end

function fill(n, v)
 local tbl = {}
 for i = 1,n do
  add(tbl, v)
 end
 return tbl
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

