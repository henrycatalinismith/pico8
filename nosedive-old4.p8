pico-8 cartridge // http://www.pico-8.com
version 16
__lua__

easeout = function(t)
  return t*(2-t)/t
end

level_list = {
  "start",
  "boxes",
  "narrows",
  "start",
  "waves",
  "spikes",
  "waves",
  "spikes",
  "waves",
  "updown",
  "floorup",
  "roofdown",
  "jagged",
  "narrows",
}

levels = {
  start = function(x)
    return { 8, 120 }
  end,

  narrows = function(x)
    local c = 8 + easeout(x/2800) * x/20
    return {
      c,
      127 - c,
    }
  end,

  waves = function(x)
    return {
      30 + sin((x % 190) / 190) * 20,
      90 - sin((x + 128 % 190) / 190) * 20,
    }
  end,

  boxes = function(x)
    if flr(x / 30) % 2 == 0 then
      return { 8, 120 }
    else
      return { 40, 80 }
    end
  end,

  spikes = function(x, t)
    local c = x/10 + (8 * flrrnd(10) * 0.1)
    local f = x/10 + (20 * flrrnd(10) * 0.1)
    return {
      c,
      127 - f,
    }
  end,

  jagged = function(x, t)
    local jag = ((x/10)%5) + (x/10)
    local drop = (t-x)/9
    local c = jag + drop
    local f = x/10 + (10 * flrrnd(10) * 0.1)
    return {
      c,
      127 - c,
    }
  end,

  roofdown = function(x, t)
    local c = 8 + ((x/t) * 50)
    local f = 120 - ((x/t) * 10)
    return {
      c,
      f,
    }
  end,

  floorup = function(x, t)
    local c = 8 + ((x/t) * 10)
    local f = 120 - ((x/t) * 50)
    return {
      c,
      f,
    }
  end,

  updown = function(x, t)
    local c = 8 + ((x/(x+t)) * 10)

    c = c + section(x, t, 1, 4, function(sprg)
      return 20
    end)

    c = c + section(x, t, 2, 4, function(sprg)
      return 10
    end)

    local f = 120 - ((x/t) * 50)
    return {
      c,
      f,
    }
  end,
}

function section(x, t, n, m, fn)
  local prog = x / t
  local slen = n / m
  local sbeg = slen * (n + 1)
  local send = sbeg + slen
  local sprg = (x%slen)/slen
  if prog >= sbeg and prog <= send then
    return fn(sprg)
  else
    return 0
  end
end

function _init()
  music(4, 3)
  tick = 0
  alive = true
  gravity = 0.09
  power = 0.15
  foreground = { 0, 0 }
  position = { 64, 64 }
  velocity = { 2, -1 }
  hitbox = {}
  inclination = "hovering"
  exhaust = {}
  cave = {}
  level = cue_level(level_list[1])
  level_index = 1

  for x = 1,128 do
    add(cave, level())
  end
end

function _update60()
  tick = tick + 1
  controls()
  if tick % 5 < 4 then
    move_helicopter()
    move_cave()
  end
  move_exhaust()
  collisions()
end

function _draw()
  cls(0)
  camera(foreground[1], foreground[2])
  draw_cave()
  draw_helicopter()
  draw_exhaust()

  --for i = 0,2 do print(stat(i), foreground[1], i*8, 7) end
  --print(hitbox[1], foreground[1] + 32, 32)
  --print(foreground[1], foreground[1] + 32, 38)
  --print(cave[50][1], foreground[1] + 32, 46)
  --print(
    --hitbox[1] - foreground[1]
  --, foreground[1] + 32, 54)
  --pset(foreground[1] + 57, cave[57][1], 12)
end

function controls()
  if alive and btn(5) then
    velocity[2] = max(-1.5, velocity[2] - power)
    sfx(7)
  else
    sfx(-1)
  end
end


function lerp(a,b,r)
  return a+(b-a)*r
end

function pow(n)
  return function(v) return v^n end
end

