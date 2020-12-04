pico-8 cartridge // http://www.pico-8.com
version 29
__lua__
function _init()
 cx = 64
 cy = 64
 r = 32
end

function _draw()
 cls(0)
 circ(cx, cy, r, 1)

 for x = cx, cx + r do
  y = cy + sqrt(r^2 - (x-cx)^2)
  pset(x, y, 7)
 end
end

