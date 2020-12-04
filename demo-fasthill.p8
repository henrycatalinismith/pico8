pico-8 cartridge // http://www.pico-8.com
version 29
__lua__
-- fasthill
-- by hen

function _init()
 seed = rnd(1)
 speed = 8
 distance = 0
 foreground = {}
 background = {}
 snow = {}

 for x = 1, 128 do
  add(background, topography(x+1))
  add(foreground, topography(x+speed-1))
  add(snow, topography(x+speed-1) * 0.01)
 end
end

function _update()
 for i = 1, speed/2 do
  del(background, background[1])
  add(background, topography(distance + i))
 end

 for i = 1, speed do
  del(foreground, foreground[1])
  del(snow, snow[1])
  add(foreground, topography(distance + i))
  add(snow, topography(distance/4) * 0.02)
 end

 distance += speed
end

function _draw()
 cls(12)
 for x = 0, 127 do
  line(x, background[x+1], x, 127, 13)
  line(x, foreground[x+1], x, 127, 1)
  line(x, foreground[x+1], x, foreground[x+1] + snow[x+1], 7)
 end
 rectfill(0, 115, 127, 127, 3)
 print(stat(1), 1, 1, 7)
end

function sinw(pos,period,amp)
	return sin(pos*period)*amp
end

function topography(x)
	local pos=x/127
	return 90+sinw(pos+100*seed,2,10)+sinw(pos+100*seed,0.8,10)+sinw(pos+100*seed,8,1)
end