function cue_level(name)
  local length = 128
  local level = {}
  local first = tick

  local ei = pow(4)
  local t = 30

  local ease = function(a, b)
    local diff = b - a
    local per = diff / t
    local age = tick - first
    local sofar = age * per

    if age < t then
      return a + sofar
    else
      return b
    end
  end

  local generator = function()
    for x = 1,length do
      local s = levels[name](x, length)
      local top = s[1]
      local bottom = s[2]

      if #cave > 1 then
        top = ease(cave[#cave][1], top)
        bottom = ease(cave[#cave][2], bottom)
      end
      add(cave, { top, bottom })
      yield()
    end
  end

  local coroutine = cocreate(generator)

  local level = function()
    if costatus(coroutine) == "dead" then
      next_level()
    else
      coresume(coroutine)
    end
  end

  return level
end

function next_level()
  level_index = (level_index + 1) % #level_list
  level_name = level_list[level_index]
  level = cue_level(level_name)
end

function move_cave()
  for i = 1,velocity[1] do
    del(cave, cave[1])
  end
  for i = 0,127-#cave do
    level()
  end
end

function move_helicopter()
  velocity[2] = min(1.9, velocity[2] + gravity)
  position[1] = position[1] + velocity[1]
  position[2] = position[2] + velocity[2]
  foreground[1] = position[1] - 32

  if btn(5) then
    if velocity[2] >= 0 then
      inclination = "hovering"
    else
      inclination = "climbing"
    end
  else
    if velocity[2] > 0.4 then
      inclination = "dropping"
    else
      inclination = "hovering"
    end
  end
end

function move_exhaust()
  for i,puff in pairs(exhaust) do
    -- exhaust puffs shrink with age
    puff_age = tick - puff[6]
    if puff_age % 20 == 0 then
      puff[5] = puff[5] - 1
    end

    -- exhaust puffs conserve momentum
    puff[1] = puff[1] + puff[3] / 16
    puff[2] = puff[2] + puff[4] / 8

    -- exhaust puffs disappear
    if puff[5] < 0 then
      del(exhaust, puff)
    end
  end

  if tick % 4 == 0 then
    if btn(5) then
      puff_radius = 1
    else
      puff_radius = 0
    end
    add(exhaust, {
      position[1] + 8,
      position[2] + 4,
      velocity[1],
      velocity[2],
      puff_radius,
      tick,
    })
  end
end

function collisions()
  hitbox = {
    position[1] + 1, position[2],
    position[1] + 14, position[2] + 6,
  }

  start_i = hitbox[1] - foreground[1]
  for i = hitbox[1],hitbox[3] do
    slice = cave[i - foreground[1]]
    if hitbox[2] < slice[1] then
      --alive = false
      velocity = { velocity[1], 0.2 }
      position[2] = slice[1] + 1
    end
    if hitbox[4] > slice[2] then
      --alive = false
      position[2] = slice[2] - 8
      velocity = { velocity[1], -0.8 }
    end
  end
end

function draw_helicopter()
  helicopter_sprite_column = ({
    hovering = 1,
    dropping = 2,
    climbing = 3,
  })[inclination]

  helicopter_sprite_x = ({
    0,
    16,
    32,
    48,
  })[helicopter_sprite_column]

  sspr(
    helicopter_sprite_x, 0,
    16, 8,
    position[1], position[2]
  )

  sspr(
    helicopter_sprite_x + 3, 8+(loop(32,8)*3),
    13, 3,
    position[1] + 3, position[2] - 1
  )

  tail_y_offset = ({
    hovering = 2,
    dropping = 0,
    climbing = 3,
  })[inclination]

  sspr(
    helicopter_sprite_x, 8+loop(8,8)*3 ,
    3, 3,
    position[1], position[2] + tail_y_offset
  )
end

function draw_exhaust()
  for puff in all(exhaust) do
    puff_age = tick - puff[6]
    puff_color = 7
    if puff_age < 8 then
      puff_color = 5
    end
    circ(
      puff[1],
      puff[2],
      puff[5],
      puff_color
    )
  end
end

function draw_cave()
  for x,slice in pairs(cave) do
    local sx = foreground[1] + x - 1
    local cy = foreground[2] + slice[1]
    local fy = foreground[2] + slice[2]

    local ceiling_rock_y1 = 0
    local ceiling_rock_y2 = cy
    local floor_rock_y1 = fy
    local floor_rock_y2 = 128

    local ceiling_edge_y1 = cy+1
    local ceiling_edge_y2 = cy+1
    local floor_edge_y1 = fy-1
    local floor_edge_y2 = fy-1

    local ceiling_blur_y1 = cy
    local ceiling_blur_y2 = cy
    local floor_blur_y1 = fy
    local floor_blur_y2 = fy

    if x > 1 then
      local pcy = foreground[2]+cave[x-1][1]
      local pfy = foreground[2]+cave[x-1][2]

      if cy > pcy then
        ceiling_blur_y1 = pcy
        ceiling_edge_y1 = pcy+1
      end

      if fy < pfy then
        floor_blur_y1 = pfy
        floor_edge_y1 = pfy-1
      end

      if x > 2 then
        local pcy2 = foreground[2]+cave[x-2][1]
        local pfy2 = foreground[2]+cave[x-2][2]
        if pcy > pcy2 then
          ceiling_blur_y1 = pcy2
        end

        if pfy < pfy2 then
          floor_blur_y1 = pfy2
        end
      end

      if x < #cave and #cave[x+1] == 2 then
        local ncy = foreground[2]+cave[x+1][1]
        local nfy = foreground[2]+cave[x+1][2]

        if cy > ncy then
          ceiling_blur_y1 = ncy
          ceiling_edge_y1 = ncy+1
        end

        if fy < nfy then
          floor_blur_y1 = nfy
          floor_edge_y1 = nfy-1
        end

        if x < #cave - 1 and #cave[x+2] == 2 then
          local ncy2 = foreground[2]+cave[x+2][1]
          local nfy2 = foreground[2]+cave[x+2][2]

          if ncy > ncy2 then
            ceiling_blur_y1 = ncy2
          end

          if nfy < nfy2 then
            floor_blur_y1 = nfy2
          end
        end
      end
    end

    local rock_color = 5
    local blur_color = 13
    local ceiling_edge_color = 1
    local floor_edge_color = 1
    local cave_color = 0

    local p = 0b0000000000000000
    local blank = 0b1111111111111111
    local half = 0b0101010010101010
    if x > #cave - (128 - position[2] + cy) then
      ceiling_edge_color = 6
    else
      p = 0b0001000110011101
      p = blank
      p = half
    end
    if x > #cave - (position[2] + 128-fy) then
      floor_edge_color = 6
    else
      p = blank
      p = half
    end

    fillp(p)

    line(sx, cy, sx, fy, cave_color)

    line(sx, ceiling_rock_y1, sx, ceiling_rock_y2, rock_color)
    line(sx, floor_rock_y1, sx, floor_rock_y2, rock_color)

    if x > 0 and x <= #cave then
      line(sx, ceiling_blur_y1, sx, ceiling_blur_y2, blur_color)
      line(sx, floor_blur_y1, sx, floor_blur_y2, blur_color)
    end

    if x > 1 and x < #cave then
      line(sx, ceiling_edge_y1, sx, ceiling_edge_y2, ceiling_edge_color)
      line(sx, floor_edge_y1, sx, floor_edge_y2, floor_edge_color)
    end
  end
end

function flrrnd(n)
  return flr(rnd(n))
end

function choose(table)
  return table[flrrnd(#table) + 1]
end

function loop(interval, limit)
  remainder = tick % interval
  chunk_size = flr(interval / limit)
  local num = flr(remainder / chunk_size)
  return num
end

-- 1. Paste this at the very bottom of your PICO-8 
--    cart
-- 2. Hit return and select the menu item to save
--    a slow render gif (it's all automatic!)
-- 3. Tweet the gif with #PutAFlipInIt
-- 
-- Notes: 
--
-- This relies on the max gif length being long
-- enough. This can be set with the -gif_len 
-- command line option, e.g.:
--
--   pico8.exe -gif_len 30
--
-- The gif is where it would be when you hit F9.
-- Splore doesn't play nicely with this, you
-- need to save the splore cart locally and load
-- it.
--
-- You might need to remove unnecessary 
-- overrides to save tokens. pset() override
-- flips every 4th pset() call.
--
-- This doesn't always play nicely with optional
-- parameters, e.g. when leaving out the color 
-- param.
--
-- Name clashes might happen, didn't bother
-- to namespace etc.

function cflip() if(slowflip)flip()
end
ospr=spr
function spr(...)
ospr(...)
cflip()
end
osspr=sspr
function sspr(...)
osspr(...)
cflip()
end
omap=map
function map(...)
omap(...)
cflip()
end
orect=rect
function rect(...)
orect(...)
cflip()
end
orectfill=rectfill
function rectfill(...)
orectfill(...)
cflip()
end
ocircfill=circfill
function circfill(...)
ocircfill(...)
cflip()
end
ocirc=circ
function circ(...)
ocirc(...)
cflip()
end
oline=line
function line(...)
oline(...)
cflip()
end
opset=pset
psetctr=0
function pset(...)
opset(...)
psetctr+=1
if(slowflip and psetctr%4==0)flip()
end
odraw=_draw
function _draw()
if(slowflip)extcmd("rec")
odraw()
if(slowflip)for i=0,99 do flip() end extcmd("video")cls()stop("gif saved")
end
menuitem(1,"put a flip in it!",function() slowflip=not slowflip end)

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
012000000c750117500c75011750157501575311750117500c753157501175015750187501875315750157500c7531875015750187501c7501c75310750107500c75315750107501575019750197532170021100
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

