pico-8 cartridge // http://www.pico-8.com
version 29
__lua__

function _init()
  init_camera()
  init_cave()
  init_clock()
  init_gravity()
  init_helicopter()
  init_hitbox()
  init_collision()
  init_rotor()
  init_smoke()
end

function _update60()
  update_clock()
  update_camera()
  update_cave()
  update_rotor()
  update_helicopter()
  update_hitbox()
  update_collision()
  update_smoke()
end

function _draw()
  camera(camera_position.x, camera_position.y)
  draw_cave()
  draw_smoke()
  draw_helicopter()
  draw_hitbox()
  draw_overlay()
end

function init_camera()
  camera_position = xy(0, 0)
  camera_velocity = xy(1, 0)
end

function init_cave()
  cave_position = xy(0, 0)
  cave_velocity = xy(1, 0)
  cave_floor = {}
  cave_roof = {}

  for x = 0, 127 do
    add(cave_roof, xy(x, cave_position.y + 8 + rnd(2)))
    add(cave_floor, xy(x, cave_position.y + 119 + rnd(2)))
  end
end

function init_clock()
  clock_frame = 0
end

function init_collision()
  collision_point = nil
end

function init_gravity()
  gravity_velocity = xy(0, 0.1)
end

function init_helicopter()
  helicopter_inclination = "hovering"
  helicopter_position = xy(48, 32)
  helicopter_velocity = xy(1, 0)
end

function init_hitbox()
  hitbox_offset = xy(-4, -4)
  hitbox_box = box(helicopter_position + hitbox_offset, xy(8, 8))
end

function init_rotor()
  rotor_engaged = false
  rotor_velocity = xy(0, 0)
end

function init_smoke()
  smoke_puffs = {}
end

function update_camera()
  local last_roof = cave_roof[127 - 16].y
  local last_floor = cave_floor[127 - 16].y

  local ideal_camera_depth = ((last_roof + last_floor) / 2) - 64
  local camera_offset = camera_position.y - ideal_camera_depth
  local camera_wrongness = abs(camera_offset)
  local camera_too_wrong = camera_wrongness > 1
  local camera_must_move = camera_too_wrong
  local camera_very_close = (
    (flr(camera_position.y) == flr(ideal_camera_depth))
    or (flr(camera_position.y) == flr(ideal_camera_depth) + 1)
  )

  if camera_very_close then
    camera_velocity.y = 0
  elseif camera_must_move then
    local ideal_new_camera_velocity = camera_offset * -1
    local camera_velocity_offset = camera_velocity.y - ideal_new_camera_velocity
    local camera_velocity_change = abs(camera_velocity_offset)
    camera_velocity.y -= camera_velocity_offset / 512
  else
    camera_velocity.y = 0
  end

  camera_velocity.y = min(3, max(-3, camera_velocity.y))

  camera_position.x += camera_velocity.x
  camera_position.y += camera_velocity.y
end

function update_cave()
  cave_position += cave_velocity

  if clock_frame > 64 and clock_frame < 128 then
    cave_position.y += sin(64 / (clock_frame - 64)) * 3
  elseif clock_frame > 192 and clock_frame < 256 then
    cave_position.y += cos(64 / (clock_frame - 64)) * 1
  elseif clock_frame > 288 and clock_frame < 416 then
    cave_position.y += 1
  end

  for i = 1, 127 do
    local j = i + cave_velocity.x
    cave_roof[i].x = cave_roof[j].x
    cave_roof[i].y = cave_roof[j].y
    cave_floor[i].x = cave_floor[j].x
    cave_floor[i].y = cave_floor[j].y
  end

  for i = 128 - cave_velocity.x, 128 do
    local j = i - 1
    cave_roof[i].x = cave_roof[j].x + 1
    cave_roof[i].y = cave_position.y + 8 + rnd(2)
    cave_floor[i].x = cave_floor[j].x + 1
    cave_floor[i].y = cave_position.y + 119 + rnd(2)
  end
end

function update_clock()
  clock_frame += 1
end

function update_collision()
  collision_point = nil

  for i = 1, hitbox_box.size.x do
    local j = hitbox_box.position.x - camera_position.x + (hitbox_box.size.x - i)

    local roof = cave_roof[j]
    if hitbox_box:contains(roof) then
      collision_point = roof
      break
    end

    local floor = cave_floor[j]
    if hitbox_box:contains(floor) then
      collision_point = floor
      break
    end
  end

  if collision_point ~= nil then
    printh("boom")

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

    printh(helicopter_position:angle(collision_point))

    local p = xy(
      helicopter_position.x + 8 * cos(angle),
      helicopter_position.y - 8 * sin(angle)
    )

    circ(p.x, p.y, 2, 8)

    if collision_point:below(helicopter_position) then
      helicopter_velocity.y = -2
    else
      helicopter_velocity.y = 2
    end
  end
end

function update_helicopter()
  helicopter_velocity += rotor_velocity + gravity_velocity
  helicopter_velocity.y = mid(-1.5, helicopter_velocity.y, 1.9)
  helicopter_position += helicopter_velocity

  if helicopter_velocity.y > 0 and not rotor_engaged then
    helicopter_inclination = "dropping"
  elseif helicopter_velocity.y < 0 and rotor_engaged then
    helicopter_inclination = "climbing"
  else
    helicopter_inclination = "hovering"
  end
