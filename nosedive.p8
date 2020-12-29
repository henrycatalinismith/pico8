pico-8 cartridge // http://www.pico-8.com
version 29
__lua__
-- nosedive
-- by hen

function _init()
 poke(0x5f80, 1)

 update_mode = 0
 update_camera = 1
 update_cave = 2
 update_helicopter = 4
 update_rotor = 8
 update_hitbox = 16
 update_debris = 32
 update_coins = 64
 update_smoke = 128

 update_enable(update_camera)
 update_enable(update_cave)
 update_enable(update_helicopter)
 update_enable(update_rotor)
 update_enable(update_hitbox)
 update_enable(update_coins)
 update_enable(update_debris)
 update_enable(update_smoke)

 draw_mode = 0
 draw_cave = 1
 draw_helicopter = 2
 draw_rotor = 4
 draw_hitbox = 8
 draw_debris = 16
 draw_coins = 32
 draw_debug = 64
 draw_smoke = 128

 draw_enable(draw_cave)
 draw_enable(draw_helicopter)
 draw_enable(draw_rotor)
 --draw_enable(draw_hitbox)
 draw_enable(draw_coins)
 draw_enable(draw_debris)
 draw_enable(draw_debug)
 draw_enable(draw_smoke)

 clock_frame = 0

 camera_x1 = 1
 camera_y1 = 0
 camera_x2 = camera_x1 + 128
 camera_y2 = camera_y1 + 128
 camera_vx = 2
 camera_vy = 0
 camera_ideal_y1 = camera_y1
 camera_error_y1 = 0
 camera_offset_y1 = 0
 camera_error_count = -1

 cave_x1 = 1
 cave_x2 = cave_x1 + 128

 chunk_fn = tunnel(0, 88) + resize1(32)
 chunk_p = 0
 chunk_length = 128*camera_vx
 chunk_x1 = cave_x1
 chunk_x2 = chunk_x1 + chunk_length

 cave_floor = fill(chunk_length, 118)
 cave_floor_blur_colors = fill(chunk_length, 1)
 cave_floor_blur_heights = fill(chunk_length, 0)
 cave_floor_edge_colors = fill(chunk_length, 7)
 cave_floor_edge_heights = fill(chunk_length, 0)
 cave_roof = fill(chunk_length, 8)
 cave_roof_blur_colors = fill(chunk_length, 1)
 cave_roof_blur_heights = fill(chunk_length, 0)
 cave_roof_edge_colors = fill(chunk_length, 7)
 cave_roof_edge_heights = fill(chunk_length, 0)
 coin_height = 64

 cave_y1 = cave_roof[chunk_length]
 cave_y2 = cave_floor[chunk_length]

 for x = 1,chunk_length do
  local slice = chunk_fn(x/chunk_length)
  add_cave(x, slice[1], slice[2])
 end

 chunk_y1 = cave_roof[#cave_roof]

 coins = {}
 coins_count = 0

 debug_messages = {}
 debug_color = 8

 helicopter_x = 48
 helicopter_y = 80
 helicopter_vx = camera_vx
 helicopter_vy = 0
 helicopter_inclination = "hovering"
 helicopter_gravity = 0.1
 helicopter_min_vy = -1.5
 helicopter_max_vy = 2

 hitbox_x1 = helicopter_x - 4
 hitbox_y1 = helicopter_y - 4
 hitbox_x2 = hitbox_x1 + 8
 hitbox_y2 = hitbox_y1 + 6

 rotor_engaged = false
 rotor_vy = 0
 rotor_power = -0.3

 debris = {}

 rotor_collision_frame = nil
 helicopter_collision_frame = nil

 smoke = {}
end

function _update60()
 clock_frame += 1


 if update(update_camera) then

  if rotor_collision_frame and helicopter_y-64>camera_y1 then
   camera_ideal_y1 = helicopter_y-64
  else
   camera_ideal_y1 = avg({
    cave_roof[32] + 1,
    cave_floor[32],
    cave_roof[96] + 1,
    cave_floor[96],
   }) - 64
  end

  camera_offset_y1 = camera_y1 - camera_ideal_y1
  camera_error_y1 = abs(camera_offset_y1)

  if camera_error_y1 < 1 then
   camera_error_count = 0
  else
   camera_error_count += 1
  end

  camera_vy = flr(
   camera_offset_y1
   * (camera_error_count / 256)
   * -1
  )

  camera_x1 += camera_vx
  camera_y1 += camera_vy
  camera_x2 = camera_x1 + 128
  camera_y2 = camera_y1 + 128
 end

 if update(update_cave) then
  for i = 1,camera_vx do
   for j = 1, chunk_length-1 do
    cave_floor[j] = cave_floor[j+1]
    cave_roof[j] = cave_roof[j+1]

    cave_floor_blur_heights[j] = cave_floor_blur_heights[j+1]
    cave_floor_edge_heights[j] = cave_floor_edge_heights[j+1]
    cave_roof_blur_heights[j] = cave_roof_blur_heights[j+1]
    cave_roof_edge_heights[j] = cave_roof_edge_heights[j+1]
   end

   cave_x1 += 1
   cave_x2 = cave_x1 + 128

   if cave_x2 < chunk_x2 then
    chunk_p = (cave_x2 - chunk_x1) / chunk_length
   elseif cave_x2 == chunk_x2 then
    chunk_p = 1
    dbg("last" .. cave_x2)
   else
    dbg("nxtchunk " .. chunk_x2 .. ":" .. cave_x2)

    chunk_p = 0
    chunk_x1 = cave_x2
    chunk_x2 = chunk_x1 + chunk_length
    chunk_y1 = cave_roof[#cave_roof]

    local r = flrrnd(8)
    r = 0
    if r == 0 then
     chunk_fn = tunnel(0, 64) + sinechunk(16, 2) + resize1(128)
    elseif r == 1 then
     chunk_fn = tunnel(0, 96) + zig(32) + resize1(32-rnd(64))
    elseif r == 2 then
     chunk_fn = tunnel(0, 96) + zag(32) + resize1(32-rnd(64))
    elseif r == 3 then
     chunk_fn = tunnel(0, 96) + zigzag(32) + resize1(32-rnd(64))
    elseif r == 4 then
     chunk_fn = tunnel(0, 72) + nbend(16+rnd(2), 32+rnd(2)) + resize1(32-rnd(64))
    elseif r == 5 then
     chunk_fn = tunnel(0, 72) + ubend(16+rnd(2), 32+rnd(2)) + resize1(32-rnd(64))
    elseif r == 6 then
     chunk_fn = tunnel(0, 72) + sbend(16+rnd(2), 32+rnd(2)) + resize1(32-rnd(64))
    elseif r == 7 then
     chunk_fn = tunnel(0, 72) + zbend(16+rnd(2), 32+rnd(2)) + resize1(32-rnd(64))
    end

    dbg(chunk_y1)
   end

   next_slice = chunk_fn(chunk_p)

   add_cave(
    chunk_length,
    chunk_y1 + next_slice[1],
    chunk_y1 + next_slice[2]
   )
   cave_y1 = cave_roof[#cave_roof]
   cave_y2 = cave_floor[#cave_floor]
   cave_height = cave_y2 - cave_y1
   coin_height = cave_roof[128] + ((
    cave_floor[128] - cave_roof[128]
   ) / 2) - 4
  end
 end

 if update(update_rotor) then
  rotor_engaged = btn(5)
  if rotor_engaged then
   rotor_vy = rotor_power
  else
   rotor_vy = 0
  end
 end

 if update(update_helicopter) then
  helicopter_vy += helicopter_gravity
  helicopter_vy += rotor_vy
  helicopter_vy = mid(
   helicopter_min_vy,
   helicopter_vy,
   helicopter_max_vy
  )
  helicopter_x += helicopter_vx
  helicopter_y += helicopter_vy

  if helicopter_vy > 0 and not rotor_engaged then
   helicopter_inclination = "dropping"
  elseif helicopter_vy < 0 and rotor_engaged then
   helicopter_inclination = "climbing"
  else
   helicopter_inclination = "hovering"
  end

  bright = 7
  dim = 1
  for i = 1, 128 do
   cave_roof_edge_colors[i] = dim
   cave_floor_edge_colors[i] = dim
   if helicopter_x - camera_x1 < i then
    if helicopter_y - cave_roof[i] - i/2 < 2 then
     cave_roof_edge_colors[i] = bright
    end
    if cave_floor[i] - helicopter_y - i/2 < 8 then
     cave_floor_edge_colors[i] = bright
    end
   end
  end

 end

 if update(update_hitbox) then
  hitbox_x1 = helicopter_x - 4
  hitbox_y1 = helicopter_y - 4
  hitbox_x2 = hitbox_x1 + 8
  hitbox_y2 = hitbox_y1 + 6

  for x = hitbox_x1,hitbox_x2 do
   local i = x-camera_x1
   local roof = cave_roof[i]
   local floor = cave_floor[i]
   for y = hitbox_y1,hitbox_y2 do
    local i = flr(x) - camera_x1
    if y < cave_roof[i] then
     rotor_collision()
     goto boom
    end
    if y > cave_floor[i] then
     helicopter_collision()
     goto boom
    end
   end

   for coin in all(coins) do
    if coin.hit == nil
     and (coin.x1 < x and coin.x2 > x)
     and not (coin.y2 < hitbox_y1 or coin.y1 > hitbox_y2)
     then
     coin.hit = clock_frame
     coins_count += 1

     for i = 1,8 do
      add(debris, {
       color = choose({9,10}),
       x = coin.x1,
       y = coin.y1+2,
       vx = -1+rnd(2),
       vy = helicopter_vy + rnd(8),
      })
     end

     if coins_count % 4 == 0 and helicopter_vx < 4 then
      --camera_vx += 1
      --helicopter_vx += 1
     end

     goto boom
    end
   end

  end
  ::boom::
 end

 if update(update_debris) then
  for d in all(debris) do
   if d.x <= camera_x1 or d.x >= camera_x2 then
    del(debris, d)
    goto continue_debris
   end
   if d.vx == 0 and d.vy == 0 then goto continue_debris end

   d.vy += 0.1
   d.vy = mid(-4, d.vy, 4)

   if is_space(d.x + d.vx, d.y) then
    d.x += d.vx
   else
    d.vx *= rnd(0.3) * -1 * d.vx
    d.vy = 0
   end

   local i = flr(d.x) - camera_x1
   if i > 128 or i < 1 then
    -- ignore out of screen debris
   elseif d.y + flr(d.vy) < cave_roof[i] then
    -- debris hits roof
    d.vy *= rnd(0.5) * - 1
    d.vx = rnd(0.2)
   elseif d.y + flr(d.vy) > cave_floor[i] then
    -- debris hits floor
    d.vy *= rnd(0.3) * - 1
    d.vx = rnd(0.2)
   else
    -- debris can move
    d.y += d.vy
   end

   ::continue_debris::
  end
 end

 if update(update_coins) then
  for coin in all(coins) do
   if coin.x2 < camera_x1
    or coin.hit and clock_frame - coin.hit > 16 then
    del(coins, coin)
   end
  end
  if #coins == 0 or coins[#coins].x2 < camera_x2 - 8 then
   local x1 = cave_x1 + 8
   local y1 = coin_height
   if coins[#coins] then
    x1 = coins[#coins].x1 + 16
   end
   local x2 = x1+9
   local y2 = y1+9
   add(coins, {
     x1 = x1,
     y1 = y1,
     x2 = x2,
     y2 = y2,
   })
   x1 += 64
  end
 end

 if update(update_smoke) then
  if helicopter_collision_frame == nil and clock_frame % 4 == 0 then
   local radius = 0
   if rotor_collision_frame then
    radius = 2
   elseif rotor_engaged then
    radius = 1
   end
   add(smoke, {
    x = helicopter_x - 8,
    y = helicopter_y,
    vx = helicopter_vx,
    vy = helicopter_vy,
    radius = radius,
    age = 0,
   })
  end

  for i, puff in pairs(smoke) do
   puff.x += puff.vx / 16
   puff.y += puff.vy / 8
   puff.age += 1
   if puff.age % 20 == 0 then
    puff.radius -= 1
   end
   if puff.radius < 0 then
    del(smoke, puff)
   end
  end

 end
end

function _draw()
 camera(camera_x1, camera_y1)

 cls(0)

 if draw(draw_coins) then
  for coin in all(coins) do
   local x = coin.x1+1
   local y = coin.y1
   y += loop(clock_frame + coin.x1, 48, 2)
   if coin.hit then
    spr(88 + clock_frame - coin.hit, x, y)
   else
    spr(64 + loop(clock_frame, 24, 24), x, y)
   end
  end
 end

 if draw(draw_cave) then
  for i = 1,128 do
   local x = camera_x1 + i
   local roof = cave_roof[i]
   local floor = cave_floor[i]
   line(x, camera_y1, x, roof, 5)
   line(x, roof, x, roof - cave_roof_blur_heights[i], cave_roof_blur_colors[i])
   line(x, roof, x, roof - cave_roof_edge_heights[i], cave_roof_edge_colors[i])
   line(x, floor, x, camera_y2, 5)
   line(x, floor, x, floor + cave_floor_blur_heights[i], cave_floor_blur_colors[i])
   line(x, floor, x, floor + cave_floor_edge_heights[i], cave_floor_edge_colors[i])
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

 if draw(draw_helicopter) then
  sspr(
   helicopter_sprite_x,
   0,
   16,
   8,
   helicopter_x - 8,
   helicopter_y - 4
  )
 end

 if draw(draw_rotor) then
  sspr(
   helicopter_sprite_x + 3,
   8 + loop(clock_frame, 32, 8) * 3,
   13,
   3,
   helicopter_x - 5,
   helicopter_y - 5
  )
  sspr(
   helicopter_sprite_x,
   8 + loop(clock_frame, 8, 8) * 3,
   3, 3,
   helicopter_x - 8,
   helicopter_y + tail_y_offset - 4
  )
 end

 if draw(draw_hitbox) then
  rect(
   hitbox_x1,
   hitbox_y1,
   hitbox_x2,
   hitbox_y2,
   11
  )

  for x = hitbox_x1,hitbox_x2 do
   local i = x-camera_x1
   pset(x, cave_floor[i], 11)
   pset(x, cave_roof[i], 11)
  end

  for coin in all(coins) do
   rect(
    coin.x1,
    coin.y1,
    coin.x2,
    coin.y2,
    11
   )
  end
 end

 if draw(draw_debris) then
  for f in all(debris) do
   pset(
    f.x,
    f.y,
    f.color
   )
  end
 end

 if draw(draw_smoke) then
  for i, puff in pairs(smoke) do
   circ(puff.x, puff.y, r, 5)
  end
 end

 camera(0, 0)
 if draw(draw_debug) then
  for i,debug_message in pairs(debug_messages) do
   print(debug_message[1], 0, ((i-1)*8)+96, debug_message[2])
  end
  draw_bar("cpu", stat(1), 1, 123)
  print(cave_y1, 32, 1, 7)
 end
end

function add_cave(ci, new_roof, new_floor)
 cave_roof[ci] = new_roof
 cave_floor[ci] = new_floor

 local from = max(1, ci - 4)
 local to = min(chunk_length-1, ci + 4)

 for i = from, to do
  local roof = cave_roof[i]
  local floor = cave_floor[i]

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

function tgad(t, g, a, d)
 if t[g] == nil or t[g] == nil then
  return d
 else
  return t[g] + a
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




function nearest(t, n)
 local v = 1
 for i = 2,#t do
  if abs(t[i] - n) < abs(t[v] - n) then
   v = i
  end
 end
 return v
end

function is_space(x, y)
 local i = flr(x) - camera_x1
 if i > 128 or i < 1 then
  return true
 end
 if y < cave_roof[i] then
  return false
 end
 if y > cave_floor[i] then
  return false
 end
 return true
end

function rotor_collision()
  dbg("rotor collision")
  rotor_collision_frame = clock_frame

  for i = 1,32 do
   add(debris, {
    color = choose({0,0,0,0,0,0,0,0,0,5,6,6,7,11}),
    x = helicopter_x,
    y = helicopter_y + 4,
    vx = helicopter_vx*-1 + rnd(helicopter_vx*4),
    vy = 0 - rnd(2),
   })
  end

  rotor_engaged = false
  rotor_vy = 0
  helicopter_vy = 2
  helicopter_max_vy = 4
  update_disable(update_rotor)
  update_enable(update_debris)
  draw_disable(draw_rotor)
  draw_disable(draw_hitbox)
  draw_enable(draw_debris)
end

function helicopter_collision()
 dbg("helicopter collision")
 helicopter_collision_frame = clock_frame

 for i = 1,128 do
  add(debris, {
   color = choose({3,4,11}),
   x = helicopter_x,
   y = helicopter_y,
   vx = helicopter_vx + (-1+rnd(2)),
   vy = 0 - rnd(2),
  })
 end

 rotor_engaged = false
 rotor_vy = 0
 helicopter_vy = 0
 helicopter_vx = 0
 update_disable(update_camera)
 update_disable(update_cave)
 update_disable(update_helicopter)
 update_disable(update_hitbox)
 update_enable(update_debris)
 draw_disable(draw_rotor)
 draw_disable(draw_hitbox)
 draw_disable(draw_helicopter)
 draw_enable(draw_debris)
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

function update(flag)
 return (update_mode & flag) != 0
end

function update_enable(flag)
 update_mode |= flag
end

function update_disable(flag)
 update_mode &= ~flag
end

function draw(flag)
 return (draw_mode & flag) != 0
end

function draw_enable(flag)
 draw_mode |= flag
end

function draw_disable(flag)
 draw_mode &= ~flag
end

function loop(n, m, o)
 return flr(n % m / flr(m / o))
end

function avg(l)
 local t = 0
 for i in all(l) do
  t += i
 end
 return t / #l
end

function fill(n, v)
 local tbl = {}
 for i = 1,n do
  add(tbl, v)
 end
 return tbl
end

function flrrnd(n)
 return flr(rnd(n))
end

function last(t)
 return t[#t]
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

function tunnel(d, h)
 return chunk(
  static(d) + noise(1),
  static(d + h) + noise(1)
 )
end

function zig(y)
 return chunk(
  linear(-y) % range(0, 0.5) + linear(y) % range(0.5, 1),
  linear(-y) % range(0, 0.5) + linear(y) % range(0.5, 1)
 )
end

function zag(y)
 return chunk(
  linear(y) % range(0, 0.5) + linear(-y) % range(0.5, 1),
  linear(y) % range(0, 0.5) + linear(-y) % range(0.5, 1)
 )
end

function zigzag(y)
 return chunk(
  linear(y) % range(0, 0.25)
  + linear(-y) % range(0.25, 0.5)
  + linear(y) % range(0.5, 0.75)
  + linear(-y) % range(0.75, 1),
  linear(y) % range(0, 0.25)
  + linear(-y) % range(0.25, 0.5)
  + linear(y) % range(0.5, 0.75)
  + linear(-y) % range(0.75, 1)
 )
end

function room(d)
 return chunk(
  static(d),
  static(d + 112)
 )
end

function corridor(d, h)
 return chunk(
  static(d),
  static(d + h)
 )
end

function resize1(y)
 return chunk(
  linear(y),
  linear(y)
 )
end

function resize(y1, y2)
 return chunk(
  linear(y1),
  linear(y2)
 )
end

function nbend(r1, r2)
 return chunk(
  nshape(r2, r1),
  nshape(r1, r2)
 )
end

function sbend(r1, r2)
 return chunk(
  sshape(r1, r2),
  sshape(r2, r1)
 )
end

function ubend(r1, r2)
 return chunk(
  ushape(r2, r1),
  ushape(r1, r2)
 )
end

function zbend(r1, r2)
 return chunk(
  zshape(r2, r1),
  zshape(r1, r2)
 )
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

function invert()
 return terrain(
  function(p)
   return -1
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

function pythagoras(r)
 return terrain(
  function(p)
   return r - sqrt(r^2 - flr(r*p)^2)
  end
 )
end

function range(from, to)
 return terrain(
  function(p)
   if p <= from then
    return 0
   elseif p >= to then
    return 1
   else
    return (p-from)/(to-from)
   end
  end
 )
end

function reverse()
 return terrain(
  function(p)
   return 1 - p
  end
 )
end

function fragment(x, y, r, d)
 return (
  static(y)
  + (linear(r*d) + sinewave(2, 1) + noise(1)) % range(0, 0.5)
  + (linear(r*-d) + sinewave(2, 1) + noise(1)) % range(0.5, 1)
 ) % trim() % range(x-(r*0.01), x+(r*0.01))
end

function nshape(r1, r2)
 return (
  sshape(r2, r1) % range(0, 0.5)
  + zshape(r1, r2) % range(0.5, 1)
 )
end

function sshape(r1, r2)
 return zshape(r1, r2) * static(-1)
end

function ushape(r1, r2)
 return (
  zshape(r1, r2) % range(0, 0.5)
  + sshape(r2, r1) % range(0.5, 1)
 )
end

function zshape(r1, r2)
 local p1 = r1 / (r1 + r2)
 return (
  static(r2) + pythagoras(r1) % range(0, p1)
  + pythagoras(r2) * invert() % reverse() % range(p1, 1)
 )
end

function sinechunk(m, f)
 return chunk(
  sinewave(m,f),
  sinewave(m,f)
 )
end

function sinewave(magnitude, frequency)
 return terrain(
  function(p)
   return sin(p * frequency) * magnitude
  end
 )
end

function static(y)
 return terrain(
  function(p)
   return y
  end
 )
end

function trim()
 return terrain(
  function(p)
   if p > 0 and p < 1 then
    return p
   end
  end
 )
end

function sort(a)
 for i=1,#a do
  local j = i
  while j > 1 and a[j-1] > a[j] do
   a[j],a[j-1] = a[j-1],a[j]
   j = j - 1
  end
 end
end

function choose(table)
 return table[flrrnd(#table) + 1]
end

function draw_bar(l, p, x, y)
 line(x+1, y+1, x+14, y+1, 5)
 line(x+1, y+1, x+14*p, y+1, 7)
 rect(x, y, x+15, y+2, 1)
 print(l, x+17, y-1, 7)
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
00000000000000000000000000000000000000000500000005500000005500000000000000000000000000000000000000000000000000000000000000000000
00999900009999000099990000999900509999005099990000999900509999000099990000999900009999000099990000999900009999000099990000999900
09aaaa9009aaaa9009aaaa9059aaaa9059aaaa9009aaaa9059aaaa9009aaaa9009aaaa9009aaaa9009aaaa9009aaaa9009aaaa9009aaaa9009aaaa9009aaaa90
09a99a9009a99a9059a99a9059a99a9009a99a9059a99a9009a99a9009a99a9009a99a9009a99a9009aa9a9009a9aa9009a99a9009a09a9009a00a9009a00a90
09a9aa9059a9aa9059a9aa9009a9aa9059a9aa9009a9aa9009a9aa9009a9aa9009a9aa9009aa9a9009a99a9009a99a9009a0aa9009a0aa9009a0aa9009a00a90
59aaaa9059aaaa9009aaaa9059aaaa9009aaaa9009aaaa9009aaaa9009aaaa9009aaaa9009aaaa9009aaaa9009aaaa9009aaaa9009aaaa9009aaaa9009aaaa90
50999900009999005099990000999900009999000099990000999900009999000099990000999900009999000099990000999900009999000099990000999900
00500000050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000aaaa0000aaaa00000aa000000aa0000000a00000000a000000000000000000000000000000000000000000000000000000000000000000
00999900009999000a9999a00a0000a00a0000a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
090aa09009000090a900009aa000000a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
09a00a9009000090a900009aa000000aa000000aa000000aa0000000000000000000000000000000000000000000000000000000000000000000000000000000
09a00a9009000090a900009aa000000aa000000aa000000a0000000a000000000000000000000000000000000000000000000000000000000000000000000000
090aa09009000090a900009aa000000a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00999900009999000a9999a00a0000a00a0000a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000aaaa0000aaaa00000aa000000aa000000a0000000000000000000000000000000000000000000000000000000000000000000000000000
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