end

function update_hitbox()
  hitbox_box:move(helicopter_position + hitbox_offset)
end

function update_rotor()
  rotor_engaged = btn(5)
  if rotor_engaged then
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

 if clock_frame % 4 == 0 then
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


function draw_cave()
  local camera_top = camera_position.y - 2
  local camera_bottom = camera_position.y + 128 + 4

  for i = 1, 128 do
    local roof = cave_roof[i].y
    local floor = cave_floor[i].y

    local bg_y1 = roof
    local bg_y2 = floor
    local bg_color = 0

    local roof_blur_color = 1
    local roof_rock_color = 5

    local floor_rock_color = 5

    local x = i + camera_position.x - 1

    local floor_edge_color = 1
    local floor_edge_y1 = floor
    local floor_edge_y2 = tminmax(max, {
      floor,
      tgad(cave_floor, i - 1, 0, floor),
      tgad(cave_floor, i + 1, 0, floor),
    })

    local floor_blur_color = 1
    local floor_blur_y1 = floor_edge_y2 + 1
    local floor_blur_y2 = tminmax(max, {
      floor_blur_y1,
      tgad(cave_floor, i - 1, 1, floor_blur_y1),
      tgad(cave_floor, i - 2, 1, floor_blur_y1),
      tgad(cave_floor, i + 1, 1, floor_blur_y1),
      tgad(cave_floor, i + 2, 1, floor_blur_y1),
    })

    local roof_edge_color = 1
    local roof_edge_y1 = roof
    local roof_edge_y2 = tminmax(min, {
      roof,
      tgad(cave_roof, i - 1, 0, roof),
      tgad(cave_roof, i + 1, 0, roof),
    })

    local roof_blur_color = 1
    local roof_blur_y1 = roof
    local roof_blur_y2 = tminmax(min, {
      roof,
      tgad(cave_roof, i - 1, -1, roof),
      tgad(cave_roof, i - 2, -1, roof),
      tgad(cave_roof, i + 1, -1, roof),
      tgad(cave_roof, i + 2, -1, roof),
    })

    if helicopter_position.y - roof - (i/2) < 32 then
      roof_edge_color = 7
    end

    if floor - helicopter_position.y - (i/2) < 32 then
      floor_edge_color = 7
    end

    line(x, bg_y1, x, bg_y2, bg_color)

    line(x, camera_top, x, roof, roof_rock_color)
    line(x, roof_blur_y1, x, roof_blur_y2, roof_blur_color)
    line(x, roof_edge_y1, x, roof_edge_y2, roof_edge_color)

    line(x, floor, x, camera_bottom, floor_rock_color)
    line(x, floor_blur_y1, x, floor_blur_y2, floor_blur_color)
    line(x, floor_edge_y1, x, floor_edge_y2, floor_edge_color)
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

  circ(
    helicopter_position.x,
    helicopter_position.y,
    4,
    12
  )
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
      roof_color = 8
    end
    if hitbox_box:contains(cave_floor[hitbox_box.position.x - camera_position.x + i]) then
      floor_color = 8
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
  camera(0, 0)
  print(clock_frame, 1, 1, 7)
  print(flr(cave_position.y), 1, 122, 7)
  print(flr(camera_position.y), 32, 122, 7)
end

function draw_smoke()
  for i, puff in pairs(smoke_puffs) do
    circ(puff.position.x, puff.position.y, puff.radius, 7)
  end
end

function loop(n, m, o)
  return flr(n % m / flr(m / o))
end

function xy(x, y)
  local p = { x = x, y = y }
  
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
  if t[g] == nil then
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
__sfx__
01200000097500e750097500e75011750117530e7500e75009753117500e75011750157501575311750117500975315750117501575018750187530c7500c75009753117500c7531175015750157501575315100
012000000c750117500c75011750157501575311750117500c75315750117501575018750187531575015750107531875015750187501c7501c75310750107500c75315750107501575019750197532170021100
01200000157551675013752167551a7501a7500000000000157551675013752167551b7501b7501570015750157550e7001a750157521a7551d7501d7501d7500000000000000000000000000000000000000000
01200000157551675013752167551a7501a7500c0000c000157551675013752167551c7501c750157001575015755157551a7551e7552175021750217502d7000000000000000000000000000000000000000000
010a00000c013006050060500605006150060517615176050c013006160061500605006150060517615176050c013006050060500605006150060500605006050c01300616006150060500615006051761517605
010a00002151300600006000060000600006001760017600095330e531095310e53311530115330e5350e5351d513027000e7001a70009700117000e7001a70009533115310e5311153315530155331153511535
01200000091540e150091500e15011150111530e1500e15009153111500e15011150151501515311150111500915315150111501515018150181530c1500c15009153111500c1531115015150151501515315100
01200002007460c746000070000700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004
__music__
00 00424344
00 01424344
00 02424344
00 03424344
03 04054344

